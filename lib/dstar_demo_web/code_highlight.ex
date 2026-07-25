defmodule DstarDemoWeb.CodeHighlight do
  @moduledoc """
  Server-side syntax highlighting for the documentation snippets.

  Wraps Makeup so these pages never ship a highlighter to the browser.
  Snippets are stored carrying the indentation they have in the source file
  they were excerpted from, so `DstarDemoWeb.Snippets` can be checked
  against that file; `dedent/1` strips it back off for display.
  """

  @lexers %{"elixir" => "elixir", "heex" => "heex"}

  @doc """
  Highlights `code` and returns safe HTML for embedding inside a `<code>` tag.

  Makeup escapes the source text itself, so the result is safe to mark raw.
  """
  @spec highlight(String.t(), String.t()) :: {:safe, iodata()}
  def highlight(code, language) when is_binary(code) and is_binary(language) do
    lexer = Map.fetch!(@lexers, language)

    code
    |> dedent()
    # Both lexers default group_prefix to a random string, so identical input
    # would render different HTML (and different data-group-id attributes) on
    # every call. Pin it: we don't ship the JS that uses those ids, and
    # deterministic output matters for both testability and Datastar's
    # fragment diffing (a random prefix always looks "changed").
    |> Makeup.highlight_inner_html(lexer: lexer, lexer_options: [group_prefix: "hl"])
    |> Phoenix.HTML.raw()
  end

  @doc """
  Strips the common leading indentation from every non-blank line, and trims
  surrounding blank lines.

  Blank lines are excluded from the indentation measurement — otherwise one
  empty line in the middle of a snippet would flatten the whole thing.
  """
  @spec dedent(String.t()) :: String.t()
  def dedent(code) when is_binary(code) do
    # Trim blank (whitespace-only, not just literal "\n") lines from both
    # ends by dropping list elements, not by string-trimming the raw text —
    # `String.trim(code, "\n")` only strips literal newline characters, so a
    # leading line of pure spaces would survive and render as a blank first
    # row inside the <pre>.
    lines =
      code
      |> String.split("\n")
      |> Enum.drop_while(&(String.trim(&1) == ""))
      |> Enum.reverse()
      |> Enum.drop_while(&(String.trim(&1) == ""))
      |> Enum.reverse()

    indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&(String.length(&1) - String.length(String.trim_leading(&1))))
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(fn line ->
      if String.trim(line) == "", do: "", else: String.slice(line, indent..-1//1)
    end)
    |> Enum.join("\n")
  end
end
