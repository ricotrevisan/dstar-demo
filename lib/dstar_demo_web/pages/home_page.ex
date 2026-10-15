defmodule DstarDemoWeb.HomePage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 text-base-content">
      <div class="mx-auto w-full max-w-[1100px] px-5 py-10 sm:px-8">
        <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 pb-5">
          <a href={~p"/"} class="flex items-center gap-2.5 text-sm font-semibold tracking-tight">
            <span class="grid size-7 place-items-center bg-primary text-primary-content">
              <.icon name="hero-bolt-micro" class="size-4" />
            </span>
            Dstar Demo
          </a>
          <Layouts.theme_toggle />
        </header>

        <h1 class="mt-10 max-w-[68ch] text-4xl font-semibold tracking-tight sm:text-5xl">
          Dstar server UI showcase
        </h1>
        <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">
          <a
            href="https://hexdocs.pm/dstar"
            class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
          >
            Dstar
          </a>
          is an Elixir library that renders Phoenix pages over <a
            href="https://data-star.dev"
            class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
          >Datastar</a>, a hypermedia framework: the browser sends signals, the server
          answers with HTML patches over SSE, and no client-side component or virtual-DOM
          application is required.
        </p>
        <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">
          The showcase focuses on interactions that make Datastar's model visible: client signals,
          progressive SSE responses, explicit DOM patches, live collections, and multi-tab presence.
          Smaller application patterns live in <a
            href={~p"/examples"}
            class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
          >Examples / Reference</a>.
        </p>

        <a
          id="explainer-link"
          href={~p"/explained/dx"}
          class="group mt-8 flex items-center justify-between gap-4 border border-primary/40 bg-primary/10 px-5 py-4 transition hover:border-primary"
        >
          <span>
            <span class="block text-base font-semibold tracking-tight">
              New here? Watch an inbox grow up in LiveView and Dstar
            </span>
            <span class="mt-1 block text-sm text-base-content/70">
              Follow the arrows: login, a layout sidebar, live tabs and a deploy, in both models.
            </span>
          </span>
          <.icon
            name="hero-arrow-right"
            class="size-5 shrink-0 transition group-hover:translate-x-0.5"
          />
        </a>

        <section id="showcase-map" class="mt-10 grid border-t border-l border-base-300 sm:grid-cols-2">
          <.demo_tile
            title="Live Collections"
            href={~p"/collections"}
            icon="hero-rectangle-stack"
            body="Each filtered tab reloads with its own signals after one tiny PubSub nudge."
          />
          <.demo_tile
            title="Progressive SSE"
            href={~p"/streaming"}
            icon="hero-signal"
            body="One ordinary POST streams many patches, completes, and leaves no page process resident."
          />
          <.demo_tile
            title="Patch & Morph Lab"
            href={~p"/patch-lab"}
            icon="hero-squares-plus"
            body="Watch explicit selectors, insertion modes, replacement, and removal change the DOM."
          />
          <.demo_tile
            title="Signal-native UI"
            href={~p"/signals"}
            icon="hero-adjustments-horizontal"
            body="Client-owned reactive state meets server reconciliation and targeted HTML patches."
          />
          <.demo_tile
            title="Presence Room"
            href={~p"/presence"}
            icon="hero-user-group"
            body="Multiple tabs join one room, update the roster, and send collaborative pings."
          />
          <.demo_tile
            title="Examples / Reference"
            href={~p"/examples"}
            icon="hero-book-open"
            body="Copyable patterns for forms, search, components, scripts, and authentication."
          />
        </section>
      </div>
    </div>

    <%!-- After the content, so crawlers and unfurlers read the H1 first. --%>
    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :title, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :body, :string, required: true

  def demo_tile(assigns) do
    ~H"""
    <a
      href={@href}
      class="group border-r border-b border-base-300 p-5 transition hover:bg-base-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus:ring-inset"
    >
      <div class="flex items-center gap-2.5">
        <.icon
          name={@icon}
          class="size-5 shrink-0 text-base-content/45 transition group-hover:text-primary"
        />
        <h2 class="text-base font-semibold tracking-tight">{@title}</h2>
      </div>
      <p class="mt-2 max-w-[52ch] text-sm leading-6 text-base-content/65">{@body}</p>
    </a>
    """
  end
end
