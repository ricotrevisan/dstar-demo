defmodule ExplainerBenchWeb.ControlController do
  @moduledoc """
  The benchmark's control plane. Everything here describes the server VM
  only — the load generator runs in a separate OS process.
  """
  use Phoenix.Controller, formats: [:json]

  alias ExplainerBench.Stats

  def health(conn, _params), do: json(conn, %{ok: true})

  def env(conn, _params) do
    json(conn, %{
      otp_release: to_string(:erlang.system_info(:otp_release)),
      erts_version: to_string(:erlang.system_info(:version)),
      elixir: System.version(),
      schedulers: :erlang.system_info(:schedulers_online),
      logical_processors: :erlang.system_info(:logical_processors_available),
      system_architecture: to_string(:erlang.system_info(:system_architecture)),
      deps:
        Map.new(~w(phoenix phoenix_live_view bandit dstar)a, fn app ->
          {app, app |> Application.spec(:vsn) |> to_string()}
        end)
    })
  end

  # ?gc=1 garbage-collects every process first, so memory reads as what is
  # actually retained rather than whenever each heap last happened to GC.
  def metrics(conn, params) do
    if params["gc"] == "1", do: Enum.each(Process.list(), &:erlang.garbage_collect/1)

    {runtime_ms, _} = :erlang.statistics(:runtime)
    {reductions, _} = :erlang.statistics(:reductions)

    json(conn, %{
      memory: Map.new(:erlang.memory()),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count),
      runtime_ms: runtime_ms,
      reductions: reductions,
      stats: Stats.snapshot(),
      conns: %{
        liveview: Registry.count_match(ExplainerBench.Conns, :liveview, :_),
        dstar: Registry.count_match(ExplainerBench.Conns, :dstar, :_)
      }
    })
  end

  # A deploy, as the clients see it: every long-lived connection closes at
  # once. Killing the connection's owner process closes its TCP socket.
  def drop(conn, _params) do
    pids =
      for key <- [:liveview, :dstar],
          {_registrant, pid} <- Registry.lookup(ExplainerBench.Conns, key),
          do: pid

    pids = Enum.uniq(pids)
    Enum.each(pids, &Process.exit(&1, :kill))
    json(conn, %{dropped: length(pids)})
  end
end
