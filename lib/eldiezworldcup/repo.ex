defmodule ElDiezWorldCup.Repo do
  use Ecto.Repo,
    otp_app: :eldiezworldcup,
    adapter: Ecto.Adapters.Postgres
end
