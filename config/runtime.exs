import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dstar_demo start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dstar_demo, DstarDemoWeb.Endpoint, server: true
end

port = String.to_integer(System.get_env("PORT", "4000"))

# config/test.exs pins its own port (4002) so tests never collide with a
# running dev server — don't override it here.
if config_env() != :test do
  config :dstar_demo, DstarDemoWeb.Endpoint, http: [port: port]
end

# In development, automatically enable local HTTPS when certificate files
# exist — either the mkcert names from the README or the names written by
# `mix dstar.https` and `mix phx.gen.cert`. HTTPS listens one port higher
# than PORT, so PORT=4000 serves HTTP on 4000 and HTTPS on 4001.
{dev_ssl_key_path, dev_ssl_cert_path} =
  case {System.get_env("SSL_KEY_PATH"), System.get_env("SSL_CERT_PATH")} do
    {nil, nil} ->
      [
        {"priv/cert/localhost-key.pem", "priv/cert/localhost.pem"},
        {"priv/cert/selfsigned_key.pem", "priv/cert/selfsigned.pem"}
      ]
      |> Enum.find({nil, nil}, fn {key, cert} ->
        File.exists?(key) and File.exists?(cert)
      end)

    {key, cert} ->
      {key || "priv/cert/localhost-key.pem", cert || "priv/cert/localhost.pem"}
  end

https_enabled? =
  config_env() == :dev and
    String.downcase(System.get_env("HTTPS", "true")) in ["1", "true", "yes", "on"] and
    is_binary(dev_ssl_key_path) and File.exists?(dev_ssl_key_path) and
    is_binary(dev_ssl_cert_path) and File.exists?(dev_ssl_cert_path)

if https_enabled? do
  config :dstar_demo, DstarDemoWeb.Endpoint,
    https: [
      ip: {127, 0, 0, 1},
      port: port + 1,
      cipher_suite: :strong,
      keyfile: dev_ssl_key_path,
      certfile: dev_ssl_cert_path
    ]
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :dstar_demo, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :dstar_demo, DstarDemoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :dstar_demo, DstarDemoWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :dstar_demo, DstarDemoWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
