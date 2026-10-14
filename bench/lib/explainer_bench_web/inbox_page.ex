defmodule ExplainerBenchWeb.InboxPage do
  @moduledoc """
  The Dstar side: the same markup, a stream opened by `data-init`, and one
  handler that patches the changed row and the badge. The `dstar_nostream`
  model loads this same page but never opens the stream.
  """
  use Dstar.Page

  import ExplainerBenchWeb.InboxComponents

  alias ExplainerBench.{Inbox, Stats}

  @impl Dstar.Page
  def mount(conn, _params) do
    Stats.bump(:ds_mount)
    assign(conn, unread: Inbox.unread_count(), messages: Inbox.list())
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <div class="app">
      <.sidebar unread={@unread} />
      <main id="messages" data-init={connect()}>
        <.message_row :for={m <- @messages} message={m} />
      </main>
    </div>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "read:" <> id, _signals) do
    Stats.bump(:events)
    message = Inbox.toggle_read(String.to_integer(id))
    patch_change(conn, message)
  end

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    Stats.bump(:ds_connect)
    Inbox.subscribe()
    # So /bench/drop can close the stream the way a deploy would.
    Registry.register(ExplainerBench.Conns, :dstar, self())
    # Re-read the badge: what a reconnecting tab needs, and the first event
    # the client waits for before it counts the stream as back.
    patch(conn, &sidebar/1, unread: Inbox.unread_count())
  end

  @impl Dstar.Page
  def handle_info({:inbox_changed, message}, conn), do: patch_change(conn, message)

  defp patch_change(conn, message) do
    conn
    |> patch(&message_row/1, message: message)
    |> patch(&sidebar/1, unread: Inbox.unread_count())
  end

  attr :message, :map, required: true

  def message_row(assigns) do
    ~H"""
    <.row
      id={"messages-#{@message.id}"}
      message={@message}
      data-on:click={event("read:#{@message.id}")}
    />
    """
  end
end
