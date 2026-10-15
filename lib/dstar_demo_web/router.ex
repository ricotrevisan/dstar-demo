defmodule DstarDemoWeb.Router do
  use DstarDemoWeb, :router

  import Dstar.Router

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

    dstar("/", HomePage)
    dstar("/showcase", ShowcasePage)
    dstar("/explained", ExplainedIndexPage)
    dstar("/explained/lab", ExplainedLabPage)
    dstar("/examples", ExamplesPage)
    dstar("/collections", LiveCollectionsPage)
    dstar("/commands", CommandsPage)
    dstar("/search", ActiveSearchPage)
    dstar("/streaming", StreamingDashboardPage)
    dstar("/patch-lab", PatchLabPage)
    dstar("/components", ServerComponentsPage)
    dstar("/signals", SignalsPage)
    dstar("/scripts", ScriptsPage)
    dstar("/auth", AuthFlowPage)
    dstar("/presence", PresencePage)

    dstar_components("/ds", [ComponentStage])
  end

  scope "/", DstarDemoWeb do
    get "/sitemap.xml", SitemapController, :index

    # The inbox story was /explained/dx before it became the home page.
    get "/explained/dx", RedirectController, :permanent, assigns: %{to: "/"}
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

    # Renders the 1200×630 social cards in priv/static/images/og/.
    # See DstarDemoWeb.OgCardPage for how to regenerate them.
    scope "/dev", DstarDemoWeb do
      pipe_through :browser

      dstar("/og/:card", OgCardPage)
    end
  end
end
