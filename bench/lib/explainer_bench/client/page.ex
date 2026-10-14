defmodule ExplainerBench.Client.Page do
  @moduledoc """
  What a browser keeps from the first HTML response: the session cookie,
  the CSRF token, and (for LiveView) the tokens the socket join needs.
  """

  def load(port, path) do
    {:ok, %{status: 200} = resp} = ExplainerBench.Client.HTTP.get(port, path)

    %{
      cookie: cookie(resp.headers),
      csrf: capture!(resp.body, ~r/name="csrf-token" content="([^"]+)"/),
      html_bytes: byte_size(resp.body),
      micros: resp.micros,
      lv:
        if String.starts_with?(path, "/lv") do
          %{
            id: capture!(resp.body, ~r/id="(phx-[^"]+)"/),
            session: capture!(resp.body, ~r/data-phx-session="([^"]+)"/),
            static: capture!(resp.body, ~r/data-phx-static="([^"]+)"/)
          }
        end
    }
  end

  defp cookie(headers) do
    for {"set-cookie", value} <- headers, into: "" do
      value |> String.split(";", parts: 2) |> hd()
    end
  end

  defp capture!(html, regex) do
    case Regex.run(regex, html) do
      [_, value] -> value
      nil -> raise "page did not contain #{inspect(regex.source)}"
    end
  end
end
