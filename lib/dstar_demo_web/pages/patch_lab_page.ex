defmodule DstarDemoWeb.PatchLabPage do
  use DstarDemoWeb, :dstar_page

  @modes ~w(outer inner append prepend before after remove)

  # The selector is half the API, so it is data rather than something buried in
  # the case clause below: the header, the stage highlight, and the handler all
  # read the same map, which keeps what the page claims and what it patches in
  # step.
  @mode_selectors %{
    "outer" => "#lab-target",
    "inner" => "#lab-target",
    "append" => "#patch-list",
    "prepend" => "#patch-list",
    "before" => "#anchor-row",
    "after" => "#anchor-row",
    "remove" => "#removable-note"
  }

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
      signals={%{selected_mode: @selected_mode, hovered_mode: "", patch_count: @patch_count}}
    >
      <:demo>
        <%!-- The mode list has to stay beside the target area: watching a patch
        land is the whole demo, and a stacked layout puts seven tall buttons
        between the control you clicked and the thing that changed. Side by side
        from sm up, sticky so it stays in view while the stage grows. --%>
        <section class="grid gap-5 sm:grid-cols-[minmax(0,190px)_minmax(0,1fr)] lg:grid-cols-[240px_minmax(0,1fr)]">
          <div class="self-start border border-base-300 bg-base-200 p-4 sm:sticky sm:top-4">
            <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">Modes</p>
            <div class="mt-4 flex flex-wrap gap-2 sm:grid">
              <button
                :for={mode <- @modes}
                id={"patch-mode-#{mode}"}
                data-on:click={"$selected_mode = '#{mode}'; #{event(mode)}"}
                data-on:mouseenter={"$hovered_mode = '#{mode}'"}
                data-on:mouseleave="$hovered_mode = ''"
                data-class={mode_classes(mode)}
                class={[
                  "flex items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm font-medium capitalize transition",
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
                  selector:
                  <span class="text-base-content" data-text={selector_expr()}>
                    {selector_for(@selected_mode)}
                  </span>
                  · mode: :<span data-text="$selected_mode">{@selected_mode}</span> · count:
                  <span data-text="$patch_count">{@patch_count}</span>
                </p>
              </div>
              <div class="flex items-center gap-3">
                <button
                  id="reset-stage"
                  data-on:click={event("reset")}
                  class="flex items-center gap-1.5 rounded-md border border-base-300 px-2.5 py-1.5 text-xs font-medium text-base-content/80 transition hover:border-base-content/40 hover:bg-base-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                >
                  <.icon name="hero-arrow-path-micro" class="size-3.5" /> Reset stage
                </button>
                <.pill label="Datastar patch-elements" tone="info" />
              </div>
            </div>

            <.patch_status selected_mode={@selected_mode} patch_count={@patch_count} />

            <.lab_stage />
          </div>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "outer replaces the target node.",
          "inner replaces only target contents.",
          "append and prepend add children to a list.",
          "before and after insert siblings around an anchor.",
          "remove deletes the selected element.",
          "The selector is fixed per mode; the header and the ringed node show which one is next."
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

      <:comparison>
        <.prose>
          Only three of the seven modes have a LiveView counterpart, which is the
          point of the comparison rather than a gap in it.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label={@snippet.source}
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>
        </.compare>
      </:comparison>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  for mode <- @modes do
    def handle_event(conn, unquote(mode), signals),
      do: apply_patch_mode(conn, unquote(mode), signals)
  end

  def handle_event(conn, "reset", signals) do
    mode = signals["selected_mode"] || "outer"

    conn
    |> patch_signals(%{patch_count: 0})
    |> patch(&patch_status/1, selected_mode: mode, patch_count: 0)
    |> patch(&lab_stage/1, [], selector: "#lab-stage", mode: :outer)
  end

  # Keeps the mode buttons' highlight in sync with the $selected_mode
  # signal after events; the server only renders the initial state.
  defp mode_classes(mode) do
    "{'border-primary bg-primary text-primary-content': $selected_mode === '#{mode}', " <>
      "'border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-100': $selected_mode !== '#{mode}'}"
  end

  # Reset re-renders this whole subtree with an outer patch, which is why the
  # initial render and the reset handler share one component: remove deletes
  # #removable-note for good, and without a way back that mode works exactly
  # once per page load.
  defp lab_stage(assigns) do
    ~H"""
    <div id="lab-stage" class="border border-base-300 bg-base-100 p-4">
      <div id="before-zone" class="space-y-2"></div>
      <div id="lab-target" data-class={ring("#lab-target")} class={target_class()}>
        <div class="flex items-center justify-between gap-3">
          <p class="text-sm font-semibold text-base-content">Target node</p>
          <.zone_id id="#lab-target" />
        </div>
        <p id="target-copy" class="mt-1 text-sm text-base-content/70">
          Inner content starts here.
        </p>
        <.list_label />
        <div id="patch-list" data-class={ring("#patch-list")} class={list_class()}>
          <div id="seed-row" class="bg-base-200 px-3 py-2 text-sm text-base-content/80">
            Seed row
          </div>
        </div>
      </div>
      <div
        id="anchor-row"
        data-class={ring("#anchor-row")}
        class="my-3 flex items-center justify-between gap-3 border border-info/30 bg-info/10 px-3 py-2 text-sm text-base-content"
      >
        <span>Sibling anchor for before and after</span>
        <.zone_id id="#anchor-row" />
      </div>
      <div
        id="removable-note"
        data-class={ring("#removable-note")}
        class="flex items-center justify-between gap-3 border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-base-content"
      >
        <span>Remove mode deletes this note.</span>
        <.zone_id id="#removable-note" />
      </div>
      <div id="after-zone" class="space-y-2"></div>
    </div>
    """
  end

  defp selector_for(mode), do: @mode_selectors[mode]

  # A lookup keyed by the same signal the buttons set, so the header shows the
  # selector the next patch will use — before the round trip, not after it.
  defp selector_expr do
    pairs = Enum.map_join(@mode_selectors, ", ", fn {m, s} -> "'#{m}': '#{s}'" end)
    "({#{pairs}})[$selected_mode]"
  end

  # Rings the element a mode is about to patch. Hover takes precedence so the
  # stage previews a button's target without changing the selected mode; when
  # hover ends, the ring returns to the selected target. Both interactions are
  # client-side signal writes, so the ring moves without a server round trip.
  defp ring(selector) do
    modes =
      @mode_selectors
      |> Enum.filter(fn {_mode, sel} -> sel == selector end)
      |> Enum.map_join(", ", fn {mode, _sel} -> "'#{mode}'" end)

    "{'ring-2 ring-primary': [#{modes}].includes($hovered_mode || $selected_mode)}"
  end

  defp mono, do: "font-mono font-semibold text-base-content"
  defp target_class, do: "border border-primary/40 bg-primary/10 p-4"
  defp list_class, do: "mt-2 grid gap-2"

  attr :id, :string, required: true

  defp zone_id(assigns) do
    ~H"""
    <span class="shrink-0 font-mono text-[11px] text-base-content/50">{@id}</span>
    """
  end

  defp list_label(assigns) do
    ~H"""
    <div class="mt-4 flex items-center justify-between gap-3">
      <p class="text-xs text-base-content/60">List children</p>
      <.zone_id id="#patch-list" />
    </div>
    """
  end

  attr :selected_mode, :string, required: true
  attr :patch_count, :integer, required: true

  def patch_status(assigns) do
    ~H"""
    <div
      id="patch-status"
      class="mb-4 border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content/80"
    >
      <%= if @patch_count == 0 do %>
        Fresh stage, no patches yet. Next patch targets <span class={mono()}>{selector_for(@selected_mode)}</span>.
      <% else %>
        Last patch used <span class={mono()}>{@selected_mode}</span>
        mode on <span class={mono()}>{selector_for(@selected_mode)}</span>
        at count <span class={mono()}>{@patch_count}</span>.
      <% end %>
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
        patch(conn, &inner_body/1, [count: count], selector: "#lab-target", mode: :inner)

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

  # The outer and inner replacements have to re-declare the zone ids and their
  # data-class rings: a patch replaces the markup wholesale, and an unlabelled
  # #patch-list would leave the header pointing at a selector the stage no
  # longer shows.
  defp lab_target(assigns) do
    ~H"""
    <div id="lab-target" data-class={ring("#lab-target")} class={target_class()}>
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-semibold text-base-content">Outer patch replaced this node.</p>
        <.zone_id id="#lab-target" />
      </div>
      <p class="mt-1 text-sm text-base-content/70">Patch count {@count}</p>
      <.list_label />
      <div id="patch-list" data-class={ring("#patch-list")} class={list_class()}>
        <div id={"outer-seed-#{@count}"} class="bg-base-200 px-3 py-2 text-sm text-base-content/80">
          New list seed
        </div>
      </div>
    </div>
    """
  end

  defp inner_body(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3">
      <p class="text-sm font-semibold text-base-content">Inner patch {@count}</p>
      <.zone_id id="#lab-target" />
    </div>
    <p class="mt-1 text-sm text-base-content/70">Only the children changed.</p>
    <.list_label />
    <div id="patch-list" data-class={ring("#patch-list")} class={list_class()}>
      <div id={"inner-seed-#{@count}"} class="bg-base-200 px-3 py-2 text-sm text-base-content/80">
        New list seed
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
