defmodule ElDiezWorldCupWeb.DrawLive do
  @moduledoc """
  Public single-page view of the live World Cup sweepstakes draw.

  Subscribes to the `DrawServer` broadcast topic so every viewer sees the same
  draw in real time: a flag spins for ~3 seconds per slot, locks in, and fills
  the board pot by pot. Shows a countdown before the scheduled start and the
  prize-pool awards breakdown throughout.
  """
  use ElDiezWorldCupWeb, :live_view

  alias ElDiezWorldCup.Sweepstakes
  alias ElDiezWorldCup.Sweepstakes.ContributionServer
  alias ElDiezWorldCup.Sweepstakes.DrawServer
  alias Phoenix.PubSub

  @reel_flags ~w(🇪🇸 🇫🇷 🇧🇷 🇩🇪 🇳🇱 🇦🇷 🇵🇹 🇲🇽)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(ElDiezWorldCup.PubSub, DrawServer.topic())
      PubSub.subscribe(ElDiezWorldCup.PubSub, ContributionServer.topic())
    end

    socket =
      socket
      |> assign(:page_title, "World Cup Sweepstakes Draw")
      |> assign(:players, Sweepstakes.players())
      |> assign(:pots, Sweepstakes.pots())
      |> assign(:awards, Sweepstakes.awards())
      |> assign(:reel_flags, @reel_flags)
      |> assign(:selected_player, hd(Sweepstakes.players()))
      |> assign(:pledges, ContributionServer.pledges())
      |> apply_state(DrawServer.state())
      |> assign(:now, DateTime.utc_now())
      |> schedule_tick()

    {:ok, socket}
  end

  @impl true
  def handle_info({:draw, state}, socket) do
    {:noreply, socket |> apply_state(state) |> schedule_tick()}
  end

  def handle_info({:contributions, pledges}, socket) do
    {:noreply, assign(socket, :pledges, pledges)}
  end

  def handle_info(:tick, socket) do
    {:noreply, socket |> assign(:now, DateTime.utc_now()) |> schedule_tick()}
  end

  @impl true
  def handle_event("select_player", %{"player" => player}, socket) do
    {:noreply, assign(socket, :selected_player, player)}
  end

  def handle_event("pledge", %{"player" => player, "amount" => amount}, socket) do
    case parse_pence(amount) do
      {:ok, pence} ->
        ContributionServer.set_pledge(player, pence)
        {:noreply, assign(socket, :selected_player, player)}

      :error ->
        {:noreply, assign(socket, :selected_player, player)}
    end
  end

  # Parse a "£" text input (e.g. "10", "12.50") into whole pence.
  defp parse_pence(amount) when is_binary(amount) do
    case Float.parse(String.trim(amount)) do
      {pounds, _rest} when pounds > 0 -> {:ok, round(pounds * 100)}
      _ -> :error
    end
  end

  # Build a {pot, player} => slot lookup for O(1) board rendering.
  defp apply_state(socket, state) do
    board =
      Map.new(state.assignments, fn slot -> {{slot.pot, slot.player}, slot} end)

    socket
    |> assign(:status, state.status)
    |> assign(:scheduled_at, state.scheduled_at)
    |> assign(:current, state.current)
    |> assign(:board, board)
    |> assign(:done_count, map_size(board))
    |> assign(:total, Sweepstakes.total_slots())
  end

  # Tick once a second only while a future countdown is showing.
  defp schedule_tick(socket) do
    if socket.assigns.status in ["pending", "scheduled"] and countdown_secs(socket.assigns) > 0 do
      if connected?(socket), do: Process.send_after(self(), :tick, 1000)
    end

    socket
  end

  defp countdown_secs(%{scheduled_at: nil}), do: 0

  defp countdown_secs(%{scheduled_at: at, now: now}),
    do: max(DateTime.diff(at, now, :second), 0)

  defp countdown_secs(_), do: 0

  # Digital countdown clock. Reads as mm:ss near the draw, widening to
  # h:mm:ss / d:hh:mm:ss when the start is further out.
  defp format_countdown(secs) do
    days = div(secs, 86_400)
    hours = div(rem(secs, 86_400), 3600)
    mins = div(rem(secs, 3600), 60)
    s = rem(secs, 60)

    cond do
      days > 0 -> "#{days}:#{pad(hours)}:#{pad(mins)}:#{pad(s)}"
      hours > 0 -> "#{hours}:#{pad(mins)}:#{pad(s)}"
      true -> "#{pad(mins)}:#{pad(s)}"
    end
  end

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  # Format whole pence as "£12.50" (drops the decimals for round pounds).
  defp format_pence(pence) do
    pounds = pence / 100

    if pence |> rem(100) == 0 do
      "£#{div(pence, 100)}"
    else
      "£#{:erlang.float_to_binary(pounds, decimals: 2)}"
    end
  end

  defp pot_label(1), do: "Pot 1 · Top 10 Favourites"
  defp pot_label(2), do: "Pot 2 · 11–20"
  defp pot_label(3), do: "Pot 3 · 21–30"
  defp pot_label(4), do: "Pot 4 · 31–40"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="mx-auto max-w-6xl px-4 py-8 space-y-8">
        <header class="text-center space-y-2">
          <h1 class="text-3xl sm:text-5xl font-black tracking-tight">
            🏆 ElDiez World Cup Sweepstakes
          </h1>
          <p class="text-base-content/70">
            Ten players · four pots · one team each · live draw
          </p>
        </header>

        <.status_banner
          status={@status}
          scheduled_at={@scheduled_at}
          countdown={format_countdown(countdown_secs(assigns))}
          countdown_secs={countdown_secs(assigns)}
          done={@done_count}
          total={@total}
        />

        <.awards awards={@awards} />

        <.contributions
          players={@players}
          pledges={@pledges}
          selected_player={@selected_player}
          awards={@awards}
        />

        <.now_drawing
          :if={@current}
          current={@current}
          remaining={remaining_teams(@pots, @board, @current.pot)}
        />

        <.draw_preview
          :if={is_nil(@current) and @status in ["pending", "scheduled"]}
          pot={Map.get(@pots, 1, [])}
        />

        <section class="grid gap-6 lg:grid-cols-2">
          <div :for={pot <- 1..Sweepstakes.pot_count()} class="card bg-base-100 shadow-md">
            <div class="card-body p-4 sm:p-6">
              <div class="flex items-center justify-between gap-2">
                <h2 class="card-title text-lg">{pot_label(pot)}</h2>
                <div class="text-sm text-base-content/60">
                  {Enum.count(@players, fn p -> Map.has_key?(@board, {pot, p}) end)}/{Sweepstakes.pot_size()}
                </div>
              </div>

              <div class="flex flex-wrap gap-1 text-xl pb-2 opacity-70" title="Teams in this pot">
                <span :for={team <- Map.get(@pots, pot, [])} title={team.name}>{team.flag}</span>
              </div>

              <ul class="divide-y divide-base-200">
                <li
                  :for={player <- @players}
                  class={[
                    "flex items-center justify-between gap-3 py-2 px-2 rounded-md transition-colors",
                    active?(@current, pot, player) && "bg-warning/15 ring-1 ring-warning"
                  ]}
                >
                  <span class="font-medium truncate">{player}</span>
                  <.slot_result
                    slot={Map.get(@board, {pot, player})}
                    spinning={active?(@current, pot, player) && @current.phase == "spinning"}
                    reel_flags={@reel_flags}
                  />
                </li>
              </ul>
            </div>
          </div>
        </section>

        <footer class="text-center text-xs text-base-content/50 pt-4">
          Odds: best available outright price per team (source: Oddschecker).
          Pot results are random and final.
        </footer>
      </div>
    </div>
    """
  end

  # --- Function components ---------------------------------------------------

  attr :status, :string, required: true
  attr :scheduled_at, :any, required: true
  attr :countdown, :string, required: true
  attr :countdown_secs, :integer, required: true
  attr :done, :integer, required: true
  attr :total, :integer, required: true

  defp status_banner(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-md">
      <div class="card-body items-center text-center py-6">
        <%= case @status do %>
          <% "pending" -> %>
            <div class="badge badge-ghost badge-lg">Not scheduled</div>
            <p class="text-base-content/70">
              The draw hasn't been scheduled yet. Sit tight — it'll kick off here live.
            </p>
          <% "scheduled" -> %>
            <%= if @countdown_secs > 0 do %>
              <div class="badge badge-info badge-lg">Draw starts in</div>
              <div class="font-mono text-4xl sm:text-6xl font-black tracking-widest tabular-nums">
                {@countdown}
              </div>
              <p class="text-base-content/60 text-sm">
                Scheduled for {Calendar.strftime(@scheduled_at, "%d %b %Y · %H:%M UTC")}
              </p>
            <% else %>
              <div class="badge badge-warning badge-lg animate-pulse">Starting…</div>
            <% end %>
          <% "drawing" -> %>
            <div class="badge badge-success badge-lg animate-pulse">Drawing live</div>
            <progress class="progress progress-success w-full max-w-md" value={@done} max={@total}>
            </progress>
            <p class="text-base-content/60 text-sm">{@done} of {@total} teams drawn</p>
          <% "complete" -> %>
            <div class="badge badge-success badge-lg">Draw complete 🎉</div>
            <p class="text-base-content/70">Every player has their four teams. Good luck!</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :current, :map, required: true
  attr :remaining, :list, required: true

  defp now_drawing(assigns) do
    ~H"""
    <div class="card bg-primary text-primary-content shadow-xl">
      <div class="card-body items-center text-center gap-3 py-6">
        <div class="uppercase tracking-widest text-sm opacity-80">
          {pot_label(@current.pot)} · Now drawing
        </div>
        <div class="text-2xl sm:text-3xl font-black">{@current.player}</div>

        <%= if @current.phase == "spinning" do %>
          <.flag_ticker id="flag-ticker" flags={Enum.map(@remaining, & &1.flag)} />
          <div class="text-lg opacity-80">Spinning…</div>
        <% else %>
          <div class="flex flex-col items-center gap-1">
            <div class="text-7xl sm:text-8xl flag-pop">{@current.flag}</div>
            <div class="text-2xl font-extrabold">{@current.team}</div>
            <div class="badge badge-outline border-primary-content/40">{@current.odds}</div>
          </div>
        <% end %>

        <.remaining_pool remaining={@remaining} />
      </div>
    </div>
    """
  end

  attr :pot, :map, required: true

  # Pre-draw teaser: the same selector idling over Pot 1 (drawn first) so the
  # ticker is alive on the page before the draw goes live.
  defp draw_preview(assigns) do
    ~H"""
    <div class="card bg-primary text-primary-content shadow-xl">
      <div class="card-body items-center text-center gap-3 py-6">
        <div class="uppercase tracking-widest text-sm opacity-80">
          {pot_label(1)} · Up first
        </div>
        <div class="text-2xl sm:text-3xl font-black">Waiting for the draw…</div>
        <.flag_ticker id="preview-ticker" flags={Enum.map(@pot, & &1.flag)} />
        <div class="text-lg opacity-80">Warming up…</div>
        <.remaining_pool remaining={@pot} />
      </div>
    </div>
    """
  end

  attr :remaining, :list, required: true

  defp remaining_pool(assigns) do
    ~H"""
    <div class="w-full pt-1">
      <div class="text-xs uppercase tracking-wider opacity-70 mb-1.5">
        {length(@remaining)} {if length(@remaining) == 1, do: "team", else: "teams"} left in this pot
      </div>
      <div class="mx-auto grid grid-cols-5 gap-3 text-5xl opacity-90 w-fit">
        <span :for={team <- @remaining} title={team.name}>{team.flag}</span>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :flags, :list, required: true

  # Slot-machine ticker: rotates the big flag through `flags` in random order.
  # Purely cosmetic — the actual result is pre-calculated server-side and the
  # spin ends when the server broadcasts the locked phase.
  defp flag_ticker(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook=".FlagTicker"
      data-flags={Jason.encode!(@flags)}
      class="text-7xl sm:text-8xl leading-none h-24 flex items-center justify-center"
    >
      {List.first(@flags)}
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".FlagTicker">
      export default {
        mounted() {
          let flags = []
          try { flags = JSON.parse(this.el.dataset.flags) } catch (_e) {}
          // Shuffle so the ticker rotates through teams in a random order
          // rather than the pot's listed order.
          for (let i = flags.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1))
            ;[flags[i], flags[j]] = [flags[j], flags[i]]
          }
          if (flags.length === 0) return
          let i = 0
          this.el.textContent = flags[0]
          this.timer = setInterval(() => {
            i = (i + 1) % flags.length
            this.el.textContent = flags[i]
          }, 90)
        },
        destroyed() {
          clearInterval(this.timer)
        },
      }
    </script>
    """
  end

  attr :slot, :map, default: nil
  attr :spinning, :boolean, default: false
  attr :reel_flags, :list, required: true

  defp slot_result(%{slot: nil, spinning: true} = assigns) do
    ~H"""
    <span class="reel-window reel-window-sm rounded-md bg-base-200 px-2">
      <span class="reel-strip reel-strip-sm">
        <span :for={flag <- @reel_flags ++ @reel_flags}>{flag}</span>
      </span>
    </span>
    """
  end

  defp slot_result(%{slot: nil} = assigns) do
    ~H"""
    <span class="text-base-content/30 text-sm">—</span>
    """
  end

  defp slot_result(assigns) do
    ~H"""
    <span class="flex items-center gap-2 min-w-0">
      <span class="text-2xl shrink-0">{@slot.flag}</span>
      <span class="flex flex-col items-end leading-tight min-w-0">
        <span class="font-semibold truncate">{@slot.team}</span>
        <span class="text-xs text-base-content/50">{@slot.odds}</span>
      </span>
    </span>
    """
  end

  attr :awards, :list, required: true

  defp awards(assigns) do
    ~H"""
    <section class="card bg-base-100 shadow-md">
      <div class="card-body">
        <h2 class="card-title">💰 Prize Pool</h2>
        <div class="grid gap-4 sm:grid-cols-3">
          <div
            :for={award <- @awards}
            class={[
              "rounded-box border p-4 text-center space-y-1",
              award.pct < 0 && "border-error/40 bg-error/5",
              award.pct >= 0 && "border-base-200"
            ]}
          >
            <div class={[
              "text-4xl font-black",
              award.pct < 0 && "text-error",
              award.pct >= 0 && "text-primary"
            ]}>
              {format_pct(award.pct)}
            </div>
            <div class="font-semibold">{award.title}</div>
            <div class="text-sm text-base-content/60">{award.desc}</div>
          </div>
        </div>
        <p class="text-xs text-base-content/50 pt-1">
          Wooden-spoon penalties: the offending player pays an extra 10% into the pot.
        </p>
      </div>
    </section>
    """
  end

  # "80%" for prizes, "−10%" for penalties (true minus sign, not a hyphen).
  defp format_pct(pct) when pct < 0, do: "−#{abs(pct)}%"
  defp format_pct(pct), do: "#{pct}%"

  attr :players, :list, required: true
  attr :pledges, :map, required: true
  attr :selected_player, :string, required: true
  attr :awards, :list, required: true

  defp contributions(assigns) do
    pledged = Map.values(assigns.pledges)
    lowest = (pledged != [] && Enum.min(pledged)) || nil

    # Each wooden spoon is an extra X% of the pot the offender pays in; the worst
    # case is landing all of them at once.
    penalty_pct =
      assigns.awards |> Enum.map(& &1.pct) |> Enum.filter(&(&1 < 0)) |> Enum.sum() |> abs()
    pot = (lowest && lowest * length(assigns.players)) || 0
    max_penalty = round(pot * penalty_pct / 100)

    assigns = assign(assigns, lowest: lowest, max_penalty: max_penalty)

    ~H"""
    <section class="card bg-base-100 shadow-md">
      <div class="card-body gap-4">
        <h2 class="card-title">🤝 Pot Contributions</h2>
        <p class="text-sm text-base-content/60">
          Pick who you are and what you're prepared to pay in. Everyone contributes the
          <span class="font-semibold">lowest</span>
          pledge on the board — so no one pays more than the cheapest player will.
        </p>

        <form phx-submit="pledge" class="flex flex-col gap-3 sm:flex-row sm:items-end">
          <label class="form-control w-full sm:max-w-xs">
            <span class="label-text mb-1">You are</span>
            <select
              name="player"
              class="select select-bordered"
              phx-change="select_player"
            >
              <option
                :for={player <- @players}
                value={player}
                selected={player == @selected_player}
              >
                {player}
              </option>
            </select>
          </label>

          <label class="form-control w-full sm:max-w-[10rem]">
            <span class="label-text mb-1">Prepared to pay</span>
            <div class="join">
              <span class="join-item btn btn-disabled no-animation">£</span>
              <input
                type="number"
                name="amount"
                min="1"
                step="0.50"
                inputmode="decimal"
                placeholder="10"
                class="input input-bordered join-item w-full"
                required
              />
            </div>
          </label>

          <button type="submit" class="btn btn-primary">Pledge</button>
        </form>

        <div
          :if={@lowest}
          class="rounded-box bg-success/10 border border-success/30 p-4 text-center"
        >
          <div class="text-sm text-base-content/60">Agreed contribution per player</div>
          <div class="text-3xl font-black text-success">{format_pence(@lowest)}</div>
          <div class="text-xs text-base-content/50">
            {format_pence(@lowest * length(@players))} total pot across {length(@players)} players
          </div>
          <div :if={@max_penalty > 0} class="text-xs text-error/80 pt-1">
            Land every wooden spoon and you could pay an extra {format_pence(@max_penalty)} into the pot.
          </div>
        </div>

        <ul class="divide-y divide-base-200">
          <li
            :for={player <- @players}
            class={[
              "flex items-center justify-between gap-3 py-2 px-2 rounded-md",
              @lowest && Map.get(@pledges, player) == @lowest && "bg-success/15"
            ]}
          >
            <span class="font-medium truncate">{player}</span>
            <span class="flex items-center gap-2">
              <%= case Map.get(@pledges, player) do %>
                <% nil -> %>
                  <span class="text-base-content/30 text-sm">no pledge yet</span>
                <% pence -> %>
                  <span class="font-mono font-semibold tabular-nums">{format_pence(pence)}</span>
                  <span
                    :if={pence == @lowest}
                    class="badge badge-success badge-sm"
                  >
                    lowest
                  </span>
              <% end %>
            </span>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp active?(nil, _pot, _player), do: false
  defp active?(current, pot, player), do: current.pot == pot and current.player == player

  # Teams in `pot` not yet locked in on the board — the pool the selector
  # tickers through. Includes the team currently spinning (it locks on reveal).
  defp remaining_teams(pots, board, pot) do
    taken =
      for {{p, _player}, slot} <- board, p == pot, into: MapSet.new(), do: slot.flag

    pots
    |> Map.get(pot, [])
    |> Enum.reject(fn team -> MapSet.member?(taken, team.flag) end)
  end
end
