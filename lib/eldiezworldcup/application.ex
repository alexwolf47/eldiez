defmodule ElDiezWorldCup.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElDiezWorldCupWeb.Telemetry,
      ElDiezWorldCup.Repo,
      {DNSCluster, query: Application.get_env(:eldiezworldcup, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElDiezWorldCup.PubSub},
      # Owns the live draw state machine (paces reveals, persists results).
      ElDiezWorldCup.Sweepstakes.DrawServer,
      # Holds the live, per-player prize-pot contribution pledges.
      ElDiezWorldCup.Sweepstakes.ContributionServer,
      # Start to serve requests, typically the last entry
      ElDiezWorldCupWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElDiezWorldCup.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElDiezWorldCupWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
