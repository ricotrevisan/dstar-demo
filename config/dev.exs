import Config

# The shared local Postgres (infra-postgres, see ~/dev/devops/infra).
config :dstar_demo, DstarDemo.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "dstar_demo_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
port = System.get_env("PORT", "4000") |> String.to_integer()

config :dstar_demo, DstarDemoWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: port],
  url: [host: "dstar-demo.localhost", scheme: "https", port: 443],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "el61WClw/zQkxJwDCcyaK8s3IJKjz0Cw8dKyTwCQxn4NW0KICn+rvc7fYNMo1ATz",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:dstar_demo, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:dstar_demo, ~w(--watch)]}
  ]

# Reload browser tabs when matching files change.
config :dstar_demo, DstarDemoWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      # Static assets, except user uploads
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      # Gettext translations
      ~r"priv/gettext/.*\.po$",
      # Router, Dstar pages, controllers, and components
      ~r"lib/dstar_demo_web/router\.ex$",
      ~r"lib/dstar_demo_web/(controllers|live|components|pages)/.*\.(ex|heex)$"
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
