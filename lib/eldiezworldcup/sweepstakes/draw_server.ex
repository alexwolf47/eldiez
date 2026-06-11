defmodule ElDiezWorldCup.Sweepstakes.DrawServer do
  @moduledoc """
  Authoritative, in-memory state machine for the live sweepstakes draw.

  Responsibilities:

    * Holds the current draw state (status, schedule, revealed assignments and the
      slot currently spinning) so every viewer sees the same thing.
    * Paces the draw: each team reveal is a 5s flag spin followed by a lock-in
      so the selected team sticks (4s, doubled to 8s for the Pot 1 favourites),
      advancing Pot 1 for all players, then Pot 2, and so on.
    * Persists every revealed assignment to the database as it happens, and the
      lifecycle/schedule/seed to the settings row, so a restart resumes cleanly.
    * Broadcasts state changes over PubSub topic `"draw"`.

  A monotonic `gen` token guards against stale timer messages after a reset,
  reschedule, or "start now" so an aborted run can never resurrect itself.
  """
  use GenServer

  alias ElDiezWorldCup.Sweepstakes
  alias ElDiezWorldCup.Sweepstakes.Assignment
  alias Phoenix.PubSub

  @pubsub ElDiezWorldCup.PubSub
  @topic "draw"
  @spin_ms 5_000
  @lock_ms 4_000

  # --- Client API ------------------------------------------------------------

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "PubSub topic that broadcasts `{:draw, state}` on every change."
  def topic, do: @topic

  @doc "Returns the current public draw state."
  def state, do: GenServer.call(__MODULE__, :state)

  @doc "Schedules the draw to begin at the given `DateTime` (UTC)."
  def schedule(%DateTime{} = at), do: GenServer.call(__MODULE__, {:schedule, at})

  @doc "Starts the draw immediately."
  def start_now, do: GenServer.call(__MODULE__, :start_now)

  @doc "Resets everything back to a blank, pending draft."
  def reset, do: GenServer.call(__MODULE__, :reset)

  # --- Server ----------------------------------------------------------------

  @impl true
  def init(:ok) do
    setting = Sweepstakes.get_setting()
    assignments = Sweepstakes.list_assignments() |> Enum.map(&to_pub/1)

    state = %{
      gen: 0,
      status: setting.status,
      scheduled_at: setting.scheduled_at,
      seed: setting.seed,
      assignments: assignments,
      current: nil,
      timer: nil
    }

    state =
      cond do
        setting.status == "drawing" -> resume(state)
        setting.status == "scheduled" and setting.scheduled_at -> arm_timer(state)
        true -> state
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, public(state), state}

  def handle_call({:schedule, at}, _from, state) do
    state = cancel_timer(state)
    gen = state.gen + 1
    Sweepstakes.update_setting(%{scheduled_at: at, status: "scheduled"})

    state =
      %{state | gen: gen, scheduled_at: at, status: "scheduled", current: nil}
      |> arm_timer()

    broadcast(state)
    {:reply, :ok, state}
  end

  def handle_call(:start_now, _from, state) do
    state = state |> cancel_timer() |> bump_gen() |> do_start()
    broadcast(state)
    {:reply, :ok, state}
  end

  def handle_call(:reset, _from, state) do
    state = cancel_timer(state)
    Sweepstakes.reset!()

    state = %{
      state
      | gen: state.gen + 1,
        status: "pending",
        scheduled_at: nil,
        seed: nil,
        assignments: [],
        current: nil,
        timer: nil
    }

    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:start_scheduled, gen}, %{gen: gen} = state) do
    state = state |> Map.put(:timer, nil) |> do_start()
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:next, gen}, %{gen: gen} = state) do
    plan = Sweepstakes.build_plan(state.seed)
    index = length(state.assignments)

    if index >= length(plan) do
      Sweepstakes.update_setting(%{status: "complete"})
      state = %{state | status: "complete", current: nil, timer: nil}
      broadcast(state)
      {:noreply, state}
    else
      slot = Enum.at(plan, index)
      current = Map.put(slot, :phase, "spinning")
      timer = Process.send_after(self(), {:lock, gen}, @spin_ms)
      state = %{state | current: current, timer: timer}
      broadcast(state)
      {:noreply, state}
    end
  end

  def handle_info({:lock, gen}, %{gen: gen, current: current} = state) when is_map(current) do
    slot = Map.delete(current, :phase)
    {:ok, _} = Sweepstakes.create_assignment(slot)

    timer = Process.send_after(self(), {:advance, gen}, lock_ms(current.pot))

    state = %{
      state
      | assignments: state.assignments ++ [to_pub(slot)],
        current: Map.put(current, :phase, "locked"),
        timer: timer
    }

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:advance, gen}, %{gen: gen} = state) do
    send(self(), {:next, gen})
    state = %{state | current: nil, timer: nil}
    broadcast(state)
    {:noreply, state}
  end

  # Stale messages from a superseded generation (after reset/reschedule).
  def handle_info(_msg, state), do: {:noreply, state}

  # --- Internals -------------------------------------------------------------

  # How long the selected team stays on screen before advancing. Pot 1 (the
  # favourites) lingers twice as long for extra drama.
  defp lock_ms(1), do: @lock_ms * 2
  defp lock_ms(_pot), do: @lock_ms

  defp do_start(state) do
    seed = state.seed || :erlang.unique_integer([:positive])
    Sweepstakes.update_setting(%{status: "drawing", seed: seed})
    send(self(), {:next, state.gen})
    %{state | status: "drawing", seed: seed, current: nil}
  end

  defp resume(state) do
    send(self(), {:next, state.gen})
    %{state | status: "drawing", current: nil}
  end

  defp arm_timer(%{scheduled_at: nil} = state), do: state

  defp arm_timer(state) do
    ms = DateTime.diff(state.scheduled_at, DateTime.utc_now(), :millisecond)

    if ms > 0 do
      %{state | timer: Process.send_after(self(), {:start_scheduled, state.gen}, ms)}
    else
      do_start(state)
    end
  end

  defp bump_gen(state), do: %{state | gen: state.gen + 1}

  defp cancel_timer(%{timer: nil} = state), do: state

  defp cancel_timer(%{timer: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer: nil}
  end

  defp broadcast(state), do: PubSub.broadcast(@pubsub, @topic, {:draw, public(state)})

  defp public(state) do
    %{
      status: state.status,
      scheduled_at: state.scheduled_at,
      assignments: state.assignments,
      current: state.current
    }
  end

  defp to_pub(%Assignment{} = a) do
    %{pot: a.pot, position: a.position, player: a.player, team: a.team, flag: a.flag, odds: a.odds}
  end

  defp to_pub(%{} = slot) do
    Map.take(slot, [:pot, :position, :player, :team, :flag, :odds])
  end
end
