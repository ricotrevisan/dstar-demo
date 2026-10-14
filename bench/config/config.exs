import Config

config :explainer_bench, ExplainerBenchWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  # Fixed at compile time on purpose: Phoenix validates :http as compile-time
  # config, so run.sh exports the same BENCH_PORT for compile and run.
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("BENCH_PORT", "4100"))],
  # Generated for the benchmark only; never used outside it.
  secret_key_base: String.duplicate("explainer-bench-not-a-secret-", 3),
  live_view: [signing_salt: "explainer-bench"],
  pubsub_server: ExplainerBench.PubSub,
  render_errors: [formats: [html: ExplainerBenchWeb.ErrorHTML], layout: false],
  check_origin: false,
  server: true

config :phoenix, :json_library, Jason

# Request logging costs CPU on both sides of the comparison; keep it off.
config :logger, level: :warning
