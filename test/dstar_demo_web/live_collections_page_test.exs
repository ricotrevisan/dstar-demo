defmodule DstarDemoWeb.LiveCollectionsPageTest do
  use DstarDemoWeb.ConnCase, async: false

  import Dstar.Test

  alias DstarDemo.LiveCollections
  alias DstarDemo.LiveCollections.Item
  alias DstarDemo.Repo
  alias DstarDemoWeb.LiveCollectionsPage

  test "GET /collections renders the showcase through the router", %{conn: conn} do
    item = insert_item!("Routed collection", :queued)
    response = conn |> get(~p"/collections") |> html_response(200)

    assert response =~ "Live collections"
    assert response =~ ~s(id="live-collections-demo")
    assert response =~ ~s(id="item-#{item.id}")
    assert response =~ "Showcase"
    assert response =~ "Examples / Reference"
  end

  test "renders independent filters, nudge wiring, and stable row ids", %{conn: conn} do
    queued = insert_item!("Queued card", :queued)
    _done = insert_item!("Done card", :done)
    mounted = LiveCollectionsPage.mount(conn, %{})
    html = render_page(mounted.assigns)
    document = LazyHTML.from_fragment(html)

    assert LazyHTML.query(document, "#live-collections-demo")
    assert LazyHTML.query(document, "#collection-composer")
    assert LazyHTML.query(document, "#collection-filter-queued")
    assert LazyHTML.query(document, "#collection-filter-done")
    assert LazyHTML.query(document, "#item-#{queued.id}")
    assert LazyHTML.query(document, "#arrival-feed")

    panel = LazyHTML.query(document, "#collection-items")
    [action] = LazyHTML.attribute(panel, "data-on-signal-patch")
    assert action =~ "/_event/reload"

    [filter] = LazyHTML.attribute(panel, "data-on-signal-patch-filter")
    assert Jason.decode!(filter) == %{"include" => "^nudges\\.work_items$"}

    assert html =~ "data-bind:new-item-title"
    assert html =~ "data-init="
  end

  test "reload uses the requesting tab's filter and never echoes it", %{conn: conn} do
    queued = insert_item!("Only queued", :queued)
    done = insert_item!("Only done", :done)

    queued_conn = event_conn(conn, "reload", %{"statusFilter" => "queued"})
    assert_patched_element(queued_conn, "#collection-items")
    assert sse_body(queued_conn) =~ ~s(id="item-#{queued.id}")
    refute sse_body(queued_conn) =~ ~s(id="item-#{done.id}")
    refute sse_body(queued_conn) =~ "datastar-patch-signals"

    done_conn = event_conn(conn, "reload", %{"statusFilter" => "done"})
    assert sse_body(done_conn) =~ ~s(id="item-#{done.id}")
    refute sse_body(done_conn) =~ ~s(id="item-#{queued.id}")
  end

  test "create persists and patches feedback, leaving list delivery to PubSub", %{conn: conn} do
    :ok = LiveCollections.subscribe()

    response = event_conn(conn, "create", %{"newItemTitle" => "New arrival"})

    assert %Item{status: :queued} = Repo.get_by(Item, title: "New arrival")
    assert_receive {:live_collection_changed, :created, %Item{title: "New arrival"}}
    assert_patched_element(response, "#collection-feedback")
    assert_patched_signals(response, %{newItemTitle: ""})
    refute sse_body(response) =~ "selector #collection-items"
    refute sse_body(response) =~ "selector #arrival-feed"
  after
    Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, LiveCollections.topic())
  end

  test "advance moves a row between subsequent filtered reloads", %{conn: conn} do
    item = insert_item!("Advance me", :queued)

    response = event_conn(conn, "advance", %{"itemId" => Integer.to_string(item.id)})
    assert_patched_element(response, "#collection-feedback")
    assert Repo.get!(Item, item.id).status == :active

    queued = event_conn(conn, "reload", %{"statusFilter" => "queued"})
    active = event_conn(conn, "reload", %{"statusFilter" => "active"})
    refute sse_body(queued) =~ ~s(id="item-#{item.id}")
    assert sse_body(active) =~ ~s(id="item-#{item.id}")
  end

  test "real PubSub messages nudge filtered views and append only immutable arrivals", %{
    conn: conn
  } do
    item = insert_item!("Stream item", :queued)
    stream_conn = conn |> recycle() |> Dstar.start()
    connected = LiveCollectionsPage.handle_connect(stream_conn, %{})
    assert_patched_signals(connected, %{nudges: %{"work_items" => patched_nudge(connected)}})

    Phoenix.PubSub.broadcast(
      DstarDemo.PubSub,
      LiveCollections.topic(),
      {:live_collection_changed, :created, item}
    )

    assert_receive message = {:live_collection_changed, :created, ^item}
    created = LiveCollectionsPage.handle_info(message, connected)
    assert is_integer(patched_nudge(created))
    assert_patched_element(created, "#arrival-#{item.id}")
    assert sse_body(created) =~ "selector #arrival-feed"
    assert sse_body(created) =~ "mode append"

    updated =
      LiveCollectionsPage.handle_info({:live_collection_changed, :updated, item}, connected)

    assert is_integer(patched_nudge(updated))
    refute sse_body(updated) =~ "selector #arrival-feed"

    LiveCollectionsPage.handle_disconnect(updated)
    Phoenix.PubSub.broadcast(DstarDemo.PubSub, LiveCollections.topic(), :subscription_probe)
    refute_receive :subscription_probe
  end

  defp render_page(assigns) do
    assigns
    |> Map.put(:__changed__, nil)
    |> LiveCollectionsPage.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp event_conn(conn, event, signals) do
    conn
    |> recycle()
    |> Dstar.start()
    |> LiveCollectionsPage.handle_event(event, signals)
  end

  defp patched_nudge(conn) do
    conn
    |> patched_signals()
    |> get_in(["nudges", "work_items"])
  end

  defp insert_item!(title, status) do
    %Item{}
    |> Item.changeset(%{title: title, status: status})
    |> Repo.insert!()
  end

  defp sse_body(conn), do: conn.resp_body || ""
end
