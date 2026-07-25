defmodule DstarDemoWeb.ThemeTest do
  # Reads the compiled stylesheet, so it must not run concurrently with a build.
  use ExUnit.Case, async: false

  @css "priv/static/assets/css/app.css"

  setup_all do
    {_, 0} = System.cmd("mix", ["tailwind", "dstar_demo"], cd: File.cwd!(), stderr_to_stdout: true)
    {:ok, css: File.read!(@css)}
  end

  test "the light theme is the default and carries the spec's tokens", %{css: css} do
    assert css =~ "--color-base-100: #ffffff"
    assert css =~ "--color-base-200: #fafafa"
    assert css =~ "--color-base-300: #e2e2e2"
    assert css =~ "--color-base-content: #111111"
    assert css =~ ~s([data-theme="light"])
  end

  test "the dark theme is declared with the spec's tokens", %{css: css} do
    assert css =~ "--color-base-100: #0c0c0c"
    assert css =~ "--color-base-200: #141414"
    assert css =~ "--color-base-300: #262626"
    assert css =~ "--color-base-content: #f2f2f2"
    assert css =~ ~s([data-theme="dark"])
  end

  test "the accent is the same orange in both modes", %{css: css} do
    assert css =~ "--color-primary: #e8590c"
  end
end
