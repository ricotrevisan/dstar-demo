defmodule DstarDemoWeb.DemoComponents do
  @moduledoc false

  use Phoenix.Component

  import DstarDemoWeb.CoreComponents
  import DstarDemoWeb.CodeHighlight, only: [highlight: 2]

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
  attr :eyebrow, :string, required: true
  attr :summary, :string, required: true
  attr :signals, :map, default: nil, doc: "initial Datastar signals, rendered as data-signals"
  attr :rest, :global

  slot :aside
  slot :inner_block, required: true

  def demo_shell(assigns) do
    assigns = assign(assigns, :demos, @demos)

    ~H"""
    <main class="min-h-screen bg-zinc-950 text-zinc-100">
      <div class="mx-auto grid min-h-screen w-full max-w-7xl grid-rows-[auto_1fr]">
        <header class="flex flex-col gap-4 border-b border-zinc-800/80 px-4 py-4 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
          <a href={~p"/"} class="flex w-fit items-center gap-2 text-sm font-semibold text-zinc-100">
            <span class="grid size-8 place-items-center rounded-md bg-emerald-300 text-zinc-950">
              <.icon name="hero-bolt" class="size-4" />
            </span>
            <span>Dstar Demo</span>
          </a>

          <nav class="flex gap-1 overflow-x-auto pb-1 text-sm lg:pb-0" aria-label="Demo sections">
            <a
              :for={{label, href, icon} <- @demos}
              href={href}
              class={[
                "flex shrink-0 items-center gap-2 rounded-md px-3 py-2 transition focus:outline-none focus:ring-2 focus:ring-emerald-300/60",
                @active == label && "bg-zinc-100 text-zinc-950",
                @active != label && "text-zinc-400 hover:bg-zinc-900 hover:text-zinc-100"
              ]}
            >
              <.icon name={icon} class="size-4" />
              <span>{label}</span>
            </a>
          </nav>
        </header>

        <section
          data-signals={@signals && Jason.encode!(@signals)}
          class="grid gap-6 px-4 py-5 sm:px-6 lg:grid-cols-[280px_minmax(0,1fr)] lg:px-8"
          {@rest}
        >
          <aside class="lg:sticky lg:top-5 lg:self-start">
            <div class="space-y-5 border-b border-zinc-800 pb-5 lg:border-b-0 lg:border-r lg:pb-0 lg:pr-6">
              <div>
                <p class="text-xs font-semibold tracking-[0.16em] text-emerald-300 uppercase">
                  {@eyebrow}
                </p>
                <h1 class="mt-3 text-3xl font-semibold leading-tight text-zinc-50 sm:text-4xl">
                  {@title}
                </h1>
                <p class="mt-3 max-w-prose text-sm leading-6 text-zinc-400">
                  {@summary}
                </p>
              </div>
              {render_slot(@aside)}
            </div>
          </aside>

          <div class="min-w-0 pb-8">
            {render_slot(@inner_block)}
          </div>
        </section>
      </div>
    </main>
    """
  end

  attr :items, :list, required: true

  def demo_facts(assigns) do
    ~H"""
    <div class="grid gap-2 text-sm text-zinc-300">
      <div
        :for={item <- @items}
        class="flex items-start gap-2 rounded-md border border-zinc-800 bg-zinc-900/60 px-3 py-2"
      >
        <.icon name="hero-check-circle-micro" class="mt-0.5 size-4 shrink-0 text-emerald-300" />
        <span>{item}</span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "neutral"
  attr :rest, :global

  def pill(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold",
        @tone == "good" && "bg-emerald-300 text-zinc-950",
        @tone == "warn" && "bg-amber-300/15 text-amber-200",
        @tone == "bad" && "bg-rose-400/15 text-rose-200",
        @tone == "info" && "bg-sky-300/15 text-sky-200",
        @tone == "neutral" && "bg-zinc-800 text-zinc-300"
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
    <div
      id={@id}
      class={[
        "rounded-lg border px-4 py-3 transition",
        @tone == "good" && "border-emerald-300/30 bg-emerald-300/10",
        @tone == "warn" && "border-amber-300/30 bg-amber-300/10",
        @tone == "info" && "border-sky-300/30 bg-sky-300/10",
        @tone == "neutral" && "border-zinc-800 bg-zinc-900"
      ]}
    >
      <p class="text-xs font-semibold tracking-[0.14em] text-zinc-500 uppercase">{@title}</p>
      <p class="mt-2 text-2xl font-semibold text-zinc-50">{@value}</p>
      <p class="mt-1 text-sm text-zinc-400">{@detail}</p>
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
        "inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition focus:outline-none focus:ring-2 focus:ring-emerald-300/60",
        @active && "bg-emerald-300 text-zinc-950 hover:bg-emerald-200",
        !@active && "border border-zinc-700 text-zinc-200 hover:border-zinc-500 hover:bg-zinc-900"
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
