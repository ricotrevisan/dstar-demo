defmodule DstarDemoWeb.ServerComponentsPage do
  use DstarDemoWeb, :dstar_page

  alias DstarDemoWeb.ComponentStage

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn, component_kind: "profile", render_count: 0)
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:server_components))

    ~H"""
    <.demo_shell
      active="Components"
      title="Server-rendered components"
      summary="A Dstar.Component owns the stage UI and its event handlers. This page embeds it on first render; events dispatch straight to the component."
      signals={%{component_kind: @component_kind, render_count: @render_count}}
    >
      <:demo>
        <section class="grid gap-5 xl:grid-cols-[260px_minmax(0,1fr)]">
          <div class="border border-base-300 bg-base-200 p-4">
            <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">Variants</p>
            <div class="mt-4 grid gap-2">
              <.action_button
                id="component-profile"
                label="Profile"
                icon="hero-identification-micro"
                click={"$component_kind = 'profile'; #{ComponentStage.event("profile")}"}
                active={@component_kind == "profile"}
                data-class={variant_classes("profile")}
              />
              <.action_button
                id="component-timeline"
                label="Timeline"
                icon="hero-queue-list-micro"
                click={"$component_kind = 'timeline'; #{ComponentStage.event("timeline")}"}
                active={@component_kind == "timeline"}
                data-class={variant_classes("timeline")}
              />
              <.action_button
                id="component-deploy"
                label="Deploy"
                icon="hero-rocket-launch-micro"
                click={"$component_kind = 'deploy'; #{ComponentStage.event("deploy")}"}
                active={@component_kind == "deploy"}
                data-class={variant_classes("deploy")}
              />
            </div>
          </div>

          <div class="border border-base-300 bg-base-200 p-5">
            <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
              <div>
                <p class="text-sm font-semibold text-base-content">Component stage</p>
                <p class="mt-1 font-mono text-xs text-base-content/65">
                  renders: <span data-text="$render_count">{@render_count}</span>
                </p>
              </div>
              <.pill label={@component_kind} tone="good" data-text="$component_kind" />
            </div>

            <ComponentStage.component_stage
              component_kind={@component_kind}
              render_count={@render_count}
            />
          </div>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "ComponentStage is a Dstar.Component: UI plus handle_event/3.",
          "This page has no handle_event clauses for the stage at all.",
          "event/2 targets /ds/<module>/<event> via dstar_components/2.",
          "The same component renders on first paint and in SSE patches."
        ]} />

        <.prose>
          <code class="font-mono text-sm">ComponentStage</code>
          is a <code class="font-mono text-sm">Dstar.Component</code>: it owns both its markup and
          its <code class="font-mono text-sm">handle_event/3</code>. Events target <code class="font-mono text-sm">/ds/&lt;module&gt;/&lt;event&gt;</code>, so this page
          module has no handler clauses for the stage at all — and the same component function
          renders on first paint and inside every later patch.
        </.prose>

        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
      </:how_it_works>
    </.demo_shell>
    """
  end

  # Keeps the variant buttons' highlight in sync with the $component_kind
  # signal after events; the server only renders the initial state.
  defp variant_classes(kind) do
    "{'border-primary bg-primary text-primary-content': $component_kind === '#{kind}', " <>
      "'border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-200': $component_kind !== '#{kind}'}"
  end
end
