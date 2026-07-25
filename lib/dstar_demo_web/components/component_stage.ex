defmodule DstarDemoWeb.ComponentStage do
  @moduledoc """
  A `Dstar.Component`: the stage UI and its event handlers in one module.

  Pages embed `component_stage/1` as a plain function component; the
  variant buttons post to `/ds/<module>/<event>` via `event/2`, routed by
  `dstar_components/2` in the router.
  """

  use DstarDemoWeb, :dstar_component

  @kinds ~w(profile timeline deploy)

  def handle_event(conn, kind, signals) when kind in @kinds do
    count = next_count(signals)

    conn
    |> start()
    |> patch_signals(%{component_kind: kind, render_count: count})
    |> patch(&component_stage/1, component_kind: kind, render_count: count)
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
    <section class="border border-base-300 bg-base-100 p-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex min-w-0 items-center gap-3">
          <div class="grid size-11 shrink-0 place-items-center bg-primary text-primary-content">
            <.icon name="hero-user" class="size-5" />
          </div>
          <div class="min-w-0">
            <h2 class="truncate text-base font-semibold text-base-content">Ada Lovelace</h2>
            <p class="text-sm text-base-content/70">Release coordinator · Dstar lab</p>
          </div>
        </div>
        <.pill label={"render #{@render_count}"} tone="info" />
      </div>

      <dl class="mt-5 grid gap-3 sm:grid-cols-3">
        <div class="border border-base-300 bg-base-200 px-3 py-2">
          <dt class="font-mono text-xs text-base-content/65">Open commands</dt>
          <dd class="mt-1 text-lg font-semibold tabular-nums text-base-content">7</dd>
        </div>
        <div class="border border-base-300 bg-base-200 px-3 py-2">
          <dt class="font-mono text-xs text-base-content/65">Patch latency</dt>
          <dd class="mt-1 text-lg font-semibold tabular-nums text-base-content">34 ms</dd>
        </div>
        <div class="border border-base-300 bg-base-200 px-3 py-2">
          <dt class="font-mono text-xs text-base-content/65">Signal scope</dt>
          <dd class="mt-1 text-lg font-semibold text-base-content">tab</dd>
        </div>
      </dl>
    </section>
    """
  end

  attr :render_count, :integer, required: true

  def timeline_panel(assigns) do
    ~H"""
    <section class="border border-base-300 bg-base-100 p-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-semibold text-base-content">Patch timeline</h2>
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
          class="flex items-center gap-3 border border-base-300 bg-base-200 px-3 py-2"
        >
          <.pill label={tone} tone={tone} />
          <span class="text-sm text-base-content/80">{label}</span>
        </li>
      </ol>
    </section>
    """
  end

  attr :render_count, :integer, required: true

  def deploy_summary(assigns) do
    ~H"""
    <section class="border border-base-300 bg-base-100 p-4">
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-base font-semibold text-base-content">Deploy summary</h2>
        <.pill label={"render #{@render_count}"} tone="info" />
      </div>
      <div class="mt-4 grid gap-3 md:grid-cols-2">
        <div class="border border-success/40 bg-success/10 p-3">
          <p class="text-sm font-semibold text-base-content">Ready to patch</p>
          <p class="mt-1 text-sm text-base-content/80">HEEx returned safe iodata for Dstar.</p>
        </div>
        <div class="border border-info/40 bg-info/10 p-3">
          <p class="text-sm font-semibold text-base-content">Stable selector</p>
          <p class="mt-1 text-sm text-base-content/80">#component-stage receives the update.</p>
        </div>
      </div>
    </section>
    """
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
