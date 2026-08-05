defmodule DstarDemo.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @env_keys ~w(PORT PHX_SERVER SECRET_KEY_BASE PHX_HOST DNS_CLUSTER_QUERY)

  test "dev endpoint port comes from PORT" do
    endpoint_config = read_endpoint_config!(%{"PORT" => "4123"})

    assert get_in(endpoint_config, [:http, :port]) == 4123
  end

  test "test env leaves the endpoint port to config/test.exs" do
    endpoint_config = read_endpoint_config!(%{"PORT" => "4123"}, env: :test)

    # test.exs pins port 4002 to avoid clashing with a running dev server;
    # an unconditional PORT override here would silently clobber it.
    refute get_in(endpoint_config || [], [:http, :port])
  end

  defp read_endpoint_config!(env, opts \\ []) do
    saved_env = Map.new(@env_keys, fn key -> {key, System.get_env(key)} end)
    config_path = Path.expand("config/runtime.exs")
    config_env = Keyword.get(opts, :env, :dev)

    read = fn ->
      config_path
      |> Config.Reader.read!(env: config_env)
      |> get_in([:dstar_demo, DstarDemoWeb.Endpoint])
    end

    try do
      Enum.each(@env_keys, &System.delete_env/1)
      System.put_env(env)
      read.()
    after
      restore_env(saved_env)
    end
  end

  defp restore_env(saved_env) do
    Enum.each(saved_env, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)
  end
end
