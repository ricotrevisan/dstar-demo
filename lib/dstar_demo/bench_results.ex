defmodule DstarDemo.BenchResults do
  @moduledoc """
  The benchmark medians shown on `/explained/lab`, embedded at compile time.

  They come from the separate `bench/` project: run `bench/run.sh`, then copy
  `bench/results/<run>/summary.json` to `priv/bench/summary-<tabs>tabs.json`.
  Adding or changing a file recompiles this module.
  """

  @dir Path.expand("../../priv/bench", __DIR__)
  @files @dir |> Path.join("summary-*tabs.json") |> Path.wildcard() |> Enum.sort()

  for file <- @files, do: @external_resource(file)

  @results @files
           |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
           |> Enum.sort_by(& &1["params"]["tabs"])

  def __mix_recompile__? do
    @dir |> Path.join("summary-*tabs.json") |> Path.wildcard() |> Enum.sort() != @files
  end

  @doc "One summary per published run, smallest tab count first."
  def all, do: @results
end
