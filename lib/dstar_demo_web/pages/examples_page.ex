defmodule DstarDemoWeb.ExamplesPage do
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

        <nav class="mt-8 text-sm" aria-label="Breadcrumb">
          <a
            href={~p"/"}
            class="text-base-content/60 underline decoration-base-content/25 underline-offset-4 transition hover:text-base-content"
          >
            Showcase
          </a>
          <span class="px-2 text-base-content/35" aria-hidden="true">/</span>
          <span class="font-medium text-base-content">Examples / Reference</span>
        </nav>

        <h1 class="mt-6 max-w-[68ch] text-4xl font-semibold tracking-tight sm:text-5xl">
          Examples / Reference
        </h1>
        <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">
          Focused, copyable patterns for familiar application work. These pages explain Dstar's API
          seams and Phoenix integration; the
          <a
            href={~p"/"}
            class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
          >
            showcase
          </a>
          is reserved for the Datastar interactions that are easiest to understand by using them.
        </p>

        <section
          id="reference-map"
          class="mt-10 grid border-t border-l border-base-300 sm:grid-cols-2"
        >
          <DstarDemoWeb.HomePage.demo_tile
            title="Form Validation"
            href={~p"/commands"}
            icon="hero-clipboard-document-check"
            body="Native form submission, debounced checks, and targeted server feedback patches."
          />
          <DstarDemoWeb.HomePage.demo_tile
            title="Active Search"
            href={~p"/search"}
            icon="hero-magnifying-glass"
            body="A compact signal → event → filtered fragment example."
          />
          <DstarDemoWeb.HomePage.demo_tile
            title="Server Components"
            href={~p"/components"}
            icon="hero-cube-transparent"
            body="Colocate reusable HEEx UI with stateless, module-routed event handlers."
          />
          <DstarDemoWeb.HomePage.demo_tile
            title="Script Helpers"
            href={~p"/scripts"}
            icon="hero-code-bracket-square"
            body="Reference execute_script, console_log, and redirect escape hatches safely."
          />
          <DstarDemoWeb.HomePage.demo_tile
            title="Authentication Flow"
            href={~p"/auth"}
            icon="hero-shield-check"
            body="Protect GETs, events, streams, and components with one Phoenix authentication path."
          />
        </section>
      </div>
    </div>

    <%!-- After the content, so crawlers and unfurlers read the H1 first. --%>
    <Layouts.flash_group flash={@flash} />
    """
  end
end
