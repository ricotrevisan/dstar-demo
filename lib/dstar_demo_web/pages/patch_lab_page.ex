defmodule DstarDemoWeb.PatchLabPage do
  use DstarDemoWeb, :dstar_page

  @modes ~w(outer inner append prepend before after remove)

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn, selected_mode: "outer", patch_count: 0)
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :modes, @modes)

    ~H"""
    <.demo_shell
      active="Patch Lab"
      title="Patch lab"
      eyebrow="DOM patch modes"
      summary="Each control sends a page event that uses a different Datastar patch mode. The target area makes insertion, replacement, and removal explicit."
      signals={%{selected_mode: @selected_mode, patch_count: @patch_count}}
    >
      <:aside>
        <.demo_facts items={[
          "outer replaces the target node.",
          "inner replaces only target contents.",
          "append and prepend add children to a list.",
          "before and after insert siblings around an anchor.",
          "remove deletes the selected element."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[260px_minmax(0,1fr)]">
        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">Modes</p>
          <div class="mt-4 grid gap-2">
            <button
              :for={mode <- @modes}
              id={"patch-mode-#{mode}"}
              data-on:click={"$selected_mode = '#{mode}'; #{event(mode)}"}
              data-class={mode_classes(mode)}
              class={[
                "flex items-center justify-between rounded-md px-3 py-2 text-sm font-semibold capitalize transition focus:outline-none focus:ring-2 focus:ring-emerald-300/60",
                @selected_mode == mode && "bg-emerald-300 text-zinc-950",
                @selected_mode != mode &&
                  "border border-zinc-700 text-zinc-300 hover:border-zinc-500 hover:bg-zinc-800"
              ]}
            >
              <span>{mode}</span>
              <.icon name="hero-arrow-right-micro" class="size-4" />
            </button>
          </div>
        </div>

        <div class="min-w-0 rounded-lg border border-zinc-800 bg-zinc-900 p-5">
          <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <p class="text-sm font-semibold text-zinc-100">Patch target</p>
              <p class="mt-1 text-xs text-zinc-500">
                Count: <span data-text="$patch_count">{@patch_count}</span>
                · mode: <span data-text="$selected_mode">{@selected_mode}</span>
              </p>
            </div>
            <.pill label="Datastar patch-elements" tone="info" />
          </div>

          <.patch_status selected_mode={@selected_mode} patch_count={@patch_count} />

          <div id="lab-stage" class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
            <div id="before-zone" class="space-y-2"></div>
            <div id="lab-target" class="rounded-md border border-emerald-300/30 bg-emerald-300/10 p-4">
              <p class="text-sm font-semibold text-emerald-100">Target node</p>
              <p id="target-copy" class="mt-1 text-sm text-emerald-200/80">
                Inner content starts here.
              </p>
              <div id="patch-list" class="mt-4 grid gap-2">
                <div id="seed-row" class="rounded-md bg-zinc-900 px-3 py-2 text-sm text-zinc-300">
                  Seed row
                </div>
              </div>
            </div>
            <div
              id="anchor-row"
              class="my-3 rounded-md border border-sky-300/30 bg-sky-300/10 px-3 py-2 text-sm text-sky-100"
            >
              Sibling anchor for before and after
            </div>
            <div
              id="removable-note"
              class="rounded-md border border-amber-300/30 bg-amber-300/10 px-3 py-2 text-sm text-amber-100"
            >
              Remove mode deletes this note.
            </div>
            <div id="after-zone" class="space-y-2"></div>
          </div>
        </div>
      </section>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  for mode <- @modes do
    def handle_event(conn, unquote(mode), signals),
      do: apply_patch_mode(conn, unquote(mode), signals)
  end

  # Keeps the mode buttons' highlight in sync with the $selected_mode
  # signal after events; the server only renders the initial state.
  defp mode_classes(mode) do
    "{'bg-emerald-300 text-zinc-950': $selected_mode === '#{mode}', " <>
      "'border border-zinc-700 text-zinc-300 hover:border-zinc-500 hover:bg-zinc-800': $selected_mode !== '#{mode}'}"
  end

  attr :selected_mode, :string, required: true
  attr :patch_count, :integer, required: true

  def patch_status(assigns) do
    ~H"""
    <div
      id="patch-status"
      class="mb-4 rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2 text-sm text-zinc-300"
    >
      Last patch used <span class="font-semibold text-emerald-200">{@selected_mode}</span>
      mode at count <span class="font-semibold text-zinc-100">{@patch_count}</span>.
    </div>
    """
  end

  attr :mode, :string, required: true
  attr :count, :integer, required: true

  def patch_badge(assigns) do
    ~H"""
    <div
      id={"patch-item-#{@mode}-#{@count}"}
      class="rounded-md border border-emerald-300/30 bg-emerald-300/10 px-3 py-2 text-sm text-emerald-100"
    >
      {@mode} patch #{@count}
    </div>
    """
  end

  defp apply_patch_mode(conn, mode, signals) do
    count = next_count(signals)

    conn =
      conn
      |> patch_signals(%{selected_mode: mode, patch_count: count})
      |> patch(&patch_status/1, selected_mode: mode, patch_count: count)

    case mode do
      "outer" ->
        patch(conn, &lab_target/1, [count: count], selector: "#lab-target", mode: :outer)

      "inner" ->
        patch_elements(
          conn,
          ~s(<p class="text-sm font-semibold text-emerald-100">Inner patch #{count}</p><p class="mt-1 text-sm text-emerald-200/80">Only the children changed.</p>),
          selector: "#lab-target",
          mode: :inner
        )

      "append" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#patch-list",
          mode: :append
        )

      "prepend" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#patch-list",
          mode: :prepend
        )

      "before" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :before
        )

      "after" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :after
        )

      "remove" ->
        remove_elements(conn, "#removable-note")
    end
  end

  defp lab_target(assigns) do
    ~H"""
    <div id="lab-target" class="rounded-md border border-emerald-300 bg-emerald-300/15 p-4">
      <p class="text-sm font-semibold text-emerald-50">Outer patch replaced this node.</p>
      <p class="mt-1 text-sm text-emerald-100/80">Patch count {@count}</p>
      <div id="patch-list" class="mt-4 grid gap-2">
        <div
          id={"outer-seed-#{@count}"}
          class="rounded-md bg-zinc-900 px-3 py-2 text-sm text-zinc-300"
        >
          New list seed
        </div>
      </div>
    </div>
    """
  end

  defp next_count(signals) do
    case signals["patch_count"] do
      count when is_integer(count) -> count + 1
      count when is_binary(count) -> String.to_integer(count) + 1
      _ -> 1
    end
  rescue
    ArgumentError -> 1
  end
end
