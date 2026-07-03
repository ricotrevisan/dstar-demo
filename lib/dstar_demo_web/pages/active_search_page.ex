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
    ~H"""
    <.demo_shell
      active="Active Search"
      title="Active search"
      eyebrow="Signal search"
      summary="Typing changes Datastar signals, the server filters local data, and only the result panel is patched back."
      signals={%{query: @query, segment: @segment}}
    >
      <:aside>
        <.demo_facts items={[
          "data-bind keeps the query and segment on the client.",
          "Typing posts a page event with the latest signals.",
          "Only #search-results is patched, not the input chrome.",
          "Empty and no-results states are server-rendered."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_300px]">
        <div class="rounded-lg border border-zinc-800 bg-zinc-900 p-5">
          <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <label class="block min-w-0 flex-1">
              <span class="mb-2 block text-sm font-medium text-zinc-300">Search inventory</span>
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-3 top-1/2 size-5 -translate-y-1/2 text-zinc-500"
                />
                <input
                  id="search-query"
                  data-bind:query
                  data-indicator="_searchPending"
                  data-on:input__debounce.240ms={event("search")}
                  value={@query}
                  placeholder="Try stream, patch, signal, or owner names"
                  autocomplete="off"
                  class="w-full rounded-md border border-zinc-700 bg-zinc-950 py-3 pr-3 pl-10 text-base text-zinc-100 outline-none transition placeholder:text-zinc-600 focus:border-emerald-300"
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
                  "rounded-md px-3 py-2 text-sm font-semibold capitalize transition focus:outline-none focus:ring-2 focus:ring-emerald-300/60",
                  @segment == segment && "bg-emerald-300 text-zinc-950",
                  @segment != segment &&
                    "border border-zinc-700 text-zinc-300 hover:border-zinc-500 hover:bg-zinc-800"
                ]}
              >
                {segment}
              </button>
            </div>
          </div>

          <div
            data-show="$_searchPending"
            class="mt-5 rounded-md border border-sky-300/20 bg-sky-300/10 px-3 py-2 text-sm text-sky-100"
          >
            Updating results
          </div>

          <.result_panel
            results={@results}
            query={@query}
            segment={@segment}
            result_count={@result_count}
          />
        </div>

        <aside class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
            Patched area
          </p>
          <p class="mt-3 text-sm leading-6 text-zinc-400">
            The input, segment buttons, and page shell stay put while Dstar morphs the result
            panel. The pending marker is a client-local indicator signal Datastar toggles around
            each request — it clears even if the request fails.
          </p>
        </aside>
      </section>
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
    <div id="search-results" class="mt-5 rounded-md border border-zinc-800 bg-zinc-950">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b border-zinc-800 px-4 py-3">
        <div>
          <p class="text-sm font-semibold text-zinc-100">{@result_count} matches</p>
          <p class="text-xs text-zinc-500">
            query: {if @query == "", do: "empty", else: @query} · segment: {@segment}
          </p>
        </div>
        <.pill label="server patch" tone="info" />
      </div>

      <div class="divide-y divide-zinc-800">
        <div :if={@query == "" and @segment == "all"} class="px-4 py-8">
          <p class="text-sm font-semibold text-zinc-100">Start typing to narrow the inventory.</p>
          <p class="mt-1 text-sm text-zinc-500">
            The first render still shows the full local dataset so there is something real to scan.
          </p>
        </div>

        <div :if={@results == []} class="px-4 py-8">
          <p class="text-sm font-semibold text-zinc-100">No matching records.</p>
          <p class="mt-1 text-sm text-zinc-500">
            Try a broader term or switch the segment back to all.
          </p>
        </div>

        <article :for={item <- @results} class="px-4 py-3 transition hover:bg-zinc-900/80">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0">
              <h2 class="truncate text-sm font-semibold text-zinc-100">{item.name}</h2>
              <p class="mt-1 text-xs text-zinc-500">{item.type} · {item.owner}</p>
            </div>
            <div class="flex flex-wrap gap-1">
              <span
                :for={tag <- item.tags}
                class="rounded bg-zinc-900 px-2 py-1 text-xs text-zinc-400"
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
