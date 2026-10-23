defmodule DstarDemoWeb.Explainers do
  @moduledoc """
  The long-form `/explained/*` posts, in reading order. The `/explained`
  index and the sitemap both read this list, so a new explainer only needs
  an entry here and a route.
  """

  @explainers [
    %{
      path: "/",
      title: "Simple and reactive Phoenix pages",
      kicker: "An inbox grows up",
      summary:
        "Login, a layout badge, live tabs and a deploy, built with Phoenix LiveView 1.8 and with Dstar. What staying connected costs, and who pays it.",
      published: ~D[2026-10-14]
    },
    %{
      path: "/explained/lab",
      title: "Go ahead, break it",
      kicker: "The chaos lab",
      summary:
        "The same inbox open in six tabs, twice. Deploy, drive a tab into a tunnel, revoke a session, and read the benchmark.",
      published: ~D[2026-10-14]
    }
  ]

  def all, do: @explainers
end
