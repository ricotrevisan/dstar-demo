defmodule Mix.Tasks.Bench.Server do
  @shortdoc "Starts the server under test (both models) on BENCH_PORT"
  @moduledoc """
  Starts the LiveView and Dstar inbox pages plus the `/bench/*` control
  plane, then blocks. `run.sh` starts a fresh one for every model so no
  run inherits another's memory or warm caches.

      BENCH_PORT=4100 MIX_ENV=prod mix bench.server
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Application.put_env(:explainer_bench, :serve, true)
    Mix.Task.run("app.start")

    port = Application.get_env(:explainer_bench, ExplainerBenchWeb.Endpoint)[:http][:port]
    Mix.shell().info("bench server listening on http://127.0.0.1:#{port}")
    Process.sleep(:infinity)
  end
end
