defmodule DstarDemoWeb.DemoComponents do
  @moduledoc false

  use Phoenix.Component

  import DstarDemoWeb.CoreComponents
  import DstarDemoWeb.CodeHighlight, only: [highlight: 2]

  alias DstarDemoWeb.Layouts

  use Phoenix.VerifiedRoutes,
    endpoint: DstarDemoWeb.Endpoint,
    router: DstarDemoWeb.Router,
    statics: DstarDemoWeb.static_paths()

  @demos [
    {"Form Validation", "/commands", "hero-clipboard-document-check-micro"},
    {"Active Search", "/search", "hero-magnifying-glass-micro"},
    {"Streaming Dashboard", "/streaming", "hero-signal-micro"},
    {"Patch Lab", "/patch-lab", "hero-squares-plus-micro"},
    {"Components", "/components", "hero-cube-transparent-micro"},
    {"Signals", "/signals", "hero-adjustments-horizontal-micro"},
    {"Scripts", "/scripts", "hero-code-bracket-square-micro"},
    {"Presence", "/presence", "hero-user-group-micro"}
  ]

  attr :active, :string, required: true
  attr :title, :string, required: true
  attr :summary, :string, required: true
  attr :signals, :map, default: nil, doc: "initial Datastar signals, rendered as data-signals"
  attr :rest, :global

  slot :demo, required: true, doc: "the live, interactive thing"
  slot :how_it_works, required: true, doc: "key points, prose at reading measure, and Dstar code"
  slot :comparison, doc: "optional side-by-side against LiveView"

  def demo_shell(assigns) do
    assigns =
      assigns
      |> assign(:demos, @demos)
      |> assign(:jump_links, jump_links(assigns))

    ~H"""
    <%!-- data-signals and @rest sit on the outermost element, not on #demo.
    Datastar scopes signals to a subtree, and the old shell declared them on a
    section that wrapped both the aside and the content. Keeping them at the top
    preserves that scope exactly, so nothing in :how_it_works or :comparison can
    fall outside it — and the presence page's pagehide beacon still finds
    presenceInstance. A HEEx comment, not an HTML one: this is a note to readers
    of the source, not something every visitor should download. --%>
    <div
      class="min-h-screen bg-base-100 text-base-content"
      data-signals={@signals && Jason.encode!(@signals)}
      {@rest}
    >
      <div class="mx-auto flex w-full max-w-[1400px] flex-col lg:flex-row">
        <div class="border-b border-base-300 lg:w-60 lg:shrink-0 lg:border-b-0 lg:border-r">
          <div class="lg:sticky lg:top-0 lg:flex lg:h-screen lg:flex-col lg:overflow-y-auto">
            <a href={~p"/"} class="flex items-center gap-2.5 px-5 py-4">
              <span class="grid size-7 shrink-0 place-items-center bg-primary text-primary-content">
                <.icon name="hero-bolt-micro" class="size-4" />
              </span>
              <span class="text-sm font-semibold tracking-tight">Dstar Demo</span>
            </a>

            <details class="group border-t border-base-300 lg:hidden">
              <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-5 py-3 text-sm text-base-content/70 [&::-webkit-details-marker]:hidden">
                <span>Demos — {@active}</span>
                <.icon
                  name="hero-chevron-down-micro"
                  class="size-4 shrink-0 transition-transform group-open:rotate-180"
                />
              </summary>
              <.demo_nav demos={@demos} active={@active} />
            </details>

            <div class="hidden lg:block">
              <.demo_nav demos={@demos} active={@active} />
            </div>

            <div class="mt-auto flex justify-center border-t border-base-300 px-5 py-4">
              <Layouts.theme_toggle />
            </div>
          </div>
        </div>

        <main class="min-w-0 flex-1">
          <article class="mx-auto w-full max-w-[1100px] px-5 py-10 sm:px-8">
            <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">{@title}</h1>
            <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">{@summary}</p>

            <nav
              class="mt-6 flex flex-wrap gap-x-5 gap-y-1 border-y border-base-300 py-2.5 text-sm"
              aria-label="On this page"
            >
              <a
                :for={{anchor, label} <- @jump_links}
                href={"##{anchor}"}
                class="text-base-content/60 transition hover:text-primary"
              >
                {label}
              </a>
            </nav>

            <section id="demo" class="mt-10 scroll-mt-6">
              <h2 class="sr-only">Demo</h2>
              {render_slot(@demo)}
            </section>

            <section id="how-it-works" class="mt-14 scroll-mt-6">
              <h2 class="border-b border-base-300 pb-2 text-xl font-semibold tracking-tight">
                How it works
              </h2>
              {render_slot(@how_it_works)}
            </section>

            <section :if={@comparison != []} id="comparison" class="mt-14 scroll-mt-6">
              <h2 class="border-b border-base-300 pb-2 text-xl font-semibold tracking-tight">
                If this were LiveView
              </h2>
              {render_slot(@comparison)}
            </section>
          </article>
        </main>
      </div>
    </div>
    """
  end

  # Derived from which slots the caller populated, so a page without a
  # :comparison renders two links rather than three. No list to keep in sync.
  defp jump_links(assigns) do
    base = [{"demo", "Demo"}, {"how-it-works", "How it works"}]

    if assigns.comparison == [],
      do: base,
      else: base ++ [{"comparison", "LiveView comparison"}]
  end

  attr :demos, :list, required: true
  attr :active, :string, required: true

  defp demo_nav(assigns) do
    ~H"""
    <nav class="flex flex-col pb-5 text-sm" aria-label="Demos">
      <a
        :for={{label, href, icon} <- @demos}
        href={href}
        aria-current={@active == label && "page"}
        class={[
          "flex items-center gap-2.5 border-l-2 px-5 py-2 transition",
          @active == label && "border-primary font-medium text-base-content",
          @active != label &&
            "border-transparent text-base-content/60 hover:border-base-300 hover:text-base-content"
        ]}
      >
        <.icon name={icon} class="size-4 shrink-0 opacity-70" />
        <span>{label}</span>
      </a>
    </nav>
    """
  end

  attr :items, :list, required: true

  @doc """
  The sharpest writing on each page. These were the `:aside` facts; they now
  lead the explanation instead of sitting in a column beside it.
  """
  def key_points(assigns) do
    ~H"""
    <ul class="mt-5 max-w-[68ch] space-y-2">
      <li :for={item <- @items} class="flex gap-2.5 text-sm leading-6 text-base-content/80">
        <span class="mt-2 size-1.5 shrink-0 rounded-full bg-primary" aria-hidden="true"></span>
        <span>{item}</span>
      </li>
    </ul>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  @doc "A paragraph held at reading measure, for use inside :how_it_works."
  def prose(assigns) do
    ~H"""
    <p class={["mt-6 max-w-[68ch] text-base leading-7 text-base-content/80", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "neutral"
  attr :rest, :global

  @doc """
  Tone is carried by the background tint alone. The obvious pairing —
  `bg-success/15` with `text-success-content` — is unreadable in the dark
  theme: daisyUI's `*-content` tokens are foregrounds for the *solid* colour,
  so on a 15% tint over `#0c0c0c` they land around 1.5:1. `text-base-content`
  flips with the theme and clears 4.5:1 over either tint.
  """
  def pill(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center px-2 py-0.5 font-mono text-xs text-base-content",
        @tone == "good" && "bg-success/20",
        @tone == "warn" && "bg-warning/20",
        @tone == "bad" && "bg-error/20",
        @tone == "info" && "bg-info/20",
        @tone == "neutral" && "bg-base-300"
      ]}
      {@rest}
    >
      {@label}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true
  attr :tone, :string, default: "neutral"

  def metric_tile(assigns) do
    ~H"""
    <div id={@id} class="border border-base-300 bg-base-200 px-4 py-3">
      <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">{@title}</p>
      <p class={[
        "mt-2 text-2xl font-semibold tabular-nums",
        @tone == "neutral" && "text-base-content",
        @tone != "neutral" && "text-primary"
      ]}>
        {@value}
      </p>
      <p class="mt-1 text-sm text-base-content/70">{@detail}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :click, :string, required: true
  attr :icon, :string, default: "hero-arrow-path-micro"
  attr :active, :boolean, default: false
  attr :rest, :global

  def action_button(assigns) do
    ~H"""
    <button
      id={@id}
      data-on:click={@click}
      class={[
        "inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm font-medium transition",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
        @active && "border-primary bg-primary text-primary-content",
        !@active &&
          "border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-200"
      ]}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
      <span>{@label}</span>
    </button>
    """
  end

  attr :code, :string, required: true
  attr :language, :string, default: "elixir", values: ~w(elixir heex)
  attr :label, :string, default: nil, doc: "usually the source path the snippet came from"

  def code_block(assigns) do
    ~H"""
    <figure class="hl min-w-0">
      <figcaption
        :if={@label}
        class="border border-base-300 border-b-0 bg-base-200 px-4 py-2 font-mono text-xs text-base-content/70"
      >
        {@label}
      </figcaption>
      <pre
        tabindex="0"
        role="region"
        aria-label={@label || "Code sample"}
        class="overflow-x-auto border border-base-300 bg-base-200 p-4 font-mono text-[13px] leading-6"
      ><code>{highlight(@code, @language)}</code></pre>
    </figure>
    """
  end
end
