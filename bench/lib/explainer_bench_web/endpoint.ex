defmodule ExplainerBenchWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :explainer_bench

  @session_options [
    store: :cookie,
    key: "_bench_key",
    signing_salt: "explainer-bench",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.Session, @session_options
  plug ExplainerBenchWeb.Router
end
