import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :dstar_demo, DstarDemoWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "el61WClw/zQkxJwDCcyaK8s3IJKjz0Cw8dKyTwCQxn4NW0KICn+rvc7fYNMo1ATz",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:dstar_demo, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:dstar_demo, ~w(--watch)]}
  ]

# ## SSL Support
#
# Local HTTPS is handled by config/runtime.exs: it adds an HTTPS listener
# on PORT+1 automatically when certificate files exist — either
# priv/cert/localhost{-key}.pem (mkcert, see the README) or
# priv/cert/selfsigned{_key}.pem (`mix dstar.https` / `mix phx.gen.cert`).
# Set HTTPS=false to disable, or SSL_KEY_PATH/SSL_CERT_PATH to override.

# Reload browser tabs when matching files change.
config :dstar_demo, DstarDemoWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      # Static assets, except user uploads
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      # Gettext translations
      ~r"priv/gettext/.*\.po$"E,
      # Router, Dstar pages, controllers, and components
      ~r"lib/dstar_demo_web/router\.ex$"E,
      ~r"lib/dstar_demo_web/(controllers|live|components|pages)/.*\.(ex|heex)$"E
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :dstar_demo, dev_routes: true

# Relay Dstar page event handler crashes to the browser console
config :dstar, debug_errors: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
