defmodule DstarDemoWeb.CodeHighlightTest do
  use ExUnit.Case, async: true

  alias DstarDemoWeb.CodeHighlight

  describe "dedent/1" do
    test "strips the common leading indentation" do
      input = "    def f(x) do\n      x + 1\n    end\n"
      assert CodeHighlight.dedent(input) == "def f(x) do\n  x + 1\nend"
    end

    test "leaves already-flush code alone" do
      assert CodeHighlight.dedent("a = 1\nb = 2") == "a = 1\nb = 2"
    end

    test "does not let a blank line drag the indent to zero" do
      input = "    a = 1\n\n    b = 2\n"
      assert CodeHighlight.dedent(input) == "a = 1\n\nb = 2"
    end

    test "trims leading and trailing blank lines" do
      assert CodeHighlight.dedent("\n\n  a = 1\n\n") == "a = 1"
    end
  end

  describe "highlight/2" do
    test "wraps Elixir tokens in Makeup spans" do
      {:safe, html} = CodeHighlight.highlight("def f(x), do: x", "elixir")
      assert IO.iodata_to_binary(html) =~ ~s(<span class="kd">def</span>)
    end

    test "highlights HEEx, including component and slot tags" do
      {:safe, html} =
        CodeHighlight.highlight(~s(<.demo_shell>\n  <:demo>x</:demo>\n</.demo_shell>), "heex")

      html = IO.iodata_to_binary(html)
      assert html =~ ~s(<span class="nf">.demo_shell</span>)
      assert html =~ ~s(<span class="ss">:demo</span>)
    end

    test "escapes the source so markup in a snippet cannot break out" do
      {:safe, html} = CodeHighlight.highlight(~s[<script>alert(1)</script>], "heex")
      html = IO.iodata_to_binary(html)
      refute html =~ "<script>"
      assert html =~ "&lt;"
    end

    test "dedents before highlighting" do
      {:safe, html} = CodeHighlight.highlight("      a = 1", "elixir")
      refute IO.iodata_to_binary(html) =~ "      "
    end

    test "rejects an unknown language" do
      assert_raise KeyError, fn -> CodeHighlight.highlight("x", "ruby") end
    end
  end
end
