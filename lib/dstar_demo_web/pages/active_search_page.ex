defmodule DstarDemoWeb.ActiveSearchPage do
  use DstarDemoWeb, :dstar_page

  @items [
    %{
      name: "Sierra Command Center",
      type: "Workflow",
      owner: "Ops",
      tags: ~w(commands validation)
    },
    %{
      name: "Signal Replay Console",
      type: "Tool",
      owner: "Platform",
      tags: ~w(signals inspector)
    },
    %{name: "Northstar Metrics", type: "Dashboard", owner: "SRE", tags: ~w(streaming metrics)},
    %{name: "Patch Mode Workbench", type: "Lab", owner: "UI Systems", tags: ~w(patches dom)},
    %{name: "Component Forge", type: "Renderer", owner: "Design Eng", tags: ~w(heex components)},
    %{name: "Edge Intake Queue", type: "Dataset", owner: "Support", tags: ~w(queue search)},
    %{
      name: "Beacon Release Notes",
      type: "Document",
      owner: "Product",
      tags: ~w(content components)
    },
    %{name: "Atlas Region Map", type: "Dataset", owner: "Field", tags: ~w(geo search)},
    %{
      name: "Pulse Incident Feed",
      type: "Stream",
      owner: "Reliability",
      tags: ~w(streaming activity)
    },
    %{
      name: "Handoff Checklist",
      type: "Workflow",
      owner: "Success",
      tags: ~w(commands lifecycle)
    },
    %{name: "Control Plane Audit", type: "Report", owner: "Security", tags: ~w(signals audit)},
    %{name: "Launch Readiness", type: "Checklist", owner: "Product", tags: ~w(validation ready)}
  ]

  @impl Dstar.Page
  def mount(conn, _params) do
    results = search("", "all")

    assign(conn,
      query: "",
      segment: "all",
      results: results,
      result_count: length(results)
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:active_search))

    ~H"""
    <.demo_shell
      active="Active Search"
      title="Active search"
      summary="Typing changes Datastar signals, the server filters local data, and only the result panel is patched back."
      signals={%{query: @query, segment: @segment}}
    >
      <:demo>
        <section class="border border-base-300 bg-base-200 p-5">
          <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <label class="block min-w-0 flex-1">
              <span class="mb-2 block text-sm font-medium text-base-content/80">
                Search inventory
              </span>
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-3 top-1/2 size-5 -translate-y-1/2 text-base-content/45"
                />
                <input
                  id="search-query"
                  data-bind:query
                  data-indicator="_searchPending"
                  data-on:input__debounce.240ms={event("search")}
                  value={@query}
                  placeholder="Try stream, patch, signal, or owner names"
                  autocomplete="off"
                  class="w-full rounded-md border border-base-300 bg-base-100 py-3 pr-3 pl-10 text-base text-base-content transition placeholder:text-base-content/65 focus:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                />
              </div>
            </label>

            <div class="flex flex-wrap gap-2" aria-label="Search segment">
              <button
                :for={segment <- ["all", "workflow", "dashboard", "tool"]}
                id={"search-segment-#{segment}"}
                data-indicator="_searchPending"
                data-on:click={"$segment = '#{segment}'; #{event("search")}"}
                class={[
                  "rounded-md border px-3 py-2 text-sm font-medium capitalize transition",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
                  @segment == segment && "border-primary bg-primary text-primary-content",
                  @segment != segment &&
                    "border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-100"
                ]}
              >
                {segment}
              </button>
            </div>
          </div>

          <div
            data-show="$_searchPending"
            class="mt-5 border border-info/30 bg-info/10 px-3 py-2 text-sm text-base-content"
          >
            Updating results
          </div>

          <.result_panel
            results={@results}
            query={@query}
            segment={@segment}
            result_count={@result_count}
          />
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "data-bind keeps the query and segment on the client.",
          "Typing posts a page event with the latest signals.",
          "Only #search-results is patched, not the input chrome.",
          "Empty and no-results states are server-rendered."
        ]} />

        <.prose>
          <code class="font-mono text-sm">data-bind:query</code>
          keeps the query on the client, and
          <code class="font-mono text-sm">data-on:input__debounce.240ms</code>
          posts a page event with the current signals 240ms after you stop typing. The handler
          filters and patches <code class="font-mono text-sm">#search-results</code>
          alone — and deliberately does not echo the query back, because a patch landing while you
          are still typing would clobber the input.
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
          Both sides debounce at 240ms, filter the same local dataset, and render
          the same empty and no-results states.
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

          <:note><.rich_text text={@snippet.note} /></:note>
        </.compare>
      </:comparison>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "search", signals) do
    query = String.trim(signals["query"] || "")
    segment = signals["segment"] || "all"
    results = search(query, segment)

    # The client owns query/segment — echoing them back would clobber
    # anything typed while this response was in flight.
    patch(conn, &result_panel/1,
      results: results,
      query: query,
      segment: segment,
      result_count: length(results)
    )
  end

  attr :results, :list, required: true
  attr :query, :string, required: true
  attr :segment, :string, required: true
  attr :result_count, :integer, required: true

  def result_panel(assigns) do
    ~H"""
    <div id="search-results" class="mt-5 border border-base-300 bg-base-100">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 px-4 py-3">
        <div>
          <p class="text-sm font-semibold text-base-content">{@result_count} matches</p>
          <p class="font-mono text-xs text-base-content/65">
            query: {if @query == "", do: "empty", else: @query} · segment: {@segment}
          </p>
        </div>
        <.pill label="server patch" tone="info" />
      </div>

      <div class="divide-y divide-base-300">
        <div :if={@query == "" and @segment == "all"} class="px-4 py-8">
          <p class="text-sm font-semibold text-base-content">
            Start typing to narrow the inventory.
          </p>
          <p class="mt-1 text-sm text-base-content/65">
            The first render still shows the full local dataset so there is something real to scan.
          </p>
        </div>

        <div :if={@results == []} class="px-4 py-8">
          <p class="text-sm font-semibold text-base-content">No matching records.</p>
          <p class="mt-1 text-sm text-base-content/65">
            Try a broader term or switch the segment back to all.
          </p>
        </div>

        <article :for={item <- @results} class="px-4 py-3 transition hover:bg-base-200">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0">
              <h2 class="truncate text-sm font-semibold text-base-content">{item.name}</h2>
              <p class="mt-1 text-xs text-base-content/65">{item.type} · {item.owner}</p>
            </div>
            <div class="flex flex-wrap gap-1">
              <span
                :for={tag <- item.tags}
                class="bg-base-200 px-2 py-1 font-mono text-xs text-base-content/70"
              >
                {tag}
              </span>
            </div>
          </div>
        </article>
      </div>
    </div>
    """
  end

  defp search(query, segment) do
    query = String.downcase(query || "")
    segment = String.downcase(segment || "all")

    @items
    |> Enum.filter(fn item ->
      haystack =
        [item.name, item.type, item.owner | item.tags]
        |> Enum.join(" ")
        |> String.downcase()

      segment_match? = segment == "all" or String.downcase(item.type) == segment
      query_match? = query == "" or String.contains?(haystack, query)

      segment_match? and query_match?
    end)
  end
end
