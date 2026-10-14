defmodule ExplainerBench.Client.HTTP do
  @moduledoc """
  One-shot HTTP/1.1 requests over a fresh connection, in passive mode.
  Used for page loads, Dstar event POSTs and the control plane. A fresh
  connection per request is the conservative choice for Dstar's events:
  a browser on keep-alive or HTTP/2 would skip the TCP connect.
  """

  @timeout 30_000

  def get(port, path, headers \\ []), do: request(port, "GET", path, headers, nil)

  def post_json(port, path, body, headers \\ []) do
    request(
      port,
      "POST",
      path,
      [{"content-type", "application/json"} | headers],
      Jason.encode!(body)
    )
  end

  @doc "Returns `{:ok, %{status, headers, body, micros}}`; `micros` spans connect to last byte."
  def request(port, method, path, headers, body) do
    started = System.monotonic_time(:microsecond)

    with {:ok, conn} <-
           Mint.HTTP.connect(:http, "127.0.0.1", port, mode: :passive, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.HTTP.request(conn, method, path, headers, body),
         {:ok, conn, acc} <- recv(conn, ref, %{status: nil, headers: [], body: []}) do
      Mint.HTTP.close(conn)

      {:ok,
       %{
         status: acc.status,
         headers: acc.headers,
         body: IO.iodata_to_binary(acc.body),
         micros: System.monotonic_time(:microsecond) - started
       }}
    end
  end

  defp recv(conn, ref, acc) do
    case Mint.HTTP.recv(conn, 0, @timeout) do
      {:ok, conn, responses} ->
        case Enum.reduce(responses, {acc, false}, &collect(&1, &2, ref)) do
          {acc, true} -> {:ok, conn, acc}
          {acc, false} -> recv(conn, ref, acc)
        end

      {:error, conn, reason, _} ->
        Mint.HTTP.close(conn)
        {:error, reason}
    end
  end

  defp collect({:status, ref, s}, {acc, d}, ref), do: {%{acc | status: s}, d}
  defp collect({:headers, ref, h}, {acc, d}, ref), do: {%{acc | headers: acc.headers ++ h}, d}
  defp collect({:data, ref, data}, {acc, d}, ref), do: {%{acc | body: [acc.body, data]}, d}
  defp collect({:done, ref}, {acc, _}, ref), do: {acc, true}
  defp collect(_other, acc, _ref), do: acc

  def json!(port, method, path) do
    {:ok, %{status: 200, body: body}} =
      request(port, method, path, [], if(method == "POST", do: ""))

    Jason.decode!(body)
  end
end
