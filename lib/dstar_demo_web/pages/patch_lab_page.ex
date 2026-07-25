defmodule DstarDemoWeb.PatchLabPage do
  use DstarDemoWeb, :dstar_page

  @modes ~w(outer inner append prepend before after remove)

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn, selected_mode: "outer", patch_count: 0)
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:modes, @modes)
      |> Map.put(:snippet, DstarDemoWeb.Snippets.fetch!(:patch_lab))

    ~H"""
    <.demo_shell
      active="Patch Lab"
      title="Patch lab"
      summary="Each control sends a page event that uses a different Datastar patch mode. The target area makes insertion, replacement, and removal explicit."
      signals={%{selected_mode: @selected_mode, patch_count: @patch_count}}
    >
      <:demo>
        <section class="grid gap-5 xl:grid-cols-[260px_minmax(0,1fr)]">
          <div class="border border-base-300 bg-base-200 p-4">
            <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">Modes</p>
            <div class="mt-4 grid gap-2">
              <button
                :for={mode <- @modes}
                id={"patch-mode-#{mode}"}
                data-on:click={"$selected_mode = '#{mode}'; #{event(mode)}"}
                data-class={mode_classes(mode)}
                class={[
                  "flex items-center justify-between rounded-md border px-3 py-2 text-sm font-medium capitalize transition",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
                  @selected_mode == mode && "border-primary bg-primary text-primary-content",
                  @selected_mode != mode &&
                    "border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-100"
                ]}
              >
                <span>{mode}</span>
                <.icon name="hero-arrow-right-micro" class="size-4" />
              </button>
            </div>
          </div>

          <div class="min-w-0 border border-base-300 bg-base-200 p-5">
            <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
              <div>
                <p class="text-sm font-semibold text-base-content">Patch target</p>
                <p class="mt-1 font-mono text-xs text-base-content/65">
                  Count: <span data-text="$patch_count">{@patch_count}</span>
                  · mode: <span data-text="$selected_mode">{@selected_mode}</span>
                </p>
              </div>
              <.pill label="Datastar patch-elements" tone="info" />
            </div>

            <.patch_status selected_mode={@selected_mode} patch_count={@patch_count} />

            <div id="lab-stage" class="border border-base-300 bg-base-100 p-4">
              <div id="before-zone" class="space-y-2"></div>
              <div id="lab-target" class="border border-primary/40 bg-primary/10 p-4">
                <p class="text-sm font-semibold text-base-content">Target node</p>
                <p id="target-copy" class="mt-1 text-sm text-base-content/70">
                  Inner content starts here.
                </p>
                <div id="patch-list" class="mt-4 grid gap-2">
                  <div id="seed-row" class="bg-base-200 px-3 py-2 text-sm text-base-content/80">
                    Seed row
                  </div>
                </div>
              </div>
              <div
                id="anchor-row"
                class="my-3 border border-info/30 bg-info/10 px-3 py-2 text-sm text-base-content"
              >
                Sibling anchor for before and after
              </div>
              <div
                id="removable-note"
                class="border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-base-content"
              >
                Remove mode deletes this note.
              </div>
              <div id="after-zone" class="space-y-2"></div>
            </div>
          </div>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "outer replaces the target node.",
          "inner replaces only target contents.",
          "append and prepend add children to a list.",
          "before and after insert siblings around an anchor.",
          "remove deletes the selected element."
        ]} />

        <.prose>
          Every control posts a page event whose handler picks a different Datastar patch mode.
          <code class="font-mono text-sm">mode: :outer</code>
          swaps the target node, <code class="font-mono text-sm">:inner</code>
          only its children, <code class="font-mono text-sm">:append</code>
          and <code class="font-mono text-sm">:prepend</code>
          add list items, <code class="font-mono text-sm">:before</code>
          and <code class="font-mono text-sm">:after</code>
          insert siblings around an anchor, and
          <code class="font-mono text-sm">remove_elements/2</code>
          deletes outright. The selector and the mode are the whole API.
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

  @impl Dstar.Page
  for mode <- @modes do
    def handle_event(conn, unquote(mode), signals),
      do: apply_patch_mode(conn, unquote(mode), signals)
  end

  # Keeps the mode buttons' highlight in sync with the $selected_mode
  # signal after events; the server only renders the initial state.
  defp mode_classes(mode) do
    "{'border-primary bg-primary text-primary-content': $selected_mode === '#{mode}', " <>
      "'border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-100': $selected_mode !== '#{mode}'}"
  end

  attr :selected_mode, :string, required: true
  attr :patch_count, :integer, required: true

  def patch_status(assigns) do
    ~H"""
    <div
      id="patch-status"
      class="mb-4 border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content/80"
    >
      Last patch used <span class="font-mono font-semibold text-base-content">{@selected_mode}</span>
      mode at count <span class="font-mono font-semibold text-base-content">{@patch_count}</span>.
    </div>
    """
  end

  attr :mode, :string, required: true
  attr :count, :integer, required: true

  def patch_badge(assigns) do
    ~H"""
    <div
      id={"patch-item-#{@mode}-#{@count}"}
      class="border border-primary/40 bg-primary/10 px-3 py-2 text-sm text-base-content"
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
          ~s(<p class="text-sm font-semibold text-base-content">Inner patch #{count}</p><p class="mt-1 text-sm text-base-content/70">Only the children changed.</p>),
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
    <div id="lab-target" class="border border-primary bg-primary/10 p-4">
      <p class="text-sm font-semibold text-base-content">Outer patch replaced this node.</p>
      <p class="mt-1 text-sm text-base-content/70">Patch count {@count}</p>
      <div id="patch-list" class="mt-4 grid gap-2">
        <div id={"outer-seed-#{@count}"} class="bg-base-200 px-3 py-2 text-sm text-base-content/80">
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
