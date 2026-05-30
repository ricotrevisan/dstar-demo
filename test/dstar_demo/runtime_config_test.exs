defmodule DstarDemo.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @env_keys ~w(PORT HTTPS SSL_KEY_PATH SSL_CERT_PATH PHX_SERVER SECRET_KEY_BASE PHX_HOST DNS_CLUSTER_QUERY)

  test "dev https uses port one higher than PORT when certificate files exist" do
    cert_dir = tmp_cert_dir!()
    keyfile = Path.join(cert_dir, "localhost-key.pem")
    certfile = Path.join(cert_dir, "localhost.pem")

    File.write!(keyfile, "test key")
    File.write!(certfile, "test cert")

    endpoint_config =
      read_endpoint_config!(%{
        "PORT" => "4123",
        "SSL_KEY_PATH" => keyfile,
        "SSL_CERT_PATH" => certfile
      })

    assert get_in(endpoint_config, [:http, :port]) == 4123
    assert get_in(endpoint_config, [:https, :port]) == 4124
    assert get_in(endpoint_config, [:https, :keyfile]) == keyfile
    assert get_in(endpoint_config, [:https, :certfile]) == certfile
  end

  test "dev https is omitted when certificate files are missing" do
    cert_dir = tmp_cert_dir!()

    endpoint_config =
      read_endpoint_config!(%{
        "PORT" => "4123",
        "SSL_KEY_PATH" => Path.join(cert_dir, "missing-key.pem"),
        "SSL_CERT_PATH" => Path.join(cert_dir, "missing-cert.pem")
      })

    assert get_in(endpoint_config, [:http, :port]) == 4123
    refute Keyword.has_key?(endpoint_config, :https)
  end

  defp read_endpoint_config!(env) do
    saved_env = Map.new(@env_keys, fn key -> {key, System.get_env(key)} end)

    try do
      Enum.each(@env_keys, &System.delete_env/1)
      System.put_env(env)

      "config/runtime.exs"
      |> Config.Reader.read!(env: :dev)
      |> get_in([:dstar_demo, DstarDemoWeb.Endpoint])
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

  defp tmp_cert_dir! do
    cert_dir =
      Path.join(
        System.tmp_dir!(),
        "dstar-demo-runtime-config-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(cert_dir)
    on_exit(fn -> File.rm_rf(cert_dir) end)
    cert_dir
  end
end
