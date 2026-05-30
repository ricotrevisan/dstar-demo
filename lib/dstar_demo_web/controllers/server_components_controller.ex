defmodule DstarDemoWeb.ServerComponentsController do
  use DstarDemoWeb, :dstar

  @impl Dstar
  def mount(conn, _params) do
    conn
    |> signal(:component_kind, "profile")
    |> signal(:render_count, 0)
  end

  def home(conn, _params), do: conn

  @impl Dstar
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Components"
      title="Server-rendered components"
      eyebrow="HEEx patches"
      summary="Reusable function components render on the server, then Dstar patches the selected component into a stable target."
      signals={init_signals(@conn)}
    >
      <:aside>
        <.demo_facts items={[
          "Each variant is a HEEx function component.",
          "Commands update component_kind and render_count signals.",
          "Only #component-stage is patched.",
          "The same components can be used on first render and SSE patches."
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
              click={"$component_kind = 'profile'; #{post("profile")}"}
              active={@component_kind == "profile"}
            />
            <.action_button
              id="component-timeline"
              label="Timeline"
              icon="hero-queue-list-micro"
              click={"$component_kind = 'timeline'; #{post("timeline")}"}
              active={@component_kind == "timeline"}
            />
            <.action_button
              id="component-deploy"
              label="Deploy"
              icon="hero-rocket-launch-micro"
              click={"$component_kind = 'deploy'; #{post("deploy")}"}
              active={@component_kind == "deploy"}
            />
          </div>
        </div>

        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <p class="text-sm font-semibold text-zinc-100">Component stage</p>
              <p class="mt-1 text-xs text-zinc-500">renders: {@render_count}</p>
            </div>
            <.pill label={@component_kind} tone="good" />
          </div>

          <.component_stage component_kind={@component_kind} render_count={@render_count} />
        </div>
      </section>
    </.demo_shell>
    """
  end

  @impl Dstar
  for kind <- ~w(profile timeline deploy) do
    def handle_event(conn, unquote(kind), signals),
      do: render_component(conn, unquote(kind), signals)
  end

  attr :component_kind, :string, required: true
  attr :render_count, :integer, required: true

  def component_stage(assigns) do
    ~H"""
    <div id="component-stage">
      <.profile_card :if={@component_kind == "profile"} render_count={@render_count} />
      <.timeline_panel :if={@component_kind == "timeline"} render_count={@render_count} />
      <.deploy_summary :if={@component_kind == "deploy"} render_count={@render_count} />
    </div>
    """
  end

  attr :render_count, :integer, required: true

  def profile_card(assigns) do
    ~H"""
    <section class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex min-w-0 items-center gap-3">
          <div class="grid size-11 shrink-0 place-items-center rounded-md bg-emerald-300 text-zinc-950">
            <.icon name="hero-user" class="size-5" />
          </div>
          <div class="min-w-0">
            <h2 class="truncate text-base font-semibold text-zinc-100">Ada Lovelace</h2>
            <p class="text-sm text-zinc-500">Release coordinator · Dstar lab</p>
          </div>
        </div>
        <.pill label={"render #{@render_count}"} tone="info" />
      </div>

      <dl class="mt-5 grid gap-3 sm:grid-cols-3">
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          <dt class="text-xs text-zinc-500">Open commands</dt>
          <dd class="mt-1 text-lg font-semibold text-zinc-100">7</dd>
        </div>
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          <dt class="text-xs text-zinc-500">Patch latency</dt>
          <dd class="mt-1 text-lg font-semibold text-zinc-100">34 ms</dd>
        </div>
        <div class="rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2">
          <dt class="text-xs text-zinc-500">Signal scope</dt>
          <dd class="mt-1 text-lg font-semibold text-zinc-100">tab</dd>
        </div>
      </dl>
    </section>
    """
  end

  attr :render_count, :integer, required: true

  def timeline_panel(assigns) do
    ~H"""
    <section class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-semibold text-zinc-100">Patch timeline</h2>
        <.pill label={"render #{@render_count}"} tone="info" />
      </div>
      <ol class="mt-4 space-y-2">
        <li
          :for={
            {label, tone} <- [
              {"Signals read", "good"},
              {"Component rendered", "info"},
              {"Target patched", "warn"}
            ]
          }
          class="flex items-center gap-3 rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2"
        >
          <.pill label={tone} tone={tone} />
          <span class="text-sm text-zinc-200">{label}</span>
        </li>
      </ol>
    </section>
    """
  end

  attr :render_count, :integer, required: true

  def deploy_summary(assigns) do
    ~H"""
    <section class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-semibold text-zinc-100">Deploy summary</h2>
        <.pill label={"render #{@render_count}"} tone="info" />
      </div>
      <div class="mt-4 grid gap-3 md:grid-cols-2">
        <div class="rounded-md border border-emerald-300/30 bg-emerald-300/10 p-3">
          <p class="text-sm font-semibold text-emerald-100">Ready to patch</p>
          <p class="mt-1 text-sm text-emerald-200/80">HEEx returned safe iodata for Dstar.</p>
        </div>
        <div class="rounded-md border border-sky-300/30 bg-sky-300/10 p-3">
          <p class="text-sm font-semibold text-sky-100">Stable selector</p>
          <p class="mt-1 text-sm text-sky-200/80">#component-stage receives the update.</p>
        </div>
      </div>
    </section>
    """
  end

  defp render_component(conn, kind, signals) do
    count = next_count(signals)

    conn
    |> signal(:component_kind, kind)
    |> signal(:render_count, count)
    |> patch_element(&component_stage/1, to: "component-stage")
  end

  defp next_count(signals) do
    case signals["render_count"] do
      count when is_integer(count) -> count + 1
      count when is_binary(count) -> String.to_integer(count) + 1
      _ -> 1
    end
  rescue
    ArgumentError -> 1
  end
end
