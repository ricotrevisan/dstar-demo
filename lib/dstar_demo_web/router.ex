defmodule DstarDemoWeb.Router do
  use DstarDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DstarDemoWeb.Layouts, :root}
    plug Dstar.Plugs.RenameCsrfParam
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DstarDemoWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/commands", CommandController, :home
    get "/search", ActiveSearchController, :home
    get "/streaming", StreamingDashboardController, :home
    post "/streaming/stream", StreamingDashboardController, :stream
    get "/patch-lab", PatchLabController, :home
    get "/components", ServerComponentsController, :home
    get "/signals", SignalsController, :home
    get "/scripts", ScriptHelpersController, :home
    post "/ds/:module/:event", Dstar.Dispatch, [], alias: false
  end

  # Other scopes may use custom stacks.
  # scope "/api", DstarDemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:dstar_demo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DstarDemoWeb.Telemetry
    end
  end
end
