defmodule DstarDemoWeb.ThemeTest do
  # Reads the compiled stylesheet, so it must not run concurrently with a build.
  use ExUnit.Case, async: false

  @css "priv/static/assets/css/app.css"

  # A previous version of this suite asserted plain substrings over the whole
  # compiled file. That cannot tell "the light theme has #ffffff" apart from
  # "the dark theme has #ffffff", so a mis-declared plugin block (tokens
  # swapped between themes) would still pass. These tests instead extract
  # each theme's own CSS rule and assert tokens only within it.
  @light_marker ~s([data-theme="light"])
  @dark_marker ~s([data-theme="dark"])
  @media_marker "prefers-color-scheme: dark"

  setup_all do
    case System.cmd("mix", ["tailwind", "dstar_demo"], cd: File.cwd!(), stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, css: File.read!(@css)}

      {output, exit_code} ->
        flunk("""
        `mix tailwind dstar_demo` exited #{exit_code}, so the compiled stylesheet \
        this suite depends on was not rebuilt. Output:

        #{output}
        """)
    end
  end

  test "the light theme is the default and carries the spec's tokens", %{css: css} do
    light = theme_rule(css, @light_marker)

    assert light =~ "--color-base-100: #ffffff"
    assert light =~ "--color-base-200: #fafafa"
    assert light =~ "--color-base-300: #e2e2e2"
    assert light =~ "--color-base-content: #111111"
    assert css =~ @light_marker
  end

  test "the dark theme is declared with the spec's tokens", %{css: css} do
    dark = theme_rule(css, @dark_marker)

    assert dark =~ "--color-base-100: #0c0c0c"
    assert dark =~ "--color-base-200: #141414"
    assert dark =~ "--color-base-300: #262626"
    assert dark =~ "--color-base-content: #f2f2f2"
    assert css =~ @dark_marker
  end

  test "the accent is the same orange in both modes, with a contrast-safe foreground", %{
    css: css
  } do
    light = theme_rule(css, @light_marker)
    dark = theme_rule(css, @dark_marker)

    # #e8590c is the shared accent in both themes.
    assert light =~ "--color-primary: #e8590c"
    assert dark =~ "--color-primary: #e8590c"

    # White-on-#e8590c is 3.58:1, below AA for normal text. #0c0c0c-on-#e8590c
    # is 5.47:1 and passes. This is the token every filled control (btn,
    # badge, etc.) reads its foreground from, so it must hold in both themes.
    assert light =~ "--color-primary-content: #0c0c0c"
    assert dark =~ "--color-primary-content: #0c0c0c"
  end

  # daisyUI's semantic defaults are tuned as solid fills on a dark surface, so
  # as text on white they fail AA — its error token is #ff627d, 2.87:1. The
  # light theme overrides them with darker variants so hue can carry meaning in
  # small text (the rejected-field message) rather than only in backgrounds.
  test "the light theme darkens the semantic tokens so they pass as text on white", %{css: css} do
    light = theme_rule(css, @light_marker)

    assert light =~ "--color-error: #b91c1c"
    assert light =~ "--color-success: #15803d"
    assert light =~ "--color-warning: #a16207"
    assert light =~ "--color-neutral: #a21caf"

    # All four are dark fills, so their foregrounds flip to white.
    assert light =~ "--color-error-content: #ffffff"
    assert light =~ "--color-success-content: #ffffff"
    assert light =~ "--color-warning-content: #ffffff"
    assert light =~ "--color-neutral-content: #ffffff"
  end

  # The presence roster needs eight distinguishable hues and borrows daisyUI's
  # eight semantic tokens. `neutral` ships as oklch(14% ...) in BOTH of daisyUI's
  # theme blocks, so an avatar filled with it is black-on-black in dark mode.
  # Both themes therefore override it with a real hue.
  test "neutral is a real hue in dark, not daisyUI's near-black", %{css: css} do
    dark = theme_rule(css, @dark_marker)

    assert dark =~ "--color-neutral: #e879f9"
    assert dark =~ "--color-neutral-content: #0c0c0c"

    refute dark =~ "--color-neutral: oklch(14%"
  end

  test "the light selector is declared after the OS-dark media query, so an explicit light toggle beats OS dark preference",
       %{css: css} do
    media_index = require_index(css, @media_marker, "the OS-dark media query")
    light_index = require_index(css, @light_marker, "the light theme selector")

    # daisyUI's `prefersdark` theme emits its `@media (prefers-color-scheme:
    # dark)` block before that theme's own `[data-theme=...]` selector. A
    # media-wrapped `:root` rule and a `[data-theme="light"]` selector have
    # equal specificity, so whichever is declared later in the stylesheet
    # wins ties. If the light theme's rule were emitted before the media
    # query, `data-theme="light"` on an OS-dark machine would be silently
    # overridden back to dark. This asserts the fix: light must come after.
    assert light_index > media_index,
           "expected [data-theme=\"light\"] (offset #{light_index}) to come after " <>
             "the prefers-color-scheme: dark media query (offset #{media_index}), " <>
             "otherwise OS-dark preference silently overrides an explicit light toggle"
  end

  # Extracts the full CSS rule (selector list through the matching closing
  # brace) that contains `marker`, e.g. the whole `[data-theme="dark"] {...}`
  # rule. Scoping assertions to this text, instead of the whole file, is what
  # lets these tests tell the two themes' tokens apart.
  defp theme_rule(css, marker) do
    start_index = require_index(css, marker, marker)
    from_marker = binary_part(css, start_index, byte_size(css) - start_index)
    open_brace = require_index(from_marker, "{", "an opening brace after #{marker}")
    close_offset = matching_close(from_marker, open_brace + 1, 1)
    binary_part(from_marker, 0, close_offset + 1)
  end

  defp matching_close(str, index, depth) do
    case :binary.at(str, index) do
      ?{ -> matching_close(str, index + 1, depth + 1)
      ?} when depth == 1 -> index
      ?} -> matching_close(str, index + 1, depth - 1)
      _ -> matching_close(str, index + 1, depth)
    end
  end

  defp require_index(haystack, needle, description) do
    case :binary.match(haystack, needle) do
      {index, _length} ->
        index

      :nomatch ->
        flunk("expected to find #{description} (#{inspect(needle)}) in the compiled CSS")
    end
  end
end
