defmodule DstarDemoWeb.LiveCollectionsPage do
  use DstarDemoWeb, :dstar_page

  alias DstarDemo.LiveCollections

  @filters ~w(all queued active done)

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      items: LiveCollections.list_items(),
      arrivals: LiveCollections.list_arrivals(),
      statusFilter: "all",
      newItemTitle: ""
    )
  end

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    :ok = LiveCollections.subscribe()
    nudge(conn, "work_items")
  end

  @impl Dstar.Page
  def handle_disconnect(conn) do
    Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, LiveCollections.topic())
    conn
  end

  @impl Dstar.Page
  def handle_event(conn, "reload", signals) do
    filter = LiveCollections.normalize_filter(signals["statusFilter"])
    items = LiveCollections.list_items(filter)

    patch(conn, &item_panel/1, items: items, filter: filter)
  end

  def handle_event(conn, "create", signals) do
    case LiveCollections.create_item(%{title: signals["newItemTitle"]}) do
      {:ok, item} ->
        conn
        |> patch_signals(%{newItemTitle: ""})
        |> patch(&feedback/1,
          tone: "good",
          message: "Created ##{item.id}. PubSub is nudging every filtered tab."
        )

      {:error, _changeset} ->
        patch(conn, &feedback/1,
          tone: "bad",
          message: "Use a title between 2 and 80 characters."
        )
    end
  end

  def handle_event(conn, "advance", signals) do
    case LiveCollections.advance_item(signals["itemId"]) do
      {:ok, item} ->
        patch(conn, &feedback/1,
          tone: "good",
          message: "Moved ##{item.id} to #{status_label(item.status)}."
        )

      {:error, _reason} ->
        patch(conn, &feedback/1, tone: "bad", message: "That work item is no longer available.")
    end
  end

  @impl Dstar.Page
  def handle_info({:live_collection_changed, :created, item}, conn) do
    conn
    |> nudge("work_items")
    |> append_elements(arrival_row(%{item: item}), "#arrival-feed")
  end

  def handle_info({:live_collection_changed, :updated, _item}, conn) do
    nudge(conn, "work_items")
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:filters, @filters)
      |> Map.put(:snippet, DstarDemoWeb.Snippets.fetch!(:live_collections))

    ~H"""
    <.demo_shell
      active="Live Collections"
      title="Live collections"
      summary="Every tab keeps its own filter. PubSub sends a tiny nudge, then each browser reloads the collection with the signals it actually holds."
      signals={%{statusFilter: @statusFilter, newItemTitle: @newItemTitle, itemId: nil}}
    >
      <:demo>
        <section
          id="live-collections-demo"
          data-init={connect()}
          data-on:online__window={connect()}
          class="grid gap-5"
        >
          <div id="collection-composer" class="border border-base-300 bg-base-200 p-5">
            <div class="flex flex-col gap-4 md:flex-row md:items-end">
              <label class="min-w-0 flex-1">
                <span class="mb-2 block text-sm font-medium text-base-content/80">
                  Add a queued work item
                </span>
                <input
                  id="collection-title"
                  type="text"
                  maxlength="80"
                  autocomplete="off"
                  data-bind:new-item-title
                  data-on:keydown={"evt.key === 'Enter' && (evt.preventDefault(), #{event("create")})"}
                  placeholder="For example: verify the filtered tab"
                  class="w-full rounded-md border border-base-300 bg-base-100 px-3 py-2.5 text-base-content placeholder:text-base-content/50 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary"
                />
              </label>
              <button
                id="collection-create"
                type="button"
                data-indicator="_collectionPending"
                data-on:click={event("create")}
                class="inline-flex items-center justify-center gap-2 rounded-md border border-primary bg-primary px-4 py-2.5 text-sm font-medium text-primary-content transition hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <.icon name="hero-plus-micro" class="size-4" /> Create item
              </button>
            </div>
            <.feedback tone="neutral" message="Changes arrive through the open PubSub stream." />
          </div>

          <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
            <section class="min-w-0 border border-base-300 bg-base-100">
              <header class="border-b border-base-300 p-4">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p class="text-sm font-semibold text-base-content">This tab's filtered query</p>
                    <p class="mt-1 text-xs text-base-content/65">
                      Switch another tab to a different status, then mutate either one.
                    </p>
                  </div>
                  <span
                    data-show="$_collectionPending"
                    class="font-mono text-xs text-primary"
                  >
                    reloading
                  </span>
                </div>
                <div class="mt-4 flex flex-wrap gap-2" aria-label="Work item status">
                  <button
                    :for={filter <- @filters}
                    id={"collection-filter-#{filter}"}
                    type="button"
                    data-indicator="_collectionPending"
                    data-on:click={"$statusFilter = '#{filter}'; #{event("reload")}"}
                    data-class:border-primary={"$statusFilter === '#{filter}'"}
                    data-class:bg-primary={"$statusFilter === '#{filter}'"}
                    data-class:text-primary-content={"$statusFilter === '#{filter}'"}
                    class="rounded-md border border-base-300 px-3 py-1.5 text-sm font-medium capitalize transition hover:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                  >
                    {filter}
                  </button>
                </div>
              </header>

              <.item_panel items={@items} filter="all" />
            </section>

            <aside class="border border-base-300 bg-base-200 p-4">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-base-content">Append-safe arrivals</p>
                  <p class="mt-1 text-xs text-base-content/65">Plain · chronological · immutable</p>
                </div>
                <.pill label="fast path" tone="info" />
              </div>
              <div id="arrival-feed" class="mt-4 grid gap-2">
                <.arrival_row :for={item <- @arrivals} item={item} />
              </div>
            </aside>
          </div>
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "The stream knows that data changed, but never guesses what a tab is showing.",
          "nudge/2 changes nudges.work_items; on_nudge/2 posts the tab's current signals.",
          "reload queries Postgres with that tab's statusFilter and patches one panel.",
          "Only the separate unfiltered arrival feed uses append_elements/3."
        ]} />

        <.prose>
          The filtered collection deliberately does not receive row mutations. An item can leave
          one filter and enter another, so every open tab re-runs its own query. The arrival lane is
          the contrast: it contains immutable creation facts in append order, making a direct append
          correct rather than merely faster.
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

  attr :items, :list, required: true
  attr :filter, :string, required: true

  def item_panel(assigns) do
    ~H"""
    <div
      id="collection-items"
      {on_nudge("work_items", event("reload"))}
      class="divide-y divide-base-300"
    >
      <div :if={@items == []} class="p-8 text-center">
        <p class="text-sm font-semibold text-base-content">No {@filter} items.</p>
        <p class="mt-1 text-sm text-base-content/65">This tab's query is current.</p>
      </div>

      <article
        :for={item <- @items}
        id={"item-#{item.id}"}
        class="flex items-center justify-between gap-4 p-4 transition hover:bg-base-200"
      >
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="truncate text-sm font-semibold text-base-content">{item.title}</h3>
            <.pill label={status_label(item.status)} tone={status_tone(item.status)} />
          </div>
          <p class="mt-1 font-mono text-xs text-base-content/60">work item {item.id}</p>
        </div>
        <button
          id={"item-advance-#{item.id}"}
          type="button"
          data-on:click={"$itemId = '#{item.id}'; #{event("advance")}"}
          class="shrink-0 rounded-md border border-base-300 px-3 py-1.5 text-sm font-medium text-base-content/80 transition hover:border-primary hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
        >
          {advance_label(item.status)}
        </button>
      </article>
    </div>
    """
  end

  attr :item, :map, required: true

  def arrival_row(assigns) do
    ~H"""
    <article id={"arrival-#{@item.id}"} class="border border-base-300 bg-base-100 px-3 py-2.5">
      <p class="truncate text-sm font-medium text-base-content">{@item.title}</p>
      <p class="mt-1 font-mono text-xs text-base-content/60">arrived as #{item_ref(@item)}</p>
    </article>
    """
  end

  attr :tone, :string, required: true
  attr :message, :string, required: true

  def feedback(assigns) do
    ~H"""
    <p
      id="collection-feedback"
      class={[
        "mt-3 text-sm",
        @tone == "good" && "text-success",
        @tone == "bad" && "text-error",
        @tone == "neutral" && "text-base-content/65"
      ]}
    >
      {@message}
    </p>
    """
  end

  defp status_label(:queued), do: "queued"
  defp status_label(:active), do: "active"
  defp status_label(:done), do: "done"

  defp status_tone(:queued), do: "neutral"
  defp status_tone(:active), do: "info"
  defp status_tone(:done), do: "good"

  defp advance_label(:queued), do: "Start"
  defp advance_label(:active), do: "Finish"
  defp advance_label(:done), do: "Requeue"

  defp item_ref(item), do: "##{item.id}"
end
