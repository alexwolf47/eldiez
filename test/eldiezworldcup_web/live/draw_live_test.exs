defmodule ElDiezWorldCupWeb.DrawLiveTest do
  use ElDiezWorldCupWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ElDiezWorldCup.Sweepstakes.ContributionServer

  setup do
    # Shared in-memory pledge state; clear it so tests don't bleed into each other.
    on_exit(fn -> Enum.each(players(), &ContributionServer.clear_pledge/1) end)
    :ok
  end

  defp players, do: ElDiezWorldCup.Sweepstakes.players()

  test "renders the prize pot and contributions section", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Prize Pool"
    assert html =~ "Pot Contributions"
  end

  test "a pledge appears live and the lowest is highlighted", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    [p1, p2 | _] = players()

    view
    |> form("form[phx-submit=pledge]", player: p1, amount: "20")
    |> render_submit()

    view
    |> form("form[phx-submit=pledge]", player: p2, amount: "12.50")
    |> render_submit()

    html = render(view)
    assert html =~ "£20"
    assert html =~ "£12.50"
    # Lowest pledge becomes the agreed per-player contribution.
    assert html =~ "Agreed contribution per player"
  end
end
