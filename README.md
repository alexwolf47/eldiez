# ElDiezWorldCup

## World Cup 2026 Winner Odds

Best available outright odds per team (source: Oddschecker, as of 11 June 2026), sorted favourites first.

| # | Team | Odds |
|---|------|------|
| 1 | Spain | 5/1 |
| 2 | France | 6/1 |
| 3 | England | 17/2 |
| 4 | Portugal | 9/1 |
| 5 | Brazil | 10/1 |
| 6 | Argentina | 11/1 |
| 7 | Germany | 16/1 |
| 8 | Netherlands | 20/1 |
| 9 | Belgium | 45/1 |
| 10 | Mexico | 66/1 |
| 11 | Japan | 81/1 |
| 12 | USA | 85/1 |
| 13 | Uruguay | 90/1 |
| 14 | Ecuador | 100/1 |
| 15 | Croatia | 125/1 |
| 16 | Senegal | 150/1 |
| 17 | Switzerland | 150/1 |
| 18 | Norway | 150/1 |
| 19 | Morocco | 150/1 |
| 20 | Austria | 175/1 |
| 21 | Colombia | 250/1 |
| 22 | Canada | 250/1 |
| 23 | Turkey | 250/1 |
| 24 | Sweden | 275/1 |
| 25 | Ivory Coast | 300/1 |
| 26 | Scotland | 300/1 |
| 27 | Czech Republic | 500/1 |
| 28 | Paraguay | 500/1 |
| 29 | Algeria | 500/1 |
| 30 | South Korea | 500/1 |
| 31 | Egypt | 500/1 |
| 32 | Australia | 600/1 |
| 33 | Bosnia and Herzegovina | 600/1 |
| 34 | Ghana | 650/1 |
| 35 | Saudi Arabia | 1000/1 |
| 36 | South Africa | 1000/1 |
| 37 | Tunisia | 1000/1 |
| 38 | Iran | 1000/1 |
| 39 | DR Congo | 1000/1 |
| 40 | Cape Verde | 2000/1 |
| 41 | Panama | 2000/1 |
| 42 | Uzbekistan | 2000/1 |
| 43 | Qatar | 2000/1 |
| 44 | New Zealand | 2500/1 |
| 45 | Iraq | 2500/1 |
| 46 | Jordan | 3000/1 |
| 47 | Curacao | 5000/1 |
| 48 | Haiti | 5000/1 |

## Players

1. Alex
2. Andrew Smith
3. Dan Cowen
4. Greg Luetchford
5. Joe O'Gorman
6. John Campbell
7. Jonny Kingsley
8. Jonny Warburton
9. Josh Richards
10. Paul Mabey

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Render

This repo includes a Render Blueprint in `render.yaml`.

The Blueprint deploys:

* `eldiezworldcup` as a Frankfurt (`frankfurt`) Elixir web service on the `starter` plan.
* `eldiezworldcup-db` as a Frankfurt Postgres database on the `basic-256mb` plan with 1 GB disk.

Set these environment variables in Render after creating the Blueprint:

* `SECRET_KEY_BASE`: generate with `mix phx.gen.secret`.
* `PHX_HOST`: the Render hostname or custom domain, without `https://`.
