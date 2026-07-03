defmodule DstarDemoWeb.ServerComponentsPage do
  use DstarDemoWeb, :dstar_page

  alias DstarDemoWeb.ComponentStage

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn, component_kind: "profile", render_count: 0)
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Components"
      title="Server-rendered components"
      eyebrow="Dstar.Component"
      summary="A Dstar.Component owns the stage UI and its event handlers. This page embeds it on first render; events dispatch straight to the component."
      signals={%{component_kind: @component_kind, render_count: @render_count}}
    >
      <:aside>
        <.demo_facts items={[
          "ComponentStage is a Dstar.Component: UI plus handle_event/3.",
          "This page has no handle_event clauses for the stage at all.",
          "event/2 targets /ds/<module>/<event> via dstar_components/2.",
          "The same component renders on first paint and in SSE patches."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[260px_minmax(0,1fr)]">
        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">Variants</p>
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

        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <p class="text-sm font-semibold text-zinc-100">Component stage</p>
              <p class="mt-1 text-xs text-zinc-500">
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
    </.demo_shell>
    """
  end

  # Keeps the variant buttons' highlight in sync with the $component_kind
  # signal after events; the server only renders the initial state.
  defp variant_classes(kind) do
    "{'bg-emerald-300 text-zinc-950 hover:bg-emerald-200': $component_kind === '#{kind}', " <>
      "'border border-zinc-700 text-zinc-200 hover:border-zinc-500 hover:bg-zinc-900': $component_kind !== '#{kind}'}"
  end
end
