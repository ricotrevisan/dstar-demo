defmodule DstarDemoWeb.HomePage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

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
          Eight focused Dstar.Page modules for commands, signals, element patches, streaming,
          components, and presence — each page is one module and one router line, shown beside
          how Phoenix LiveView would solve the same problem.
        </p>

        <section id="map" class="mt-10 grid border-t border-l border-base-300 sm:grid-cols-2">
          <.demo_tile
            title="Form Validation"
            href={~p"/commands"}
            icon="hero-clipboard-document-check"
            body="A native form submits fields with contentType: 'form' and patches feedback only."
          />
          <.demo_tile
            title="Active Search"
            href={~p"/search"}
            icon="hero-magnifying-glass"
            body="Typing sends signals and patches only the result panel."
          />
          <.demo_tile
            title="Streaming Dashboard"
            href={~p"/streaming"}
            icon="hero-signal"
            body="handle_connect and handle_info drive a bounded, deduplicated SSE stream."
          />
          <.demo_tile
            title="Patch Lab"
            href={~p"/patch-lab"}
            icon="hero-squares-plus"
            body="outer, inner, append, prepend, before, after, and remove."
          />
          <.demo_tile
            title="Server Components"
            href={~p"/components"}
            icon="hero-cube-transparent"
            body="A Dstar.Component colocates shared UI with its event handlers."
          />
          <.demo_tile
            title="Signals Inspector"
            href={~p"/signals"}
            icon="hero-adjustments-horizontal"
            body="patch_signals, remove_signals, and the signals handed to handle_event."
          />
          <.demo_tile
            title="Script Helpers"
            href={~p"/scripts"}
            icon="hero-code-bracket-square"
            body="execute_script, console_log, and a safe redirect target."
          />
          <.demo_tile
            title="Presence Room"
            href={~p"/presence"}
            icon="hero-user-group"
            body="Multiple tabs join one room, update the roster, and send pings."
          />
        </section>
      </div>
    </div>
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
