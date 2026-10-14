defmodule ExplainerBench.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    ExplainerBench.Stats.init()

    # The same project is both the server under test and the load generator.
    # Only `mix bench.server` starts the endpoint; the client starts no server
    # state at all, so the two OS processes never share a VM.
    children =
      if Application.get_env(:explainer_bench, :serve, false) do
        [
          {Phoenix.PubSub, name: ExplainerBench.PubSub},
          {Registry, keys: :duplicate, name: ExplainerBench.Conns},
          ExplainerBench.Inbox,
          ExplainerBenchWeb.Endpoint
        ]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: ExplainerBench.Supervisor)
  end
end
