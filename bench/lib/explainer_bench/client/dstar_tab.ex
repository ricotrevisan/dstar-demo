defmodule ExplainerBench.Client.DstarTab do
  @moduledoc """
  One simulated browser tab on the Dstar page, doing what Datastar 1.0's
  fetch does (same `Accept` and `Datastar-Request` headers):

    1. GET the page — keep the cookie and the CSRF token.
    2. Optionally open the stream `data-init={connect()}` asks for: a POST to
       the page path whose response is a long-lived `text/event-stream`.
       It counts as open once `handle_connect/2`'s first patch arrives.
    3. Patches arriving on the stream are reported as pushes.
    4. If the stream closes, POST again at once (Datastar retries with
       backoff; the benchmark skips the backoff on both sides).

  Clicks are not sent from here: they are independent POSTs, so the runner
  sends them itself with `credentials/1`, and this process never blocks.
  """
  use GenServer

  alias ExplainerBench.Client.Page

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def open(pid, stream?), do: GenServer.call(pid, {:open, stream?}, 120_000)

  def credentials(pid), do: GenServer.call(pid, :credentials)

  @impl true
  def init(%{id: id, port: port, coordinator: coordinator}) do
    {:ok,
     %{
       id: id,
       port: port,
       coordinator: coordinator,
       page: nil,
       conn: nil,
       ref: nil,
       live?: false,
       opener: nil
     }}
  end

  @impl true
  def handle_call({:open, stream?}, from, state) do
    page = Page.load(state.port, "/ds/inbox")
    state = %{state | page: page}

    if stream? do
      {:noreply, %{start_stream(state) | opener: from}}
    else
      {:reply, {:ok, %{html_bytes: page.html_bytes}}, state}
    end
  end

  def handle_call(:credentials, _from, state) do
    {:reply, %{cookie: state.page.cookie, csrf: state.page.csrf}, state}
  end

  @impl true
  def handle_info(:retry, state), do: {:noreply, start_stream(state)}

  def handle_info(message, %{conn: conn} = state) when conn != nil do
    case Mint.HTTP.stream(conn, message) do
      {:ok, conn, responses} ->
        {:noreply, Enum.reduce(responses, %{state | conn: conn}, &handle_response/2)}

      {:error, conn, _reason, _responses} ->
        Mint.HTTP.close(conn)
        {:noreply, start_stream(%{state | conn: nil})}

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp start_stream(state) do
    headers = [
      {"content-type", "application/json"},
      {"accept", "text/event-stream, text/html, application/json"},
      {"datastar-request", "true"},
      {"cookie", state.page.cookie}
    ]

    body = Jason.encode!(%{csrf: state.page.csrf, tabId: "tab-#{state.id}"})

    with {:ok, conn} <-
           Mint.HTTP.connect(:http, "127.0.0.1", state.port, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.HTTP.request(conn, "POST", "/ds/inbox", headers, body) do
      %{state | conn: conn, ref: ref, live?: false}
    else
      _error ->
        Process.send_after(self(), :retry, 50)
        %{state | conn: nil, live?: false}
    end
  end

  defp handle_response({:status, ref, 200}, %{ref: ref} = state), do: state

  defp handle_response({:status, ref, status}, %{ref: ref}),
    do: raise("stream refused with HTTP #{status}")

  defp handle_response({:data, ref, data}, %{ref: ref} = state) do
    cond do
      not String.contains?(data, "event: datastar") ->
        # Keep-alive comments, not patches.
        state

      not state.live? ->
        established(%{state | live?: true})

      true ->
        send(state.coordinator, {:push, state.id, now(), byte_size(data)})
        state
    end
  end

  # The server ended the stream (e.g. it was dropped cleanly): reconnect.
  defp handle_response({:done, ref}, %{ref: ref} = state) do
    Mint.HTTP.close(state.conn)
    start_stream(%{state | conn: nil})
  end

  defp handle_response(_response, state), do: state

  defp established(%{opener: nil} = state) do
    send(state.coordinator, {:reconnected, state.id, now()})
    state
  end

  defp established(%{opener: from} = state) do
    GenServer.reply(from, {:ok, %{html_bytes: state.page.html_bytes}})
    %{state | opener: nil}
  end

  defp now, do: System.monotonic_time(:microsecond)
end
