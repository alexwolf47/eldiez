defmodule ElDiezWorldCup.Sweepstakes do
  @moduledoc """
  The Sweepstakes context: the static game data (players, teams, pots, awards)
  plus persistence helpers for the draw configuration and results.

  Pots are built from the World Cup 2026 outright winner odds (best available
  price per team, source: Oddschecker). The 40 shortest-priced teams are split
  into four pots of ten — Pot 1 is the top 10 favourites, Pot 2 the next 10, and
  so on. Each of the ten players draws exactly one team from each pot.
  """

  import Ecto.Query, warn: false

  alias ElDiezWorldCup.Repo
  alias ElDiezWorldCup.Sweepstakes.{Assignment, Setting}

  @players [
    "Alex",
    "Andrew Smith",
    "Dan Cowen",
    "Greg Luetchford",
    "Joe O'Gorman",
    "John Campbell",
    "Jonny Kingsley",
    "Jonny Warburton",
    "Josh Richards",
    "Paul Mabey"
  ]

  # {name, odds, flag} ordered by best available outright price (favourites first).
  @teams [
    {"Spain", "5/1", "🇪🇸"},
    {"France", "6/1", "🇫🇷"},
    {"England", "17/2", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"},
    {"Portugal", "9/1", "🇵🇹"},
    {"Brazil", "10/1", "🇧🇷"},
    {"Argentina", "11/1", "🇦🇷"},
    {"Germany", "16/1", "🇩🇪"},
    {"Netherlands", "20/1", "🇳🇱"},
    {"Belgium", "45/1", "🇧🇪"},
    {"Mexico", "66/1", "🇲🇽"},
    {"Japan", "81/1", "🇯🇵"},
    {"USA", "85/1", "🇺🇸"},
    {"Uruguay", "90/1", "🇺🇾"},
    {"Ecuador", "100/1", "🇪🇨"},
    {"Croatia", "125/1", "🇭🇷"},
    {"Senegal", "150/1", "🇸🇳"},
    {"Switzerland", "150/1", "🇨🇭"},
    {"Norway", "150/1", "🇳🇴"},
    {"Morocco", "150/1", "🇲🇦"},
    {"Austria", "175/1", "🇦🇹"},
    {"Colombia", "250/1", "🇨🇴"},
    {"Canada", "250/1", "🇨🇦"},
    {"Turkey", "250/1", "🇹🇷"},
    {"Sweden", "275/1", "🇸🇪"},
    {"Ivory Coast", "300/1", "🇨🇮"},
    {"Scotland", "300/1", "🏴󠁧󠁢󠁳󠁣󠁴󠁿"},
    {"Czech Republic", "500/1", "🇨🇿"},
    {"Paraguay", "500/1", "🇵🇾"},
    {"Algeria", "500/1", "🇩🇿"},
    {"South Korea", "500/1", "🇰🇷"},
    {"Egypt", "500/1", "🇪🇬"},
    {"Australia", "600/1", "🇦🇺"},
    {"Bosnia and Herzegovina", "600/1", "🇧🇦"},
    {"Ghana", "650/1", "🇬🇭"},
    {"Saudi Arabia", "1000/1", "🇸🇦"},
    {"South Africa", "1000/1", "🇿🇦"},
    {"Tunisia", "1000/1", "🇹🇳"},
    {"Iran", "1000/1", "🇮🇷"},
    {"DR Congo", "1000/1", "🇨🇩"},
    {"Cape Verde", "2000/1", "🇨🇻"}
  ]

  @pot_size 10
  @pot_count 4

  @awards [
    %{pct: 80, title: "Outright Winner", desc: "Player whose team lifts the World Cup."},
    %{pct: 25, title: "Top Goalscorer", desc: "Player holding the team of the tournament's top scorer."},
    %{
      pct: 25,
      title: "Goal of the Tournament",
      desc: "Player holding the team of the Goal of the Tournament scorer."
    },
    %{pct: -10, title: "Most Red Cards", desc: "Player whose team picks up the most red cards."},
    %{
      pct: -10,
      title: "Most Goals Conceded",
      desc: "Player whose team concedes the most goals."
    },
    %{
      pct: -10,
      title: "Fewest Goals Scored",
      desc: "Player whose team scores the fewest goals."
    }
  ]

  @doc "The ten sweepstakes players, in draw order."
  def players, do: @players

  @doc "The number of pots and pot size."
  def pot_count, do: @pot_count
  def pot_size, do: @pot_size

  @doc "All teams as maps with a 1-based overall `rank`."
  def teams do
    @teams
    |> Enum.with_index(1)
    |> Enum.map(fn {{name, odds, flag}, rank} ->
      %{rank: rank, name: name, odds: odds, flag: flag, pot: div(rank - 1, @pot_size) + 1}
    end)
  end

  @doc "Map of pot number => list of team maps for that pot."
  def pots do
    teams() |> Enum.group_by(& &1.pot)
  end

  @doc "Teams in a single pot (1..4)."
  def pot(n), do: Map.get(pots(), n, [])

  @doc "The prize-pool award breakdown."
  def awards, do: @awards

  @doc """
  Builds the full, deterministic draw plan for a given `seed`.

  Returns an ordered list of slot maps (Pot 1 for all players first, then Pot 2,
  and so on). Within each pot both the team assignment *and* the order in which
  players are drawn are shuffled, so no player is ever called first by default.
  The same seed always yields the same plan, so the in-progress draw can be
  rebuilt verbatim after a server restart.
  """
  def build_plan(seed) when is_integer(seed) do
    :rand.seed(:exsss, {seed, seed + 7, seed + 13})

    Enum.flat_map(1..@pot_count, fn pot ->
      teams = Enum.shuffle(pot(pot))
      players = Enum.shuffle(@players)

      players
      |> Enum.with_index()
      |> Enum.map(fn {player, idx} ->
        team = Enum.at(teams, idx)

        %{
          pot: pot,
          position: idx,
          player: player,
          team: team.name,
          flag: team.flag,
          odds: team.odds
        }
      end)
    end)
  end

  @doc "Total number of slots in a complete draw."
  def total_slots, do: @pot_count * @pot_size

  # --- Persistence -----------------------------------------------------------

  @doc "Fetches the singleton settings row, creating it on first use."
  def get_setting do
    case Repo.get(Setting, 1) do
      nil -> Repo.insert!(%Setting{id: 1, status: "pending"})
      setting -> setting
    end
  end

  @doc "Updates the singleton settings row."
  def update_setting(attrs) do
    get_setting()
    |> Setting.changeset(attrs)
    |> Repo.update!()
  end

  @doc "All persisted assignments, ordered by pot then draw position."
  def list_assignments do
    Repo.all(from a in Assignment, order_by: [asc: a.pot, asc: a.position])
  end

  @doc "Persists a single drawn slot."
  def create_assignment(attrs) do
    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Clears all results and returns the game to the `pending` state."
  def reset! do
    Repo.delete_all(Assignment)
    update_setting(%{status: "pending", scheduled_at: nil, seed: nil})
  end
end
