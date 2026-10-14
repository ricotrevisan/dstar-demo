defmodule ExplainerBenchWeb.InboxLive do
  @moduledoc """
  The LiveView side, written the way the LiveView docs recommend: messages
  in a stream (so the process does not keep the list), the badge in the
  same LiveView (no nested LiveView — the cheapest LiveView shape, which
  favours LiveView in this comparison).
  """
  use Phoenix.LiveView

  import ExplainerBenchWeb.InboxComponents

  alias ExplainerBench.{Inbox, Stats}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Stats.bump(:lv_mount_socket)
      Inbox.subscribe()
      # So /bench/drop can close the WebSocket the way a deploy would.
      Registry.register(ExplainerBench.Conns, :liveview, socket.transport_pid)
    else
      Stats.bump(:lv_mount_http)
    end

    {:ok,
     socket
     |> assign(unread: Inbox.unread_count())
     |> stream(:messages, Inbox.list())}
  end

  @impl true
  def handle_event("read", %{"id" => id}, socket) do
    Stats.bump(:events)
    message = Inbox.toggle_read(String.to_integer(id))
    {:noreply, apply_change(socket, message)}
  end

  @impl true
  def handle_info({:inbox_changed, message}, socket),
    do: {:noreply, apply_change(socket, message)}

  defp apply_change(socket, message) do
    socket
    |> assign(unread: Inbox.unread_count())
    |> stream_insert(:messages, message)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app">
      <.sidebar unread={@unread} />
      <main id="messages" phx-update="stream">
        <.row
          :for={{dom_id, m} <- @streams.messages}
          id={dom_id}
          message={m}
          phx-click="read"
          phx-value-id={m.id}
        />
      </main>
    </div>
    """
  end
end
