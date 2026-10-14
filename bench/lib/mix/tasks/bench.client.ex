defmodule Mix.Tasks.Bench.Client do
  @shortdoc "Runs one model's load against a running bench server"
  @moduledoc """
  Runs in its own OS process, so the server's numbers exclude the load
  generator's work.

      MIX_ENV=prod mix bench.client --model liveview --tabs 1000 --clicks 100 \\
        --out results/liveview.json

  Options: `--model` (#{Enum.join(ExplainerBench.Client.Runner.models(), ", ")}),
  `--tabs` (1000), `--clicks` (100), `--concurrency` (100 tabs opening at
  once), `--settle-ms` (2000), `--port` (BENCH_PORT or 4100), `--out`.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          model: :string,
          tabs: :integer,
          clicks: :integer,
          concurrency: :integer,
          settle_ms: :integer,
          port: :integer,
          out: :string
        ]
      )

    Mix.Task.run("app.start")

    result =
      ExplainerBench.Client.Runner.run(%{
        model: Keyword.fetch!(opts, :model),
        tabs: Keyword.get(opts, :tabs, 1000),
        clicks: Keyword.get(opts, :clicks, 100),
        concurrency: Keyword.get(opts, :concurrency, 100),
        settle_ms: Keyword.get(opts, :settle_ms, 2000),
        port: Keyword.get(opts, :port, String.to_integer(System.get_env("BENCH_PORT", "4100")))
      })

    json = Jason.encode!(result, pretty: true)

    case opts[:out] do
      nil ->
        IO.puts(json)

      path ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, json <> "\n")
        Mix.shell().info("wrote #{path}")
    end
  end
end
