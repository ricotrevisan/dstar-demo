defmodule DstarDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DstarDemoWeb.Telemetry,
      DstarDemo.Repo,
      Dstar.Utility.StreamRegistry,
      {DNSCluster, query: Application.get_env(:dstar_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DstarDemo.PubSub},
      DstarDemoWeb.Presence,
      DstarDemo.Inbox,
      DstarDemo.ChaosLab.Server,
      # Start a worker by calling: DstarDemo.Worker.start_link(arg)
      # {DstarDemo.Worker, arg},
      # Start to serve requests, typically the last entry
      DstarDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DstarDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DstarDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
