defmodule DstarDemoWeb.SnippetDriftTest do
  @moduledoc """
  Snippets drifting from the code they document is the standard failure mode of
  a documentation site. Every snippet this site shows as real Dstar code is an
  excerpt from a page module, and this test proves it still is.

  Comparison matching ignores each line's leading whitespace: moving markup
  between slots re-indents it, which is not drift. Everything that matters —
  renamed functions, changed arguments, deleted calls — still fails.

  A snippet may stitch several excerpts together with lines containing only
  `# ...`; each stitched chunk must appear verbatim in the source.
  """
  use ExUnit.Case, async: true

  alias DstarDemoWeb.Snippets

  defp flush(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.join("\n")
    |> String.trim()
  end

  for {demo, entry} <- Snippets.all() do
    @demo demo
    @entry entry

    test "#{demo}: the source file the snippets claim to quote exists" do
      assert File.exists?(@entry.source), "missing source: #{@entry.source}"
    end

    test "#{demo}: the How-it-works snippet appears in the page module" do
      source = flush(File.read!(@entry.source))

      for chunk <- String.split(flush(@entry.wiring), ~r/^#\s\.\.\.$/m),
          chunk = String.trim(chunk),
          chunk != "" do
        assert String.contains?(source, chunk), """
        A wiring excerpt for #{@demo} no longer appears in #{@entry.source}.

        Either the page changed and the snippet in DstarDemoWeb.Snippets must be
        updated to match, or the snippet was mistyped.

        Excerpt:
        #{chunk}
        """
      end
    end
  end

  test "a comparison is never half-written" do
    # The Dstar side of a comparison renders `wiring`, which is already checked
    # above — so a comparison is complete when it also has a LiveView side and
    # a note. The note is what carries the concession, so it is not optional.
    for {demo, entry} <- Snippets.all(), entry.liveview || entry.note do
      assert is_binary(entry.liveview), "#{demo} has a comparison note but no LiveView side"

      assert is_binary(entry.note),
             "#{demo} has a LiveView side but no <:note> conceding where LiveView wins"
    end
  end
end
