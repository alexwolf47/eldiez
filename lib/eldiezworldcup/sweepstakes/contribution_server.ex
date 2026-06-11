defmodule ElDiezWorldCup.Sweepstakes.ContributionServer do
  @moduledoc """
  In-memory store of each player's pot contribution pledge, shared live across
  all viewers.

  Every player can pledge what they're prepared to pay into the prize pot. The
  agreed per-player contribution is the *lowest* pledge on the board, so nobody
  pays more than the cheapest player is willing to. Pledges are held in memory
  and broadcast over PubSub topic `"contributions"` as `{:contributions, pledges}`,
  where `pledges` is a `%{player => pence}` map.
  """
  use GenServer

  alias ElDiezWorldCup.Sweepstakes
  alias Phoenix.PubSub

  @pubsub ElDiezWorldCup.PubSub
  @topic "contributions"

  # --- Client API ------------------------------------------------------------

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "PubSub topic that broadcasts `{:contributions, pledges}` on every change."
  def topic, do: @topic

  @doc "Returns the current `%{player => pence}` pledge map."
  def pledges, do: GenServer.call(__MODULE__, :pledges)

  @doc """
  Records a player's pledge in whole pence. Ignores unknown players and
  non-positive amounts. Returns the updated pledge map.
  """
  def set_pledge(player, pence), do: GenServer.call(__MODULE__, {:set, player, pence})

  @doc "Clears a player's pledge."
  def clear_pledge(player), do: GenServer.call(__MODULE__, {:clear, player})

  # --- Server ----------------------------------------------------------------

  # Everyone starts pledged at £10 (1000p); players can raise/lower from there.
  @default_pence 1000

  @impl true
  def init(:ok) do
    pledges = Map.new(Sweepstakes.players(), fn player -> {player, @default_pence} end)
    {:ok, pledges}
  end

  @impl true
  def handle_call(:pledges, _from, pledges), do: {:reply, pledges, pledges}

  def handle_call({:set, player, pence}, _from, pledges) do
    if player in Sweepstakes.players() and is_integer(pence) and pence > 0 do
      pledges = Map.put(pledges, player, pence)
      broadcast(pledges)
      {:reply, pledges, pledges}
    else
      {:reply, pledges, pledges}
    end
  end

  def handle_call({:clear, player}, _from, pledges) do
    pledges = Map.delete(pledges, player)
    broadcast(pledges)
    {:reply, pledges, pledges}
  end

  defp broadcast(pledges), do: PubSub.broadcast(@pubsub, @topic, {:contributions, pledges})
end
