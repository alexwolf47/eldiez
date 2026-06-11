defmodule ElDiezWorldCupWeb.AdminLive do
  @moduledoc """
  Admin console for the sweepstakes draw (HTTP Basic Auth, see the router).

  Lets an organiser schedule the draw start time, start it immediately, and
  reset the draft back to a blank state. Mirrors the live draw status so the
  organiser sees progress alongside viewers.
  """
  use ElDiezWorldCupWeb, :live_view

  alias ElDiezWorldCup.Sweepstakes
  alias ElDiezWorldCup.Sweepstakes.DrawServer
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    if session["admin_authed"] do
      if connected?(socket), do: PubSub.subscribe(ElDiezWorldCup.PubSub, DrawServer.topic())

      {:ok,
       socket
       |> assign(:page_title, "Admin · Sweepstakes Draw")
       |> assign(:total, Sweepstakes.total_slots())
       |> apply_state(DrawServer.state())}
    else
      {:ok, redirect(socket, to: ~p"/admin/login")}
    end
  end

  @impl true
  def handle_info({:draw, state}, socket), do: {:noreply, apply_state(socket, state)}

  defp apply_state(socket, state) do
    socket
    |> assign(:status, state.status)
    |> assign(:scheduled_at, state.scheduled_at)
    |> assign(:done_count, length(state.assignments))
    |> assign(:default_dt, default_dt(state.scheduled_at))
  end

  defp default_dt(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%dT%H:%M")

  defp default_dt(_),
    do: DateTime.utc_now() |> DateTime.add(5, :minute) |> Calendar.strftime("%Y-%m-%dT%H:%M")

  @impl true
  def handle_event("schedule", %{"scheduled_at" => raw}, socket) do
    case parse_dt(raw) do
      {:ok, dt} ->
        DrawServer.schedule(dt)
        {:noreply, put_flash(socket, :info, "Draw scheduled for #{Calendar.strftime(dt, "%d %b %Y · %H:%M UTC")}.")}

      :error ->
        {:noreply, put_flash(socket, :error, "Please pick a valid date and time.")}
    end
  end

  def handle_event("start_now", _params, socket) do
    DrawServer.start_now()
    {:noreply, put_flash(socket, :info, "Draw started!")}
  end

  def handle_event("reset", _params, socket) do
    DrawServer.reset()
    {:noreply, put_flash(socket, :info, "Draft reset. Ready to schedule again.")}
  end

  # datetime-local gives "YYYY-MM-DDTHH:MM"; treat the wall-clock value as UTC.
  defp parse_dt(raw) when is_binary(raw) do
    normalized = if String.length(raw) == 16, do: raw <> ":00", else: raw

    case NaiveDateTime.from_iso8601(normalized) do
      {:ok, naive} -> {:ok, DateTime.from_naive!(naive, "Etc/UTC")}
      _ -> :error
    end
  end

  defp parse_dt(_), do: :error

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="mx-auto max-w-2xl px-4 py-10 space-y-6">
        <header class="space-y-1">
          <h1 class="text-3xl font-black">⚙️ Draw Admin</h1>
          <p class="text-base-content/70">
            Schedule, launch, or reset the live sweepstakes draw.
            <a href="/" class="link link-primary">View the public draw →</a>
          </p>
          <.link
            href={~p"/admin/logout"}
            method="delete"
            class="link link-hover text-sm text-base-content/50"
          >
            Log out
          </.link>
        </header>

        <Layouts.flash_group flash={@flash} />

        <div class="card bg-base-100 shadow-md">
          <div class="card-body gap-4">
            <h2 class="card-title">Status</h2>
            <div class="flex items-center gap-3">
              <.status_badge status={@status} />
              <span :if={@scheduled_at} class="text-sm text-base-content/60">
                Scheduled: {Calendar.strftime(@scheduled_at, "%d %b %Y · %H:%M UTC")}
              </span>
            </div>
            <progress class="progress progress-success w-full" value={@done_count} max={@total}>
            </progress>
            <p class="text-sm text-base-content/60">{@done_count} of {@total} teams drawn</p>
          </div>
        </div>

        <div class="card bg-base-100 shadow-md">
          <div class="card-body gap-4">
            <h2 class="card-title">Schedule the draw</h2>
            <form phx-submit="schedule" class="flex flex-col sm:flex-row gap-3 sm:items-end">
              <div class="form-control grow">
                <label class="label" for="scheduled_at">
                  <span class="label-text">Start time (UTC)</span>
                </label>
                <input
                  type="datetime-local"
                  id="scheduled_at"
                  name="scheduled_at"
                  value={@default_dt}
                  class="input input-bordered w-full"
                  required
                />
              </div>
              <button type="submit" class="btn btn-primary">Schedule</button>
            </form>
            <p class="text-xs text-base-content/50">
              When the clock hits this time the draw starts automatically for all viewers.
            </p>
          </div>
        </div>

        <div class="card bg-base-100 shadow-md">
          <div class="card-body gap-4">
            <h2 class="card-title">Manual controls</h2>
            <div class="flex flex-wrap gap-3">
              <button
                type="button"
                phx-click="start_now"
                class="btn btn-success"
                disabled={@status == "drawing"}
              >
                ▶ Start now
              </button>
              <button
                type="button"
                phx-click="reset"
                data-confirm="Reset the entire draft? This clears all drawn results."
                class="btn btn-error btn-outline"
              >
                ↺ Reset draft
              </button>
            </div>
            <p class="text-xs text-base-content/50">
              “Start now” launches the draw immediately. “Reset draft” wipes all results
              and returns the game to a blank, pending state.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :status, :string, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-lg",
      @status == "pending" && "badge-ghost",
      @status == "scheduled" && "badge-info",
      @status == "drawing" && "badge-success animate-pulse",
      @status == "complete" && "badge-success"
    ]}>
      {@status}
    </span>
    """
  end
end
