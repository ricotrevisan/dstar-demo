defmodule ExplainerBench.Client.LiveViewTab do
  @moduledoc """
  One simulated browser tab on the LiveView page, speaking the same wire
  protocol as `phoenix_live_view.js` (serializer vsn 2.0.0):

    1. GET the page — keep the cookie, CSRF token, `data-phx-session`
       and `data-phx-static`.
    2. Open `/live/websocket` and send `phx_join` for the page's topic.
    3. Clicks are `event` messages; the reply carries the diff.
    4. Broadcast updates arrive as `diff` pushes.
    5. If the socket closes, reconnect at once and rejoin (no new GET),
       which is what the JS client does after a deploy, minus its backoff.

  Pushes and reconnects are reported to the coordinator process.
  """
  use GenServer

  alias ExplainerBench.Client.Page

  @heartbeat_ms 25_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def open(pid), do: GenServer.call(pid, :open, 120_000)

  @doc "Returns `{:ok, %{micros: round_trip, bytes: reply_frame_bytes}}`."
  def click(pid, message_id), do: GenServer.call(pid, {:click, message_id}, 30_000)

  @impl true
  def init(%{id: id, port: port, coordinator: coordinator}) do
    Process.send_after(self(), :heartbeat, @heartbeat_ms)

    {:ok,
     %{
       id: id,
       port: port,
       coordinator: coordinator,
       page: nil,
       topic: nil,
       conn: nil,
       ref: nil,
       ws: nil,
       upgrade: %{},
       join_ref: nil,
       next_ref: 0,
       mounts: 0,
       pending: %{},
       opener: nil
     }}
  end

  @impl true
  def handle_call(:open, from, state) do
    page = Page.load(state.port, "/lv/inbox")
    state = %{state | page: page, topic: "lv:" <> page.lv.id}

    case connect(state) do
      {:ok, state} -> {:noreply, %{state | opener: from}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:click, message_id}, from, %{ws: ws} = state) when ws != nil do
    {ref, state} = next_ref(state)
    payload = %{type: "click", event: "read", value: %{id: Integer.to_string(message_id)}}
    state = send_frame(state, [state.join_ref, ref, state.topic, "event", payload])
    {:noreply, put_in(state.pending[ref], {from, now()})}
  end

  def handle_call({:click, _}, _from, state), do: {:reply, {:error, :not_joined}, state}

  @impl true
  def handle_info(:heartbeat, state) do
    Process.send_after(self(), :heartbeat, @heartbeat_ms)

    if state.ws do
      {ref, state} = next_ref(state)
      {:noreply, send_frame(state, [nil, ref, "phoenix", "heartbeat", %{}])}
    else
      {:noreply, state}
    end
  end

  def handle_info(:retry, state), do: reconnect(state)

  def handle_info(message, %{conn: conn} = state) when conn != nil do
    case Mint.WebSocket.stream(conn, message) do
      {:ok, conn, responses} ->
        {:noreply, Enum.reduce(responses, %{state | conn: conn}, &handle_response/2)}

      {:error, conn, _reason, _responses} ->
        reconnect(%{state | conn: conn})

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  # ── Connection ────────────────────────────────────────────────────────

  defp connect(state) do
    query = URI.encode_query(%{"_csrf_token" => state.page.csrf, "vsn" => "2.0.0"})

    with {:ok, conn} <-
           Mint.HTTP.connect(:http, "127.0.0.1", state.port, protocols: [:http1]),
         {:ok, conn, ref} <-
           Mint.WebSocket.upgrade(:ws, conn, "/live/websocket?" <> query, [
             {"cookie", state.page.cookie}
           ]) do
      {:ok, %{state | conn: conn, ref: ref, ws: nil, upgrade: %{}}}
    end
  end

  defp reconnect(state) do
    if state.conn, do: Mint.HTTP.close(state.conn)
    state = %{state | conn: nil, ws: nil, pending: %{}}

    case connect(state) do
      {:ok, state} ->
        {:noreply, state}

      {:error, _reason} ->
        Process.send_after(self(), :retry, 50)
        {:noreply, state}
    end
  end

  defp join(state) do
    {ref, state} = next_ref(state)

    payload = %{
      url: "http://127.0.0.1:#{state.port}/lv/inbox",
      params: %{"_csrf_token" => state.page.csrf, "_mounts" => state.mounts},
      session: state.page.lv.session,
      static: state.page.lv.static,
      sticky: false
    }

    state = %{state | join_ref: ref, mounts: state.mounts + 1}
    send_frame(state, [ref, ref, state.topic, "phx_join", payload])
  end

  # ── Mint responses and frames ─────────────────────────────────────────

  defp handle_response({:status, ref, status}, %{ref: ref} = state),
    do: put_in(state.upgrade[:status], status)

  defp handle_response({:headers, ref, headers}, %{ref: ref} = state),
    do: put_in(state.upgrade[:headers], headers)

  defp handle_response({:done, ref}, %{ref: ref, ws: nil} = state) do
    case Mint.WebSocket.new(state.conn, ref, state.upgrade.status, state.upgrade.headers) do
      {:ok, conn, ws} -> join(%{state | conn: conn, ws: ws})
      {:error, _conn, reason} -> raise "WebSocket upgrade failed: #{inspect(reason)}"
    end
  end

  defp handle_response({:data, ref, data}, %{ref: ref, ws: ws} = state) when ws != nil do
    {:ok, ws, frames} = Mint.WebSocket.decode(ws, data)
    Enum.reduce(frames, %{state | ws: ws}, &handle_frame/2)
  end

  defp handle_response(_response, state), do: state

  defp handle_frame({:text, text}, state) do
    case Jason.decode!(text) do
      [_join_ref, ref, _topic, "phx_reply", %{"status" => status}] ->
        handle_reply(ref, status, byte_size(text), state)

      [_join_ref, nil, _topic, "diff", _diff] ->
        send(state.coordinator, {:push, state.id, now(), byte_size(text)})
        state

      _other ->
        state
    end
  end

  defp handle_frame({:ping, data}, state) do
    {:ok, ws, bytes} = Mint.WebSocket.encode(state.ws, {:pong, data})
    {:ok, conn} = Mint.WebSocket.stream_request_body(state.conn, state.ref, bytes)
    %{state | ws: ws, conn: conn}
  end

  defp handle_frame(_frame, state), do: state

  defp handle_reply(ref, status, _bytes, %{join_ref: ref} = state) do
    if status != "ok", do: raise("join was refused: #{status}")

    case state.opener do
      nil ->
        send(state.coordinator, {:reconnected, state.id, now()})
        state

      from ->
        GenServer.reply(from, {:ok, %{html_bytes: state.page.html_bytes}})
        %{state | opener: nil}
    end
  end

  defp handle_reply(ref, _status, bytes, state) do
    case Map.pop(state.pending, ref) do
      {nil, _} ->
        state

      {{from, started}, pending} ->
        GenServer.reply(from, {:ok, %{micros: now() - started, bytes: bytes}})
        %{state | pending: pending}
    end
  end

  defp send_frame(state, message) do
    {:ok, ws, data} = Mint.WebSocket.encode(state.ws, {:text, Jason.encode!(message)})
    {:ok, conn} = Mint.WebSocket.stream_request_body(state.conn, state.ref, data)
    %{state | ws: ws, conn: conn}
  end

  defp next_ref(state) do
    ref = state.next_ref + 1
    {Integer.to_string(ref), %{state | next_ref: ref}}
  end

  defp now, do: System.monotonic_time(:microsecond)
end
