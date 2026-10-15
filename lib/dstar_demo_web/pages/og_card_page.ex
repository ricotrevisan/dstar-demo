defmodule DstarDemoWeb.OgCardPage do
  @moduledoc """
  Dev-only: the 1200×630 social cards for link unfurls, rendered from the
  same components as the pages they advertise.

  To regenerate, run the dev server and screenshot each card at a
  1200×630 viewport into `priv/static/images/og/<card>.png`:

      /dev/og/explained-dx   /dev/og/explained-lab   /dev/og/default
  """
  use DstarDemoWeb, :dstar_page

  alias DstarDemo.ChaosLab
  alias DstarDemoWeb.ExplainedDxPage
  alias DstarDemoWeb.ExplainedLabPage

  @cards %{
    "explained-dx" => %{
      kicker: "Explained · follow the arrows",
      title: "An inbox grows up",
      dek:
        "Login, a layout badge, live tabs and a deploy. Phoenix LiveView 1.8 and Dstar, arrow by arrow."
    },
    "explained-lab" => %{
      kicker: "Explained · the chaos lab",
      title: "Go ahead, break it",
      dek:
        "The same inbox open in six tabs, twice. Deploy, tunnel, revoke, and read the benchmark."
    },
    "default" => %{
      kicker: "Dstar for Phoenix",
      title: "Server UI over Datastar",
      dek:
        "The browser sends signals, the server answers with HTML patches over SSE. No client-side app."
    }
  }

  @impl Dstar.Page
  def mount(conn, %{"card" => card}) do
    assign(conn, card: card, copy: Map.fetch!(@cards, card))
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <link
      rel="stylesheet"
      href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&display=block"
    />
    <div
      id="og-card"
      data-theme="dark"
      class="relative flex h-[630px] w-[1200px] overflow-hidden bg-base-100 text-base-content"
      data-signals={Jason.encode!(%{stage: 4, dxLane: "lv"})}
    >
      <div class="absolute inset-x-0 top-0 h-1.5 bg-primary"></div>
      <div class="flex w-[640px] shrink-0 flex-col justify-between px-16 py-16 [font-family:'Space_Grotesk',ui-sans-serif,system-ui]">
        <div>
          <p class="font-mono text-lg tracking-wide text-base-content/60 uppercase">
            {@copy.kicker}
          </p>
          <h1 class="mt-6 text-[76px] leading-[1.02] font-bold tracking-tight">{@copy.title}</h1>
          <p class="mt-8 text-[28px] leading-[1.35] text-base-content/75">{@copy.dek}</p>
        </div>
        <p class="flex items-center gap-3 text-xl font-semibold">
          <span class="grid size-9 place-items-center bg-primary text-primary-content">
            <.icon name="hero-bolt-micro" class="size-5" />
          </span>
          dstar.nocode-to-knowcode.com
        </p>
      </div>
      <div class="flex min-w-0 flex-1 items-center border-l border-base-300 bg-base-200 px-8">
        <.visual card={@card} />
      </div>
    </div>
    """
  end

  attr :card, :string, required: true

  defp visual(%{card: "explained-lab"} = assigns) do
    lab = ChaosLab.apply_action(ChaosLab.new(), "deploy")
    assigns = assign(assigns, lab: lab)

    ~H"""
    <div class="w-[900px] origin-left scale-[0.55]">
      <ExplainedLabPage.lab lab={@lab} />
    </div>
    """
  end

  defp visual(assigns) do
    assigns =
      assign(assigns,
        stages: [{1, ""}, {2, ""}, {3, ""}, {4, "Other tabs want to know"}, {5, ""}],
        bench: ExplainedDxPage.bench_memory()
      )

    ~H"""
    <div class="mx-auto w-[400px] [&_#dx-diagram>div:first-child]:hidden [&_#dx-diagram>p:last-child]:hidden">
      <ExplainedDxPage.arrows stages={@stages} bench={@bench} />
    </div>
    """
  end
end
