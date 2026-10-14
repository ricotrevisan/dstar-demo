defmodule ExplainerBenchWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import Dstar.Router

  # Identical for both models: the same session, CSRF and root layout.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {ExplainerBenchWeb.Layouts, :root}
    plug Dstar.Plugs.RenameCsrfParam
    plug :protect_from_forgery
  end

  pipeline :control do
    plug :accepts, ["json"]
  end

  scope "/", ExplainerBenchWeb do
    pipe_through :browser

    live "/lv/inbox", InboxLive
    dstar("/ds/inbox", InboxPage)
  end

  scope "/bench", ExplainerBenchWeb do
    pipe_through :control

    get "/health", ControlController, :health
    get "/env", ControlController, :env
    get "/metrics", ControlController, :metrics
    post "/drop", ControlController, :drop
  end
end
