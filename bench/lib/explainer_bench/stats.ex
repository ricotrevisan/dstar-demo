defmodule ExplainerBench.Stats do
  @moduledoc """
  Server-side counters for the callbacks each model runs. Lock-free
  `:counters`, so counting does not distort what is being counted.
  """

  @keys [:lv_mount_http, :lv_mount_socket, :ds_mount, :ds_connect, :events]

  def init do
    :persistent_term.put(__MODULE__, :counters.new(length(@keys), [:write_concurrency]))
  end

  def bump(key), do: :counters.add(ref(), index(key), 1)

  def snapshot do
    Map.new(@keys, fn key -> {key, :counters.get(ref(), index(key))} end)
  end

  defp ref, do: :persistent_term.get(__MODULE__)
  defp index(key), do: Enum.find_index(@keys, &(&1 == key)) + 1
end
