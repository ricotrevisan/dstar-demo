# Documentation Site Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `dstar_demo` from a dark app-like demo gallery into a light, minimal documentation site where every demo page shows the live demo, explains the Dstar wiring, and compares it to how Phoenix LiveView would solve the same problem.

**Architecture:** `demo_shell` is rewritten in place into a persistent-sidebar documentation layout with three slots (`:demo`, `:how_it_works`, `:comparison`); all eight call sites change in one commit because the signature change breaks them together. Colour comes from a custom DaisyUI theme declared in `app.css` (light default, dark via `prefersdark` and the existing theme toggle). Code samples are highlighted server-side by Makeup through a small `CodeHighlight` wrapper, so the browser receives no highlighter. Every code sample the site shows — both the How-it-works wiring excerpts and the Dstar side of each LiveView comparison — is data in a `Snippets` module, and a drift test asserts each one still appears in the page module it quotes.

**Tech Stack:** Elixir, Phoenix 1.8, Dstar 0.1.5, Datastar, Tailwind 4.1, DaisyUI 5 (vendored), Makeup, ExUnit + LazyHTML.

## Global Constraints

- **Palette (exact hex, from the spec):** `base-100` `#ffffff`/`#0c0c0c`, `base-200` `#fafafa`/`#141414`, `base-300` `#e2e2e2`/`#262626`, `base-content` `#111111`/`#f2f2f2`, `primary` `#e8590c` in both modes.
- **Accent accessibility:** `#e8590c` on white is **3.58:1** — AA for large text (≥3:1) and UI components, **fails** the 4.5:1 for normal body text. In light mode the orange is for rules, active states, borders, the logo and large text **only** — never small body copy, never inline links inside a paragraph. If orange is later wanted in running prose, darken to `#c2410c` (~5.9:1).
- **Text measure:** prose capped at `68ch`; demo and code panes span the full content column. Content column capped at **1100px**. Sidebar **240px**.
- **Typography:** system stacks only. Sans is Tailwind's default `font-sans` — **do not override it**. Mono is `ui-monospace` and friends. No `@font-face`, nothing added to `priv/static/fonts/`.
- **DaisyUI usage:** theme tokens plus `btn`, `badge`, `kbd`, `tabs` only. Everything structural — sidebar, panels, code blocks, the comparison grid — stays hand-written Tailwind utilities. Note that DaisyUI component CSS is **usage-gated**: Tailwind 4 prunes any component class no scanned source references, so these four are only available if something actually uses them. Never assert their presence in a test.
- **No JavaScript is added.** The sub-`lg` nav is a `<details>` disclosure, not a drawer. Highlighting is server-side.
- **`eyebrow` is dropped** from `demo_shell`. The `:aside` slot is dropped but its content is not: each page's existing `demo_facts` bullets become a `key_points` list leading **How it works**, same words.
- **Fairness rules for every comparison (requirements, not guidance):** (1) **Like for like** — both sides solve the same problem with the same features; no dropping the debounce on one side. (2) **No strawmen** — idiomatic LiveView as a competent LiveView developer would write it. (3) **Concede where LiveView wins** — the `<:note>` must say what LiveView does better wherever that is true.
- **The Dstar side of every comparison is real code**, asserted against the page module by `snippet_drift_test.exs`. The LiveView side is explicitly labelled illustrative; nothing compiles or runs it.
- **Review gate:** all eight comparisons are reviewed by Rico before they ship.
- **Running tests requires Postgres:** `mix test` is aliased to `ecto.create --quiet`, `ecto.migrate --quiet`, `test`. Run `mix db.up` first if the database is not running.

## Corrections to the spec, already verified

These were checked against the code and the published packages while writing this plan. Follow the plan, not the spec, where they differ.

1. **The custom theme goes in `assets/css/app.css`, not `assets/vendor/daisyui-theme.js`.** That vendored file is DaisyUI's theme *plugin* — a function that reads options. A theme is declared by invoking it: `@plugin "../vendor/daisyui-theme" { name: "light"; … }`. Do not edit the vendored bundle.
2. **Name the two themes `light` and `dark`.** `assets/js/app.js:29-46` already implements the toggle by setting `data-theme="light"|"dark"` on `<html>`, and DaisyUI's theme plugin keys its selector off `[data-theme="<name>"]`. Any other names leave the existing toggle dead. A bonus: the plugin merges DaisyUI's built-in `light`/`dark` token sets under those names (`assets/vendor/daisyui-theme.js:74-81`), so the five overridden tokens sit on top of sane defaults for `success`/`warning`/`error`.
3. **Makeup needs four dependencies, not one.** `makeup_eex`'s HEEx lexer raises at runtime without an HTML lexer registered. The required set is `makeup ~> 1.2`, `makeup_elixir ~> 1.0`, `makeup_eex ~> 2.0`, `makeup_html ~> 0.2`. Note the version: `makeup_eex`'s own error message suggests `makeup_html ~> 1.0`, which does not exist — the latest release is `0.2.0`.
4. **`code_block` takes the code as an attr, not a slot.** The spec sketches `<.code_block language="elixir">…</.code_block>`, but a slot's content arrives as rendered HTML, which cannot be handed to a lexer as source text — and the verbatim-drift test needs the exact string. Use `<.code_block language="elixir" code={…} />`.
5. **The suite has 43 tests, not 38.** The spec's Testing section says "of the 38 existing tests"; the actual count at `15dffbb` is 43. Use 43 as the baseline when checking that nothing regressed.
6. **`pages_test.exs` needs no repair.** The spec's Testing and Risks sections expect churn in the page-render assertions. There is none to do: every marker in `demo_pages/0` (`pages_test.exs:346-356`) and both bare copy assertions (lines 10 and 29) match page **titles**, which this restyle keeps verbatim. No test anywhere asserts an `eyebrow` string or a `demo_facts` bullet. The at-risk set is empty, so that risk is closed rather than mitigated. This plan *adds* assertions; it repairs none.
7. **Patch Lab has five facts, not four.** The spec says every demo has four `demo_facts` bullets. Seven do; `patch_lab_page.ex:24-30` has five. Move whatever each page has.
8. **`demo_pages/0` covers seven pages, not eight.** Presence is exercised by `test/dstar_demo_web/presence_page_test.exs` instead. Leave that split alone.

## File Structure

**Modify:**
- `mix.exs` — add the four Makeup dependencies.
- `assets/css/app.css` — enable the DaisyUI plugin, declare the `light` and `dark` themes, drop the hand-rolled `:root` dark default, add the Makeup token CSS.
- `lib/dstar_demo_web/components/demo_components.ex` — rewrite `demo_shell`; add `key_points`, `code_block`, `compare`; delete `demo_facts`; restyle `pill`, `metric_tile`, `action_button` onto theme tokens.
- All eight page modules in `lib/dstar_demo_web/pages/` — new shell call sites, then a `<:comparison>` each.
- `lib/dstar_demo_web/pages/home_page.ex` — restyle `demo_tile` and the hero; does not use `demo_shell`.
- `test/dstar_demo_web/pages_test.exs` — add sidebar, jump-link and structure assertions.

**Create:**
- `lib/dstar_demo_web/code_highlight.ex` — `DstarDemoWeb.CodeHighlight`: Makeup wrapper plus `dedent/1`. Not a component module; it returns safe HTML for one to embed.
- `lib/dstar_demo_web/snippets.ex` — `DstarDemoWeb.Snippets`: every code sample the site displays, as data (`source`, `wiring`, and per comparison `liveview` and `note`). One place for the review gate, and what the drift test iterates.
- `test/dstar_demo_web/code_highlight_test.exs` — unit tests for dedent, both lexers, escaping.
- `test/dstar_demo_web/snippet_drift_test.exs` — the snippet-drift check.
- `test/dstar_demo_web/theme_test.exs` — asserts the compiled stylesheet carries the palette.

**Responsibility split:** highlighting mechanics live in `CodeHighlight` so `demo_components.ex` stays presentational; snippet and comparison *content* lives in `Snippets` so the eight review-gated blobs of prose and code are not scattered across eight page modules, and so one test can iterate all of them.

**Naming note:** the spec calls this module `Comparisons` and the test `comparison_test.exs`. Both are widened here: the same mechanism protects the How-it-works wiring excerpts, which have exactly the same drift problem, so one module and one test cover both rather than standing up a near-duplicate pair.

---

### Task 1: Light DaisyUI theme

Flips the site from dark to light and gives every later task its colour tokens. No component touches this task — only the stylesheet.

**Files:**
- Modify: `assets/css/app.css:1-38` (the whole file)
- Test: `test/dstar_demo_web/theme_test.exs` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: DaisyUI theme tokens usable as Tailwind utilities everywhere — `bg-base-100`, `bg-base-200`, `border-base-300`, `text-base-content`, `text-base-content/70`, `bg-primary`, `text-primary`, `text-primary-content` — plus DaisyUI's `btn`, `badge`, `kbd`, `tabs` component classes.

- [ ] **Step 1: Write the failing test**

CSS has no behaviour to unit-test, so the test asserts the build product: that the compiled stylesheet actually carries the spec's tokens in both modes. This catches a mis-declared plugin block, which is the realistic failure.

Create `test/dstar_demo_web/theme_test.exs`:

```elixir
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
```

**Do not add an assertion that DaisyUI component classes such as `.btn` or `.badge` are present.** DaisyUI 5 on Tailwind 4 emits component CSS only when the class is detected in a scanned source. Nothing in this repo uses `badge`, `kbd` or `tabs`, so they are pruned; `.btn` compiles today only incidentally, because the default Phoenix scaffold layout at `lib/dstar_demo_web/components/layouts.ex:48` carries `class="btn btn-ghost"` — a file these Dstar pages do not even render. An assertion on either is asserting a falsehood or a coincidence.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/dstar_demo_web/theme_test.exs`
Expected: FAIL — the token assertions fail because no theme is declared and the DaisyUI plugin is not enabled (only heroicons is plugged in).

- [ ] **Step 3: Rewrite `assets/css/app.css`**

Replace the entire file with:

```css
/* See the Tailwind configuration guide for advanced usage
   https://tailwindcss.com/docs/configuration */

@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/dstar_demo_web";

/* A Tailwind plugin that makes "hero-#{ICON}" classes available.
   The heroicons installation itself is managed by your mix.exs */
@plugin "../vendor/heroicons";

/* DaisyUI supplies the theme tokens plus btn, badge, kbd and tabs. Everything
   structural on these pages is hand-written Tailwind, so DaisyUI's rounded,
   shadowed product-app look never gets a chance to override the design. */
@plugin "../vendor/daisyui" {
  themes: false;
}

/* Named "light" and "dark" on purpose: assets/js/app.js sets
   data-theme="light"|"dark", and the theme plugin keys its selector off that
   attribute. These names also inherit DaisyUI's built-in token sets, so only
   the five tokens the design specifies need overriding. */
@plugin "../vendor/daisyui-theme" {
  name: "light";
  default: true;
  color-scheme: "light";
  --color-base-100: #ffffff;
  --color-base-200: #fafafa;
  --color-base-300: #e2e2e2;
  --color-base-content: #111111;
  --color-primary: #e8590c;
  --color-primary-content: #ffffff;
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.25rem;
  --border: 1px;
  --depth: 0;
  --noise: 0;
}

@plugin "../vendor/daisyui-theme" {
  name: "dark";
  prefersdark: true;
  color-scheme: "dark";
  --color-base-100: #0c0c0c;
  --color-base-200: #141414;
  --color-base-300: #262626;
  --color-base-content: #f2f2f2;
  --color-primary: #e8590c;
  --color-primary-content: #0c0c0c;
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.25rem;
  --border: 1px;
  --depth: 0;
  --noise: 0;
}

/* Add variants based on LiveView classes */
@custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
@custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
@custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

/* Use the data attribute for dark mode. Note this only matches an explicit
   toggle, not OS-level dark preference — prefer base-* tokens, which flip in
   both cases, over dark: utilities. */
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

/* Make LiveView wrapper divs transparent for layout */
[data-phx-session], [data-phx-teleported-src] { display: contents }

/* This file is for your main application CSS */

html {
  scrollbar-gutter: stable;
  background: var(--color-base-100);
}
```

Note what left: the hand-rolled `:root { color-scheme: dark }` and `[data-theme="light"]` blocks are gone — DaisyUI's theme plugin emits `color-scheme` itself from each theme's declaration.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/dstar_demo_web/theme_test.exs`
Expected: PASS, 3 tests.

- [ ] **Step 5: Confirm nothing else broke**

Run: `mix test`
Expected: PASS, 46 tests (43 pre-existing + 3 new). The existing suite asserts markup and behaviour, not colour, so nothing in it should move. (Needs Postgres — `mix db.up` first if it is down. Note this repo runs OrbStack, not Docker Desktop; `pg_isready -h localhost -p 5433 -U postgres` is the reliable readiness check, because OrbStack binds the host port proxy before Postgres is serving.)

- [ ] **Step 6: Commit**

```bash
git add assets/css/app.css test/dstar_demo_web/theme_test.exs
git commit -m "Add a light DaisyUI theme and flip the default away from dark"
```

---

### Task 2: Server-side code highlighting

Gives every later task the ability to render a snippet. Nothing renders one yet — this task is the mechanism and its tests.

**Files:**
- Modify: `mix.exs:26-46` (the `deps/0` list)
- Create: `lib/dstar_demo_web/code_highlight.ex`
- Modify: `assets/css/app.css` (append the Makeup token block)
- Modify: `lib/dstar_demo_web/components/demo_components.ex` (add `code_block`)
- Test: `test/dstar_demo_web/code_highlight_test.exs` (create)

**Interfaces:**
- Consumes: theme tokens from Task 1.
- Produces:
  - `DstarDemoWeb.CodeHighlight.highlight(code :: String.t(), language :: String.t()) :: {:safe, iodata()}` — `language` is `"elixir"` or `"heex"`; raises `KeyError` on anything else.
  - `DstarDemoWeb.CodeHighlight.dedent(code :: String.t()) :: String.t()` — strips the common leading indentation from every non-blank line and trims surrounding blank lines.
  - `DstarDemoWeb.DemoComponents.code_block/1` — attrs `code` (string, required), `language` (string, default `"elixir"`, one of `elixir`/`heex`), `label` (string, default `nil`).

- [ ] **Step 1: Write the failing test**

Create `test/dstar_demo_web/code_highlight_test.exs`:

```elixir
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
      {:safe, html} = CodeHighlight.highlight(~s(<.demo_shell>\n  <:demo>x</:demo>\n</.demo_shell>), "heex")
      html = IO.iodata_to_binary(html)
      assert html =~ ~s(<span class="nf">.demo_shell</span>)
      assert html =~ ~s(<span class="ss">:demo</span>)
    end

    test "escapes the source so markup in a snippet cannot break out" do
      {:safe, html} = CodeHighlight.highlight(~s(<script>alert(1)</script>), "heex")
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/dstar_demo_web/code_highlight_test.exs`
Expected: FAIL — `DstarDemoWeb.CodeHighlight` is undefined.

- [ ] **Step 3: Add the dependencies**

In `mix.exs`, inside `deps/0`, after the `{:tidewave, "~> 0.6", only: [:dev]}` entry:

```elixir
      {:tidewave, "~> 0.6", only: [:dev]},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_eex, "~> 2.0"},
      # makeup_eex's HEEx lexer refuses to run without an HTML lexer
      # registered. Its error message suggests "~> 1.0", which does not exist.
      {:makeup_html, "~> 0.2"}
```

Run: `mix deps.get`

- [ ] **Step 4: Write the highlighter**

Create `lib/dstar_demo_web/code_highlight.ex`:

```elixir
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
    |> Makeup.highlight_inner_html(lexer: lexer)
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
    lines =
      code
      |> String.trim("\n")
      |> String.trim_trailing()
      |> String.split("\n")

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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/dstar_demo_web/code_highlight_test.exs`
Expected: PASS, 10 tests.

- [ ] **Step 6: Add the Makeup token CSS**

Makeup's own `Makeup.stylesheet/1` emits fixed hex colours for a single mode, which cannot follow the theme. Hand-write the token rules against theme tokens instead. Append to `assets/css/app.css`:

```css
/* Makeup token colours, written against theme tokens so they follow
   light/dark. Deliberately monochrome: the accent fails the 4.5:1 floor for
   small text, and code is small text, so weight, opacity and italics carry the
   distinction instead of hue. Only the classes our two lexers emit are styled. */
.hl code {
  color: var(--color-base-content);
}
.hl .c, .hl .c1, .hl .cm {          /* comments */
  color: color-mix(in oklab, var(--color-base-content) 45%, transparent);
  font-style: italic;
}
.hl .k, .hl .kd, .hl .kn {          /* keywords: do, end, def, defmodule */
  font-weight: 600;
}
.hl .nc, .hl .nf, .hl .nt {         /* module, function and tag names */
  font-weight: 600;
}
.hl .na {                            /* attribute names */
  color: color-mix(in oklab, var(--color-base-content) 65%, transparent);
}
.hl .s, .hl .s1, .hl .s2, .hl .ss { /* strings and atoms */
  color: color-mix(in oklab, var(--color-base-content) 78%, transparent);
}
.hl .o, .hl .p {                    /* operators and punctuation */
  color: color-mix(in oklab, var(--color-base-content) 50%, transparent);
}
```

No hue appears in a code block at all — numbers and plain identifiers inherit `base-content` from `.hl code` and are left alone. Every colour here is `base-content` at some opacity, so both themes are covered by the same five rules and nothing in a code block can fail contrast that the body text does not also fail.

- [ ] **Step 7: Add the `code_block` component**

In `lib/dstar_demo_web/components/demo_components.ex`, add the import at the top of the module, after `import DstarDemoWeb.CoreComponents`:

```elixir
  import DstarDemoWeb.CodeHighlight, only: [highlight: 2]
```

Then add the component at the end of the module, before the final `end`:

```elixir
  attr :code, :string, required: true
  attr :language, :string, default: "elixir", values: ~w(elixir heex)
  attr :label, :string, default: nil, doc: "usually the source path the snippet came from"

  def code_block(assigns) do
    ~H"""
    <figure class="hl min-w-0">
      <figcaption
        :if={@label}
        class="border border-base-300 border-b-0 bg-base-200 px-4 py-2 font-mono text-xs text-base-content/55"
      >
        {@label}
      </figcaption>
      <pre class="overflow-x-auto border border-base-300 bg-base-200 p-4 font-mono text-[13px] leading-6"><code>{highlight(@code, @language)}</code></pre>
    </figure>
    """
  end
```

- [ ] **Step 8: Run the full suite**

Run: `mix test`
Expected: PASS. Nothing renders `code_block` yet, so no page output changes.

- [ ] **Step 9: Commit**

```bash
git add mix.exs mix.lock lib/dstar_demo_web/code_highlight.ex \
  lib/dstar_demo_web/components/demo_components.ex assets/css/app.css \
  test/dstar_demo_web/code_highlight_test.exs
git commit -m "Highlight code samples server-side with Makeup"
```

---

### Task 3: Rewrite `demo_shell` and convert all eight pages

The signature change breaks all eight call sites at once, so shell, shared components and every page land in **one commit**. The steps are small; the commit is not.

**Files:**
- Modify: `lib/dstar_demo_web/components/demo_components.ex` (rewrite `demo_shell`, add `key_points`, delete `demo_facts`, restyle `pill`/`metric_tile`/`action_button`)
- Create: `lib/dstar_demo_web/snippets.ex`
- Modify: all eight of `lib/dstar_demo_web/pages/{commands,active_search,streaming_dashboard,patch_lab,server_components,signals,scripts,presence}_page.ex`
- Test: `test/dstar_demo_web/pages_test.exs` (add assertions), `test/dstar_demo_web/snippet_drift_test.exs` (create)

**Interfaces:**
- Consumes: theme tokens (Task 1); `DstarDemoWeb.DemoComponents.code_block/1` (Task 2).
- Produces:
  - `demo_shell/1` — attrs `active`, `title`, `summary` (all required strings), `signals` (map, default `nil`), `rest` (global). Slots `:demo` (required), `:how_it_works` (required), `:comparison` (optional). `eyebrow` and `:aside` no longer exist.
  - `key_points/1` — attr `items` (list, required).
  - `DstarDemoWeb.Snippets.all/0 :: %{atom() => map()}` and `DstarDemoWeb.Snippets.fetch!(atom()) :: map()`. Each entry has keys `:source` (string path), `:wiring` (string, the How-it-works snippet), `:wiring_language` (`"elixir"` or `"heex"`), and — filled in by Tasks 4-11 — `:liveview` and `:note`, both `nil` until then. There is deliberately no separate `dstar` field: the comparison's Dstar pane renders `wiring`, so the code shown beside LiveView is the same excerpt the drift test already guards.
  - Section anchor ids `#demo`, `#how-it-works`, `#comparison`. Verified not to collide with any existing id in `lib/`.

- [ ] **Step 1: Write the failing tests**

Append to `test/dstar_demo_web/pages_test.exs`, before the private helpers at the bottom:

```elixir
  test "demo pages render the documentation shell", %{conn: conn} do
    for {path, _marker} <- demo_pages() do
      response = conn |> recycle() |> get(path) |> html_response(200)

      # Persistent sidebar, listing every demo, on every page.
      assert response =~ ~s[aria-label="Demos"]
      assert response =~ ~s[href="/commands"]
      assert response =~ ~s[href="/presence"]

      # The three documentation sections, and the jump links to them.
      assert response =~ ~s[id="demo"]
      assert response =~ ~s[id="how-it-works"]
      assert response =~ ~s[href="#demo"]
      assert response =~ ~s[href="#how-it-works"]
      assert response =~ "How it works"

      # Sub-lg nav is a disclosure, not a drawer — no JavaScript involved.
      assert response =~ "<details"
    end
  end

  test "jump links are derived from the slots a page actually passes", %{conn: conn} do
    # No page has a :comparison slot yet, so no page advertises one.
    for {path, _marker} <- demo_pages() do
      response = conn |> recycle() |> get(path) |> html_response(200)

      refute response =~ ~s[href="#comparison"]
      refute response =~ ~s[id="comparison"]
    end
  end

  test "the dropped eyebrow no longer renders anywhere", %{conn: conn} do
    for {path, eyebrow} <- [
          {~p"/commands", "Form Data"},
          {~p"/search", "Signal search"},
          {~p"/streaming", "SSE stream"},
          {~p"/patch-lab", "DOM patch modes"},
          {~p"/components", "Dstar.Component"},
          {~p"/signals", "Inspector"},
          {~p"/scripts", "Client actions"}
        ] do
      response = conn |> recycle() |> get(path) |> html_response(200)
      refute response =~ eyebrow
    end
  end

  test "each page's facts survive as key points inside How it works", %{conn: conn} do
    for {path, fact} <- [
          {~p"/commands", "novalidate keeps the browser from intercepting the demo."},
          {~p"/search", "data-bind keeps the query and segment on the client."},
          {~p"/streaming", "connect/1 posts to the page path and opens the stream."},
          {~p"/patch-lab", "outer replaces the target node."},
          {~p"/components", "ComponentStage is a Dstar.Component: UI plus handle_event/3."},
          {~p"/signals", "handle_event/3 receives the request signals already read."},
          {~p"/scripts", "execute_script/3 appends a script tag through a patch."}
        ] do
      response = conn |> recycle() |> get(path) |> html_response(200)
      assert response =~ fact
    end
  end

  test "each page renders a highlighted wiring snippet", %{conn: conn} do
    for {path, _marker} <- demo_pages() do
      response = conn |> recycle() |> get(path) |> html_response(200)
      # Makeup emits token spans; the .hl wrapper carries our token colours.
      assert response =~ ~s[class="hl min-w-0"]
      assert response =~ ~s[<span class="]
    end
  end
```

Create `test/dstar_demo_web/snippet_drift_test.exs`:

```elixir
defmodule DstarDemoWeb.SnippetDriftTest do
  @moduledoc """
  Snippets drifting from the code they document is the standard failure mode of
  a documentation site. Every snippet this site shows as real Dstar code is an
  excerpt from a page module, and this test proves it still is.

  Comparison matching ignores each line's leading whitespace: moving markup
  between slots re-indents it, which is not drift. Everything that matters —
  renamed functions, changed arguments, deleted calls — still fails.
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

      assert String.contains?(source, flush(@entry.wiring)), """
      The wiring snippet for #{@demo} no longer appears in #{@entry.source}.

      Either the page changed and the snippet in DstarDemoWeb.Snippets must be
      updated to match, or the snippet was mistyped.

      Snippet:
      #{@entry.wiring}
      """
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/dstar_demo_web/pages_test.exs test/dstar_demo_web/snippet_drift_test.exs`
Expected: FAIL — `DstarDemoWeb.Snippets` is undefined, and the shell assertions fail because the current shell renders a top nav and an `:aside`, not a sidebar and sections.

- [ ] **Step 3: Rewrite the shell and shared components**

Replace the body of `lib/dstar_demo_web/components/demo_components.ex` from the `@demos` attribute through the end of `demo_facts/1` with the following, leaving the module header and imports in place (plus the Task 2 import of `highlight/2`):

```elixir
  @demos [
    {"Form Validation", "/commands", "hero-clipboard-document-check-micro"},
    {"Active Search", "/search", "hero-magnifying-glass-micro"},
    {"Streaming Dashboard", "/streaming", "hero-signal-micro"},
    {"Patch Lab", "/patch-lab", "hero-squares-plus-micro"},
    {"Components", "/components", "hero-cube-transparent-micro"},
    {"Signals", "/signals", "hero-adjustments-horizontal-micro"},
    {"Scripts", "/scripts", "hero-code-bracket-square-micro"},
    {"Presence", "/presence", "hero-user-group-micro"}
  ]

  attr :active, :string, required: true
  attr :title, :string, required: true
  attr :summary, :string, required: true
  attr :signals, :map, default: nil, doc: "initial Datastar signals, rendered as data-signals"
  attr :rest, :global

  slot :demo, required: true, doc: "the live, interactive thing"
  slot :how_it_works, required: true, doc: "key points, prose at reading measure, and Dstar code"
  slot :comparison, doc: "optional side-by-side against LiveView"

  def demo_shell(assigns) do
    assigns =
      assigns
      |> assign(:demos, @demos)
      |> assign(:jump_links, jump_links(assigns))

    ~H"""
    <!-- data-signals and @rest sit on the outermost element, not on #demo.
         Datastar scopes signals to a subtree, and the old shell declared them on
         a section that wrapped both the aside and the content. Keeping them at
         the top preserves that scope exactly, so nothing in :how_it_works or
         :comparison can fall outside it — and the presence page's pagehide
         beacon still finds presenceInstance. -->
    <div
      class="min-h-screen bg-base-100 text-base-content"
      data-signals={@signals && Jason.encode!(@signals)}
      {@rest}
    >
      <div class="mx-auto flex w-full max-w-[1400px] flex-col lg:flex-row">
        <div class="border-b border-base-300 lg:w-60 lg:shrink-0 lg:border-b-0 lg:border-r">
          <div class="lg:sticky lg:top-0 lg:flex lg:h-screen lg:flex-col lg:overflow-y-auto">
            <a href={~p"/"} class="flex items-center gap-2.5 px-5 py-4">
              <span class="grid size-7 shrink-0 place-items-center bg-primary text-primary-content">
                <.icon name="hero-bolt-micro" class="size-4" />
              </span>
              <span class="text-sm font-semibold tracking-tight">Dstar Demo</span>
            </a>

            <details class="border-t border-base-300 lg:hidden">
              <summary class="cursor-pointer list-none px-5 py-3 text-sm text-base-content/70">
                Demos — {@active}
              </summary>
              <.demo_nav demos={@demos} active={@active} />
            </details>

            <div class="hidden lg:block">
              <.demo_nav demos={@demos} active={@active} />
            </div>
          </div>
        </div>

        <main class="min-w-0 flex-1">
          <article class="mx-auto w-full max-w-[1100px] px-5 py-10 sm:px-8">
            <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">{@title}</h1>
            <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">{@summary}</p>

            <nav
              class="mt-6 flex flex-wrap gap-x-5 gap-y-1 border-y border-base-300 py-2.5 text-sm"
              aria-label="On this page"
            >
              <a
                :for={{anchor, label} <- @jump_links}
                href={"##{anchor}"}
                class="text-base-content/60 transition hover:text-primary"
              >
                {label}
              </a>
            </nav>

            <section id="demo" class="mt-10 scroll-mt-6">
              <h2 class="sr-only">Demo</h2>
              {render_slot(@demo)}
            </section>

            <section id="how-it-works" class="mt-14 scroll-mt-6">
              <h2 class="border-b border-base-300 pb-2 text-xl font-semibold tracking-tight">
                How it works
              </h2>
              {render_slot(@how_it_works)}
            </section>

            <section :if={@comparison != []} id="comparison" class="mt-14 scroll-mt-6">
              <h2 class="border-b border-base-300 pb-2 text-xl font-semibold tracking-tight">
                If this were LiveView
              </h2>
              {render_slot(@comparison)}
            </section>
          </article>
        </main>
      </div>
    </div>
    """
  end

  # Derived from which slots the caller populated, so a page without a
  # :comparison renders two links rather than three. No list to keep in sync.
  defp jump_links(assigns) do
    base = [{"demo", "Demo"}, {"how-it-works", "How it works"}]

    if assigns.comparison == [],
      do: base,
      else: base ++ [{"comparison", "LiveView comparison"}]
  end

  attr :demos, :list, required: true
  attr :active, :string, required: true

  defp demo_nav(assigns) do
    ~H"""
    <nav class="flex flex-col pb-5 text-sm" aria-label="Demos">
      <a
        :for={{label, href, icon} <- @demos}
        href={href}
        aria-current={@active == label && "page"}
        class={[
          "flex items-center gap-2.5 border-l-2 px-5 py-2 transition",
          @active == label && "border-primary font-medium text-base-content",
          @active != label &&
            "border-transparent text-base-content/60 hover:border-base-300 hover:text-base-content"
        ]}
      >
        <.icon name={icon} class="size-4 shrink-0 opacity-70" />
        <span>{label}</span>
      </a>
    </nav>
    """
  end

  attr :items, :list, required: true

  @doc """
  The sharpest writing on each page. These were the `:aside` facts; they now
  lead the explanation instead of sitting in a column beside it.
  """
  def key_points(assigns) do
    ~H"""
    <ul class="mt-5 max-w-[68ch] space-y-2">
      <li
        :for={item <- @items}
        class="flex gap-2.5 text-sm leading-6 text-base-content/80"
      >
        <span class="mt-2 size-1.5 shrink-0 rounded-full bg-primary" aria-hidden="true"></span>
        <span>{item}</span>
      </li>
    </ul>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  @doc "A paragraph held at reading measure, for use inside :how_it_works."
  def prose(assigns) do
    ~H"""
    <p class={["mt-6 max-w-[68ch] text-base leading-7 text-base-content/80", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end
```

Then restyle the three remaining components onto theme tokens. Replace `pill/1`, `metric_tile/1` and `action_button/1` with:

```elixir
  attr :label, :string, required: true
  attr :tone, :string, default: "neutral"
  attr :rest, :global

  def pill(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center px-2 py-0.5 font-mono text-xs",
        @tone == "good" && "bg-success/15 text-success-content",
        @tone == "warn" && "bg-warning/15 text-warning-content",
        @tone == "bad" && "bg-error/15 text-error-content",
        @tone == "info" && "bg-info/15 text-info-content",
        @tone == "neutral" && "bg-base-300 text-base-content/70"
      ]}
      {@rest}
    >
      {@label}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true
  attr :tone, :string, default: "neutral"

  def metric_tile(assigns) do
    ~H"""
    <div id={@id} class="border border-base-300 bg-base-200 px-4 py-3">
      <p class="font-mono text-xs tracking-wide text-base-content/55 uppercase">{@title}</p>
      <p class={[
        "mt-2 text-2xl font-semibold tabular-nums",
        @tone == "neutral" && "text-base-content",
        @tone != "neutral" && "text-primary"
      ]}>
        {@value}
      </p>
      <p class="mt-1 text-sm text-base-content/60">{@detail}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :click, :string, required: true
  attr :icon, :string, default: "hero-arrow-path-micro"
  attr :active, :boolean, default: false
  attr :rest, :global

  def action_button(assigns) do
    ~H"""
    <button
      id={@id}
      data-on:click={@click}
      class={[
        "inline-flex items-center gap-2 border px-3 py-2 text-sm font-medium transition",
        "focus:outline-none focus:ring-2 focus:ring-primary/40",
        @active && "border-primary bg-primary text-primary-content",
        !@active && "border-base-300 text-base-content/80 hover:border-base-content/40 hover:bg-base-200"
      ]}
      {@rest}
    >
      <.icon name={@icon} class="size-4" />
      <span>{@label}</span>
    </button>
    """
  end
```

`demo_facts/1` is deleted. `metric_tile`'s tone now only distinguishes neutral from accented — the old four-colour scheme was app chrome, not documentation.

- [ ] **Step 4: Create the snippets module**

Create `lib/dstar_demo_web/snippets.ex`. Every `wiring` value below is a real excerpt from the file named in `source`; `snippet_drift_test.exs` proves it. The `liveview` and `note` fields stay `nil` until Tasks 4-11.

```elixir
defmodule DstarDemoWeb.Snippets do
  @moduledoc """
  The code samples the documentation pages display, kept out of the page
  modules so one test can check every one of them against the source it
  quotes, and so the eight review-gated LiveView comparisons live in one file.

  `wiring` is the excerpt shown under **How it works**, and is also the Dstar
  side of the LiveView comparison — one verified excerpt, checked once.
  `liveview` and `note` are the other two parts of that comparison; a demo with
  no comparison yet leaves them `nil` and renders no `<:comparison>` slot.
  """

  @pages "lib/dstar_demo_web/pages"

  @snippets %{
    commands: %{
      source: "#{@pages}/commands_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "validate", params) do
        validation = validate(params)
        intent = if ready?(validation), do: "accepted", else: "rejected"
        submitted = submitted_fields(params)

        conn
        |> patch(&status_badge/1, intent: intent)
      """,
      liveview: nil,
      note: nil
    },
    active_search: %{
      source: "#{@pages}/active_search_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "search", signals) do
        query = String.trim(signals["query"] || "")
        segment = signals["segment"] || "all"
        results = search(query, segment)

        # The client owns query/segment — echoing them back would clobber
        # anything typed while this response was in flight.
        patch(conn, &result_panel/1,
          results: results,
          query: query,
          segment: segment,
          result_count: length(results)
        )
      end
      """,
      liveview: nil,
      note: nil
    },
    streaming_dashboard: %{
      source: "#{@pages}/streaming_dashboard_page.ex",
      wiring_language: "elixir",
      wiring: """
      def stream_key(_conn), do: {:dstar_demo, :streaming_dashboard}

      @impl Dstar.Page
      def handle_connect(conn, _params) do
        Process.send_after(self(), {:tick, 1}, @stream_delay)

        conn
        |> patch_signals(%{streamStatus: "live", progress: 0, tick: 0})
        |> patch(&stream_frame/1, [tick: 0, status: "live"], selector: "#stream-frame")
      end
      """,
      liveview: nil,
      note: nil
    },
    patch_lab: %{
      source: "#{@pages}/patch_lab_page.ex",
      wiring_language: "elixir",
      wiring: """
      "before" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :before
        )

      "after" ->
        patch(conn, &patch_badge/1, [mode: mode, count: count],
          selector: "#anchor-row",
          mode: :after
        )

      "remove" ->
        remove_elements(conn, "#removable-note")
      """,
      liveview: nil,
      note: nil
    },
    server_components: %{
      source: "#{@pages}/server_components_page.ex",
      wiring_language: "heex",
      wiring: """
      <.action_button
        id="component-profile"
        label="Profile"
        icon="hero-identification-micro"
        click={"$component_kind = 'profile'; \#{ComponentStage.event("profile")}"}
        active={@component_kind == "profile"}
        data-class={variant_classes("profile")}
      />
      """,
      liveview: nil,
      note: nil
    },
    signals: %{
      source: "#{@pages}/signals_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "patch", signals) do
        tick = next_tick(signals)
        state = client_state(signals, tick: tick, audit: "patch_signals tick \#{tick}")

        conn
        |> patch_signals(state)
        |> patch(&inspector/1, state)
      end
      """,
      liveview: nil,
      note: nil
    },
    scripts: %{
      source: "#{@pages}/scripts_page.ex",
      wiring_language: "elixir",
      wiring: """
      def handle_event(conn, "execute", signals) do
        runs = next_runs(signals)

        conn
        |> patch_signals(%{script_runs: runs, last_script_action: "execute_script"})
        |> execute_script(
          "document.documentElement.dataset.dstarScriptPulse = \#{Jason.encode!(Integer.to_string(runs))}",
          auto_remove: false,
          attributes: %{"data-demo-script" => "execute"}
        )
      end
      """,
      liveview: nil,
      note: nil
    },
    presence: %{
      source: "#{@pages}/presence_page.ex",
      wiring_language: "elixir",
      wiring: """
      Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
      remember_presence_instance(registry_tab, presence_instance)

      {:ok, _} =
        Presence.track(self(), @topic, tab_id, %{
          name: name,
          color: color,
          status: "active",
          presence_instance: presence_instance,
          last_seen: System.system_time(:second)
        })
      """,
      liveview: nil,
      note: nil
    }
  }

  @spec all() :: %{atom() => map()}
  def all, do: @snippets

  @spec fetch!(atom()) :: map()
  def fetch!(demo), do: Map.fetch!(@snippets, demo)
end
```

Note the escaped `\#{...}` in the `server_components`, `signals` and `scripts` entries: those snippets contain literal Elixir interpolation, which must not be interpolated by the heredoc holding them. `snippet_drift_test.exs` catches it if you miss one.

- [ ] **Step 5: Apply the token translation table to every page's demo markup**

The demo markup moving into `<:demo>` is currently styled for a dark app. Apply this mapping to every page module in Steps 6-13. It is exhaustive for the utilities these eight files use.

| from | to |
|---|---|
| `bg-zinc-950` | `bg-base-200` (inset panels) / drop it on page-level wrappers |
| `bg-zinc-900`, `bg-zinc-900/60`, `bg-zinc-900/80` | `bg-base-200` |
| `bg-zinc-800` | `bg-base-300` |
| `border-zinc-800`, `border-zinc-800/80`, `border-zinc-700` | `border-base-300` |
| `divide-zinc-800` | `divide-base-300` |
| `hover:border-zinc-500`, `hover:border-zinc-600` | `hover:border-base-content/40` |
| `hover:bg-zinc-900`, `hover:bg-zinc-800`, `hover:bg-zinc-900/80` | `hover:bg-base-200` |
| `text-zinc-50`, `text-zinc-100` | `text-base-content` |
| `text-zinc-200`, `text-zinc-300` | `text-base-content/80` |
| `text-zinc-400` | `text-base-content/70` |
| `text-zinc-500` | `text-base-content/55` |
| `text-zinc-600` | `text-base-content/45` |
| `bg-emerald-300 text-zinc-950`, `hover:bg-emerald-200` | `bg-primary text-primary-content`, `hover:bg-primary/90` |
| `text-emerald-300`, `text-emerald-100`, `text-emerald-200/80` | `text-primary` (large/UI only — never body copy) |
| `border-emerald-300/30`, `border-emerald-300` | `border-primary/40` |
| `bg-emerald-300/10`, `bg-emerald-300/15` | `bg-primary/10` |
| `focus:ring-emerald-300/60` | `focus:ring-primary/40` |
| `focus:border-emerald-300`, `focus:ring-emerald-300/20` | `focus:border-primary`, `focus:ring-primary/20` |
| `bg-sky-300/15 text-sky-200`, `border-sky-300/30 bg-sky-300/10 text-sky-100` | `bg-info/15 text-info-content`, `border-info/30 bg-info/10 text-info-content` |
| `bg-amber-300/15 text-amber-200`, `border-amber-300/30 bg-amber-300/10 text-amber-100` | `bg-warning/15 text-warning-content`, `border-warning/30 bg-warning/10 text-warning-content` |
| `bg-rose-400/15 text-rose-200`, `text-rose-300` | `bg-error/15 text-error-content`, `text-error` |
| `rounded-lg`, `rounded-md` on panels and code surfaces | drop — the design is hairlines, not cards |

Two rules that override the table: keep `rounded-full` where it marks a dot or avatar, and keep `rounded-md` on `<input>` and `<button>` so DaisyUI's `--radius-field` still reads. Nothing in the table touches `id` attributes, `data-*` attributes, or `.pill`/`.metric_tile`/`.action_button` call sites — those components were restyled in Step 3.

- [ ] **Step 6: Convert `active_search_page.ex` — the exemplar**

Replace the `~H` body's opening through the end of `</:aside>` and re-close the shell. The full converted call site:

```elixir
  @impl Dstar.Page
  def render(assigns) do
    assigns = assign(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:active_search))

    ~H"""
    <.demo_shell
      active="Active Search"
      title="Active search"
      summary="Typing changes Datastar signals, the server filters local data, and only the result panel is patched back."
      signals={%{query: @query, segment: @segment}}
    >
      <:demo>
        <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_300px]">
          <!-- the existing demo markup, with the token table applied -->
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "data-bind keeps the query and segment on the client.",
          "Typing posts a page event with the latest signals.",
          "Only #search-results is patched, not the input chrome.",
          "Empty and no-results states are server-rendered."
        ]} />

        <.prose>
          <code class="font-mono text-sm">data-bind:query</code> keeps the query on the client, and
          <code class="font-mono text-sm">data-on:input__debounce.240ms</code> posts a page event
          with the current signals 240ms after you stop typing. The handler filters and patches
          <code class="font-mono text-sm">#search-results</code> alone — and deliberately does not
          echo the query back, because a patch landing while you are still typing would clobber
          the input.
        </.prose>

        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label="lib/dstar_demo_web/pages/active_search_page.ex"
            code={@snippet.wiring}
          />
        </div>
      </:how_it_works>
    </.demo_shell>
    """
  end
```

Move the existing `<section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_300px]">` block (currently `active_search_page.ex:75-141`) inside `<:demo>` verbatim except for the token table, and drop the trailing `<aside>` "Patched area" panel at lines 131-140 — its text is now redundant with the prose above.

- [ ] **Step 7: Convert `commands_page.ex`**

Same shape. Shell header: `active="Form Validation"`, `title="Form data validation"`, `summary="Datastar submits a real form with contentType: 'form'. The server validates the fields and patches only the status, field feedback, and submitted payload."`, no `signals`. `fetch!(:commands)`.

`key_points`: the four existing facts from `commands_page.ex:23-28`, unchanged.

`prose`: "The form is a real `<form>`: Datastar posts it with `contentType: 'form'`, so the server receives ordinary form fields rather than signals. Validation runs server-side and the response patches six separate fragments — the status badge, three field-feedback spans, the validation panel and the payload panel — leaving the inputs themselves untouched. That is why what you typed survives the round trip."

Set the `<code>` spans on `<form>`, `contentType: 'form'` as in Step 6.

- [ ] **Step 8: Convert `streaming_dashboard_page.ex`**

Shell header: `active="Streaming Dashboard"`, `title="Streaming dashboard"`, existing `summary` and `signals` map unchanged. `fetch!(:streaming_dashboard)`.

`key_points`: the four facts from `streaming_dashboard_page.ex:108-113`.

`prose`: "`connect/1` posts to the page path and `Dstar.Page.Plug` opens an SSE stream, then owns the receive loop. `stream_key/1` registers it per demo scope plus tab, so starting it again in the same tab replaces the old stream instead of running two. Each tick patches the three metric tiles and prepends one activity row; the final tick returns `{:halt, conn}`."

The demo body is `stream_frame/1` plus the controls; move the existing markup into `<:demo>`. `stream_frame/1`, `activity_row/1` and `metric_tile` call sites keep their ids — the SSE tests assert `#stream-frame`, `#activity-log` and `mode prepend`, so **do not rename any id here**.

- [ ] **Step 9: Convert `patch_lab_page.ex`**

Shell header: `active="Patch Lab"`, `title="Patch lab"`, existing `summary` and `signals`. `fetch!(:patch_lab)`.

`key_points`: all **five** facts from `patch_lab_page.ex:24-30`.

`prose`: "Every control posts a page event whose handler picks a different Datastar patch mode. `mode: :outer` swaps the target node, `:inner` only its children, `:append` and `:prepend` add list items, `:before` and `:after` insert siblings around an anchor, and `remove_elements/2` deletes outright. The selector and the mode are the whole API."

Ids `#lab-stage`, `#lab-target`, `#patch-list`, `#anchor-row`, `#removable-note`, `#before-zone`, `#after-zone` are patch targets — **do not rename them**.

- [ ] **Step 10: Convert `server_components_page.ex`**

Shell header: `active="Components"`, `title="Server-rendered components"`, existing `summary` and `signals`. `fetch!(:server_components)`.

`key_points`: the four facts from `server_components_page.ex:22-27`.

`prose`: "`ComponentStage` is a `Dstar.Component`: it owns both its markup and its `handle_event/3`. Events target `/ds/<module>/<event>`, so this page module has no handler clauses for the stage at all — and the same component function renders on first paint and inside every later patch."

- [ ] **Step 11: Convert `signals_page.ex`**

Shell header: `active="Signals"`, `title="Signals lifecycle"`, existing `summary` and `signals`. `fetch!(:signals)`.

`key_points`: the four facts from `signals_page.ex:36-41`.

`prose`: "Signals are client state. Datastar posts the current set with every event, so `handle_event/3` receives them already read; `patch_signals/2` writes server-owned values back and `remove_signals/2` deletes client ones. The inspector prints the raw map it was handed, minus the CSRF and tab keys."

The inspector's `<pre>` at `signals_page.ex:184` is hand-rolled, not a `code_block` — it renders JSON, not source. Apply the token table to it and leave it a `<pre>`.

- [ ] **Step 12: Convert `scripts_page.ex`**

Shell header: `active="Scripts"`, `title="Script helpers"`, existing `summary` and `signals`. `fetch!(:scripts)`.

`key_points`: the four facts from `scripts_page.ex:25-30`.

`prose`: "These three helpers append a one-shot `<script>` through a patch: `execute_script/3` runs browser code, `console_log/3` emits a structured console entry, and `redirect/3` commands a navigation. `auto_remove: false` leaves the tag in the DOM after it has run, so you can go and look at it."

Drop the "Secondary helper lane" `<aside>` at `scripts_page.ex:60-68`; fold its one useful sentence into the prose: "The other demos avoid these helpers so the server-rendered patch flow stays easy to inspect."

- [ ] **Step 13: Convert `presence_page.ex`**

Shell header: `active="Presence"`, `title="Presence room"`, existing `summary` and `signals`. `fetch!(:presence)`.

`key_points`: the four facts from `presence_page.ex:181-186`.

`prose`: "`handle_connect/2` subscribes to the room topic and tracks this tab with `Phoenix.Presence`, then patches the roster. `handle_info/2` reacts to `presence_diff` broadcasts, and `handle_disconnect/1` untracks on every exit from the receive loop — bookkeeping that a per-connection process would do for you."

`presence_page_test.exs` is the largest behavioural test file in the repo. Its selectors are patch targets: **do not rename any id** in this page.

- [ ] **Step 14: Run the full suite**

Run: `mix test`
Expected: PASS — the 38 pre-existing tests plus the new shell, jump-link, eyebrow, key-point, snippet and drift tests. If `snippet_drift_test.exs` fails, a snippet was mistyped or an escaped interpolation was missed; fix the snippet, not the test.

- [ ] **Step 15: Look at it**

Run: `mix phx.server` and open each of the eight pages. Confirm: light background, 240px sidebar with the current page marked, two jump links, no eyebrow, facts leading **How it works**, a highlighted snippet, and no dark panels left over from the token translation. Toggle to dark and back — the toggle in `app.js` should now drive both themes.

- [ ] **Step 16: Commit**

```bash
git add lib/dstar_demo_web/components/demo_components.ex lib/dstar_demo_web/snippets.ex \
  lib/dstar_demo_web/pages/ test/dstar_demo_web/pages_test.exs \
  test/dstar_demo_web/snippet_drift_test.exs
git commit -m "Rewrite demo_shell as a documentation layout and convert all eight pages"
```

---

## Phase 3: the eight LiveView comparisons

Tasks 4-11 each add one comparison. They are independent — any order works, and a reviewer can reject one without touching the others. **Every one of them is subject to the fairness rules in Global Constraints and to Rico's review before it ships.** The LiveView code below was written to be idiomatic; it is not compiled or run, and the pages say so.

Where each comparison lands: LiveView is conceded the win on **forms, streaming, scripts and presence**; **search and components** are near parity; **patch modes and signals** are genuine philosophical differences rather than a better and a worse. If a review finds a note that reads as advocacy rather than assessment, the note is wrong, not the framework.

---

### Task 4: The `compare` component and the Active Search comparison

Establishes the pattern the next seven tasks follow, and proves the drift test fires on a real comparison.

**Files:**
- Modify: `lib/dstar_demo_web/components/demo_components.ex` (add `compare/1`)
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `active_search`)
- Modify: `lib/dstar_demo_web/pages/active_search_page.ex` (add `<:comparison>`)
- Test: `test/dstar_demo_web/pages_test.exs`

**Interfaces:**
- Consumes: `demo_shell/1`'s `:comparison` slot and `code_block/1` (Task 3); `DstarDemoWeb.Snippets.fetch!/1`.
- Produces: `compare/1` — slots `:dstar` (required), `:liveview` (required), `:note` (optional). Every later comparison task uses exactly this component.

- [ ] **Step 1: Write the failing test**

Replace the `"jump links are derived from the slots a page actually passes"` test added in Task 3 (it asserted no page has a comparison) with this pair:

```elixir
  test "jump links are derived from the slots a page actually passes", %{conn: conn} do
    response = conn |> recycle() |> get(~p"/search") |> html_response(200)

    assert response =~ ~s[href="#comparison"]
    assert response =~ ~s[id="comparison"]
    assert response =~ "If this were LiveView"

    # A page with no :comparison slot advertises two jump links, not three.
    plain = conn |> recycle() |> get(~p"/scripts") |> html_response(200)
    refute plain =~ ~s[href="#comparison"]
    refute plain =~ ~s[id="comparison"]
  end

  test "a comparison labels the LiveView side as illustrative", %{conn: conn} do
    response = conn |> recycle() |> get(~p"/search") |> html_response(200)

    assert response =~ "illustrative, never compiled or run"

    # The LiveView snippet is displayed as highlighted source, so its bindings
    # appear as escaped text rather than as live attributes on this page.
    assert response =~ "phx-debounce"
    assert response =~ "&quot;240&quot;"
  end
```

As each of Tasks 5-11 lands, extend the `refute` half of the first test to a page that still has no comparison; after Task 11 no page qualifies, so delete that half and assert all eight have one.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/dstar_demo_web/pages_test.exs`
Expected: FAIL — `/search` renders no `#comparison`.

- [ ] **Step 3: Add the `compare` component**

Append to `lib/dstar_demo_web/components/demo_components.ex`, before the final `end`:

```elixir
  slot :dstar, required: true
  slot :liveview, required: true
  slot :note, doc: "what LiveView does better here — required by the fairness rules"

  def compare(assigns) do
    ~H"""
    <div class="mt-6">
      <div class="grid gap-5 lg:grid-cols-2">
        <div class="min-w-0">
          <h3 class="mb-2 flex flex-wrap items-baseline gap-x-2 text-sm font-semibold">
            <span class="inline-block size-2 shrink-0 bg-primary" aria-hidden="true"></span>
            Dstar
            <span class="font-normal text-base-content/55">— this page's real code</span>
          </h3>
          {render_slot(@dstar)}
        </div>

        <div class="min-w-0">
          <h3 class="mb-2 flex flex-wrap items-baseline gap-x-2 text-sm font-semibold">
            <span class="inline-block size-2 shrink-0 bg-base-300" aria-hidden="true"></span>
            LiveView
            <span class="font-normal text-base-content/55">— illustrative, never compiled or run</span>
          </h3>
          {render_slot(@liveview)}
        </div>
      </div>

      <aside
        :if={@note != []}
        class="mt-5 max-w-[68ch] border-l-2 border-primary/40 pl-4 text-sm leading-6 text-base-content/80"
      >
        {render_slot(@note)}
      </aside>
    </div>
    """
  end
```

- [ ] **Step 4: Fill in the Active Search comparison**

In `lib/dstar_demo_web/snippets.ex`, replace the `active_search` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        {:ok, assign(socket, query: "", segment: "all", results: search("", "all"))}
      end

      def handle_event("search", %{"query" => query, "segment" => segment}, socket) do
        query = String.trim(query)

        {:noreply,
         assign(socket,
           query: query,
           segment: segment,
           results: search(query, segment)
         )}
      end

      def render(assigns) do
        ~H\"\"\"
        <form phx-change="search" phx-submit="search">
          <input
            type="search"
            name="query"
            value={@query}
            phx-debounce="240"
            autocomplete="off"
            placeholder="Try stream, patch, signal, or owner names"
          />

          <select name="segment">
            <option :for={s <- ~w(all workflow dashboard tool)} value={s} selected={s == @segment}>
              {s}
            </option>
          </select>
        </form>

        <div id="search-results">
          <p>{length(@results)} matches</p>

          <article :for={item <- @results} id={"result-" <> item.name}>
            <h2>{item.name}</h2>
            <p>{item.type} · {item.owner}</p>
          </article>
        </div>
        \"\"\"
      end
      """,
      note: """
      LiveView needs less wiring here. `phx-debounce="240"` is built in, and the
      diff engine works out on its own that only the result list changed — no
      selector is named anywhere. It also tracks the in-flight state for you
      through `phx-change`'s loading classes, where the Dstar version declares
      `data-indicator="_searchPending"` explicitly.

      Dstar's one real advantage is that `query` lives in a client signal, so the
      server never re-renders the input at all. There is no round trip that could
      disturb a cursor position or an in-progress IME composition — which is
      exactly what the comment in the handler is guarding — and nothing is held
      open between keystrokes.
      """
```

Note the `\"\"\"` escapes: the LiveView snippet contains a `~H"""` sigil, which would otherwise close the heredoc holding it.

- [ ] **Step 5: Add the `<:comparison>` slot to the page**

In `lib/dstar_demo_web/pages/active_search_page.ex`, after the `</:how_it_works>` closing tag:

```elixir
      <:comparison>
        <.prose>
          Both sides debounce at 240ms, filter the same local dataset, and render
          the same empty and no-results states.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/active_search_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 6: Run the tests**

Run: `mix test`
Expected: PASS. `snippet_drift_test.exs` now checks that `active_search` has both a LiveView side and a note.

- [ ] **Step 7: Commit**

```bash
git add lib/dstar_demo_web/components/demo_components.ex lib/dstar_demo_web/snippets.ex \
  lib/dstar_demo_web/pages/active_search_page.ex test/dstar_demo_web/pages_test.exs
git commit -m "Add the compare component and the Active Search LiveView comparison"
```

---

### Task 5: The Form Validation comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `commands`)
- Modify: `lib/dstar_demo_web/pages/commands_page.ex` (add `<:comparison>`)

**Interfaces:** consumes `compare/1` and `code_block/1`; produces no new API.

- [ ] **Step 1: Fill in the comparison**

Replace the `commands` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        changeset = AccessPass.changeset(%AccessPass{}, %{})

        {:ok, assign(socket, form: to_form(changeset, as: :access_pass))}
      end

      def handle_event("validate", %{"access_pass" => params}, socket) do
        form =
          %AccessPass{}
          |> AccessPass.changeset(params)
          |> Map.put(:action, :validate)
          |> to_form(as: :access_pass)

        {:noreply, assign(socket, form: form)}
      end

      def render(assigns) do
        ~H\"\"\"
        <.form for={@form} id="access-pass-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:first_name]} type="text" label="First name" minlength="2" />
          <.input field={@form[:last_name]} type="text" label="Last name" />

          <.button phx-disable-with="Checking…">Request access</.button>
        </.form>
        \"\"\"
      end
      """,
      note: """
      LiveView wins this one outright. A changeset plus `to_form/2` gives you
      field-level errors, `<.input>` renders each error next to its own field,
      `used_input?/1` keeps untouched fields quiet until they are touched,
      `phx-disable-with` handles the in-flight state, and form recovery after a
      dropped connection is automatic. The Dstar version hand-rolls all of it:
      the six `patch/3` calls and the whole `field_feedback/1` component exist to
      do what `<.input>` does for free.

      What Dstar buys in exchange is that this is a plain HTML form. It posts
      with `contentType: 'form'`, so the server receives ordinary form params and
      the markup would still submit with JavaScript disabled — and the response
      names exactly which six fragments change, rather than diffing a rendered
      tree the server had to keep.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/commands_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Both sides validate the same three fields with the same rules, and both
          keep what you typed while showing server-owned feedback.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/commands_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/commands_page.ex
git commit -m "Add the Form Validation LiveView comparison"
```

---

### Task 6: The Streaming Dashboard comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `streaming_dashboard`)
- Modify: `lib/dstar_demo_web/pages/streaming_dashboard_page.ex` (add `<:comparison>`)

- [ ] **Step 1: Fill in the comparison**

Replace the `streaming_dashboard` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      @stream_steps 8
      @stream_delay 280

      def mount(_params, _session, socket) do
        if connected?(socket), do: Process.send_after(self(), {:tick, 1}, @stream_delay)

        {:ok,
         assign(socket,
           status: "live",
           tick: 0,
           throughput: 118,
           latency: 42,
           progress: 0,
           activity: []
         )}
      end

      def handle_info({:tick, tick}, socket) when tick <= @stream_steps do
        Process.send_after(self(), {:tick, tick + 1}, @stream_delay)

        {:noreply,
         assign(socket,
           tick: tick,
           throughput: 118 + tick * 9 + rem(tick, 3) * 4,
           latency: 42 - min(tick * 2, 18),
           progress: trunc(tick / @stream_steps * 100),
           activity: [tick | socket.assigns.activity]
         )}
      end

      def handle_info({:tick, _done}, socket) do
        {:noreply, assign(socket, status: "complete", progress: 100)}
      end
      """,
      note: """
      LiveView wins, and it wins structurally rather than on ergonomics. A
      LiveView **is** a stateful process per connection, so the entire notion of
      `stream_key/1` deduplication disappears: there is no second stream to
      replace, because a reconnect makes a new process and the old one dies. The
      three metric tiles and the activity list are assigns, so no `patch/3` call
      names a selector and no `mode: :prepend` has to be chosen. Bounding the run
      needs no `{:halt, conn}` — the final `handle_info/2` clause simply stops
      scheduling.

      Dstar's model is preferable only if you want the connection to be an HTTP
      request that ends. This stream closes and leaves nothing resident on the
      server; a LiveView holds a process, and its assigns, for as long as the tab
      is open. For a bounded eight-tick dashboard that is a poor trade, and this
      is the demo where the Dstar version is doing the most extra work for the
      least gain.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/streaming_dashboard_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Both sides push eight ticks at 280ms, update the same three metrics, and
          prepend one activity row per tick.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/streaming_dashboard_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/streaming_dashboard_page.ex
git commit -m "Add the Streaming Dashboard LiveView comparison"
```

---

### Task 7: The Patch Lab comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `patch_lab`)
- Modify: `lib/dstar_demo_web/pages/patch_lab_page.ex` (add `<:comparison>`)

- [ ] **Step 1: Fill in the comparison**

Replace the `patch_lab` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      #
      # LiveView has no patch-mode API at all: you change assigns and it works
      # out the DOM operation. The nearest thing to append and prepend is a
      # stream with :at; outer, inner, before and after have no equivalent
      # because you never name the operation.
      def mount(_params, _session, socket) do
        {:ok,
         socket
         |> assign(count: 0, note_visible?: true)
         |> stream(:rows, [%{id: "seed-row", label: "Seed row"}])}
      end

      def handle_event("append", _params, socket) do
        count = socket.assigns.count + 1

        {:noreply,
         socket
         |> assign(count: count)
         |> stream_insert(:rows, %{id: "row-" <> to_string(count), label: "append patch"}, at: -1)}
      end

      def handle_event("prepend", _params, socket) do
        count = socket.assigns.count + 1

        {:noreply,
         socket
         |> assign(count: count)
         |> stream_insert(:rows, %{id: "row-" <> to_string(count), label: "prepend patch"}, at: 0)}
      end

      def handle_event("remove", _params, socket) do
        {:noreply, assign(socket, note_visible?: false)}
      end

      def render(assigns) do
        ~H\"\"\"
        <div id="patch-list" phx-update="stream">
          <div :for={{dom_id, row} <- @streams.rows} id={dom_id}>{row.label}</div>
        </div>

        <div :if={@note_visible?} id="removable-note">Remove mode deletes this note.</div>
        \"\"\"
      end
      """,
      note: """
      These are different philosophies rather than a winner and a loser.
      LiveView deliberately hides the DOM operation: you describe the state you
      want and the diff engine picks the mutation. That is why there is no
      `:outer` or `:before` to get wrong, and why `remove` is expressed as a
      conditional rather than a deletion. `phx-update="stream"` covers the
      append and prepend cases and manages a memory bound for you, which
      hand-written `mode: :append` calls do not.

      Dstar exposes the operation directly. That is what makes this page
      demonstrable at all — there is nothing to show if the framework chooses for
      you — and it is what you need when the server holds no rendered copy of the
      page to diff against. The honest summary is that most applications want
      LiveView's abstraction, and the ones that cannot afford resident
      server-side state want this.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/patch_lab_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Only three of the seven modes have a LiveView counterpart, which is the
          point of the comparison rather than a gap in it.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/patch_lab_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/patch_lab_page.ex
git commit -m "Add the Patch Lab LiveView comparison"
```

---

### Task 8: The Components comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `server_components`)
- Modify: `lib/dstar_demo_web/pages/server_components_page.ex` (add `<:comparison>`)

- [ ] **Step 1: Fill in the comparison**

Replace the `server_components` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      defmodule DstarDemoWeb.ComponentStageLive do
        use DstarDemoWeb, :live_component

        def render(assigns) do
          ~H\"\"\"
          <div id={@id}>
            <button phx-click="profile" phx-target={@myself}>Profile</button>
            <button phx-click="timeline" phx-target={@myself}>Timeline</button>
            <button phx-click="deploy" phx-target={@myself}>Deploy</button>

            <p>{@component_kind} · renders: {@render_count}</p>
          </div>
          \"\"\"
        end

        def handle_event(kind, _params, socket) do
          {:noreply,
           assign(socket,
             component_kind: kind,
             render_count: socket.assigns.render_count + 1
           )}
        end
      end

      # In the parent LiveView:
      #
      #   <.live_component
      #     module={DstarDemoWeb.ComponentStageLive}
      #     id="component-stage"
      #     component_kind={@component_kind}
      #     render_count={@render_count}
      #   />
      """,
      note: """
      Near parity, and `Phoenix.LiveComponent` does strictly more:
      it has its own lifecycle through `update/3` and `preload/1`, and it can
      hold state between events without the parent knowing. If a stage needed to
      remember anything of its own, LiveView would win here without argument.

      The costs on the LiveView side are that a component requires an `:id`, that
      every event needs `phx-target={@myself}` or it silently dispatches to the
      parent instead, and that the component's state still lives in the parent's
      process. `Dstar.Component` is stateless and routes by module name, so
      nothing has to be targeted and this page needs no handler clauses at all —
      but there is no per-instance state to be had, and two stages on one page
      would share the same handler.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/server_components_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Both sides colocate the stage's markup with the handler that updates it,
          and both re-render the same function on first paint and on every update.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/server_components_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/server_components_page.ex
git commit -m "Add the Components LiveView comparison"
```

---

### Task 9: The Signals comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `signals`)
- Modify: `lib/dstar_demo_web/pages/signals_page.ex` (add `<:comparison>`)

- [ ] **Step 1: Fill in the comparison**

Replace the `signals` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      #
      # There is no client-owned state to inspect: assigns live on the server,
      # and the client only ever sends what a binding names explicitly. So this
      # page has no real LiveView counterpart — only the nearest thing.
      def mount(_params, _session, socket) do
        {:ok,
         assign(socket,
           scope: "release",
           filter: "open",
           server_tick: 0,
           audit_trail: "mount"
         )}
      end

      def handle_event("patch", _params, socket) do
        tick = socket.assigns.server_tick + 1

        {:noreply, assign(socket, server_tick: tick, audit_trail: "assign tick")}
      end

      # To send client-held values at all, each one must be named:
      #
      #   <button phx-click="patch" phx-value-scope={@scope} phx-value-filter={@filter}>
      #
      # or a JS hook pushes them:
      #
      #   this.pushEvent("patch", {scope, filter})
      """,
      note: """
      This is the one page where the two frameworks disagree about where state
      lives rather than one doing the same job better. LiveView's assigns are
      server-authoritative: the client cannot invent a field, so there is nothing
      to validate, no `remove_signals/2` to need, and no way for a stale client
      value to reach a handler. That is genuinely simpler and genuinely safer,
      and for most applications it is the right default.

      Dstar's signals are client-owned and arrive with every event, which is what
      makes an inspector like this one possible — and it means every handler must
      treat them as untrusted input. The tax is visible in this page's own code:
      `client_state/2` drops `csrf`, `_csrf_token`, `tabId` and `last_read` before
      displaying anything, and each numeric field is parsed defensively because a
      signal can arrive as a string, or as `""` when it was never set.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/signals_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          This is the one comparison where the two sides are not solving the same
          problem, because LiveView does not have the concept this page inspects.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/signals_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/signals_page.ex
git commit -m "Add the Signals LiveView comparison"
```

---

### Task 10: The Scripts comparison

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `scripts`)
- Modify: `lib/dstar_demo_web/pages/scripts_page.ex` (add `<:comparison>`)

- [ ] **Step 1: Fill in the comparison**

Replace the `scripts` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def handle_event("execute", _params, socket) do
        runs = socket.assigns.script_runs + 1

        {:noreply,
         socket
         |> assign(script_runs: runs, last_script_action: "push_event")
         |> push_event("script-pulse", %{run: runs})}
      end

      def handle_event("redirect", _params, socket) do
        {:noreply, push_navigate(socket, to: ~p"/scripts?redirected=1")}
      end

      # The browser half is a hook, declared once in your bundle rather than
      # sent down per event:
      #
      #   Hooks.ScriptPulse = {
      #     mounted() {
      #       this.handleEvent("script-pulse", ({run}) => {
      #         document.documentElement.dataset.dstarScriptPulse = String(run)
      #       })
      #     }
      #   }
      """,
      note: """
      LiveView's design is better here, and the difference is a security one.
      `push_event/3` sends **data** to a named hook that already exists in your
      bundle; `execute_script/3` sends **code**. Anything interpolated into that
      string is one mistake away from running in the browser — which is why this
      page's own counter goes through `Jason.encode!/1` before it is spliced in.
      LiveView also gives `push_navigate/2` and `push_patch/2`, which move the
      user without discarding the process, where `redirect/3` is a full
      navigation.

      Dstar's helpers win on immediacy only: no hook has to be written,
      registered, or bundled to make a one-off effect happen. That is why they
      exist, and it is also why the other seven demos deliberately avoid them —
      the server-rendered patch flow stays easier to inspect without them.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/scripts_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Both sides run browser code from the server and both perform a
          server-commanded navigation; they disagree about what crosses the wire.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/scripts_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Run the tests**

Run: `mix test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/scripts_page.ex
git commit -m "Add the Scripts LiveView comparison"
```

---

### Task 11: The Presence comparison

The last comparison. This task also closes out the jump-link test, since after it every page has a `<:comparison>`.

**Files:**
- Modify: `lib/dstar_demo_web/snippets.ex` (fill in `presence`)
- Modify: `lib/dstar_demo_web/pages/presence_page.ex` (add `<:comparison>`)
- Modify: `test/dstar_demo_web/pages_test.exs`

- [ ] **Step 1: Fill in the comparison**

Replace the `presence` entry's `liveview: nil, note: nil` with:

```elixir
      liveview: """
      # Illustrative LiveView equivalent — not compiled or run.
      def mount(_params, _session, socket) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)

          {:ok, _} =
            Presence.track(self(), @topic, socket.id, %{
              name: socket.assigns.visitor_name,
              color: socket.assigns.visitor_color,
              status: "active",
              last_seen: System.system_time(:second)
            })
        end

        {:ok, assign(socket, roster: Presence.list(@topic), activity: [])}
      end

      def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
        {:noreply, assign(socket, roster: Presence.list(@topic))}
      end

      def handle_event("ping", _params, socket) do
        Phoenix.PubSub.broadcast(
          DstarDemo.PubSub,
          @topic,
          {:ping, socket.assigns.visitor_name}
        )

        {:noreply, socket}
      end

      # No untrack is written anywhere. Presence is bound to self(), and the
      # LiveView process dying on disconnect removes the entry — including when
      # it dies by crashing.
      """,
      note: """
      LiveView wins, and this demo shows precisely why. Presence is keyed to a
      process, and a LiveView already has one per connection: tracking happens
      once in `mount/3`, and untracking happens for free when the process dies.

      A Dstar stream is a request that has to clean up after itself. This page
      therefore needs `handle_disconnect/1` to untrack, a `presence_instance`
      token so a replaced stream can tell itself apart from the one that replaced
      it, and a `pagehide` beacon in `app.js` posting a `leave` event so a closed
      tab does not sit in the roster until it times out. That is three moving
      parts LiveView does not have, and all three are visible in this page's
      source.

      What Dstar gets back is that nothing is resident between events. For
      presence specifically, resident state is the entire feature — so this is
      the demo where the Dstar version is hardest to justify on its own merits,
      and it is here to show the pattern rather than to recommend it.
      """
```

- [ ] **Step 2: Add the `<:comparison>` slot**

In `lib/dstar_demo_web/pages/presence_page.ex`, after `</:how_it_works>`:

```elixir
      <:comparison>
        <.prose>
          Both sides track each tab with `Phoenix.Presence`, react to
          `presence_diff`, and broadcast a room ping. They differ in what has to
          happen when a visitor leaves.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label="lib/dstar_demo_web/pages/presence_page.ex"
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note>{@snippet.note}</:note>
        </.compare>
      </:comparison>
```

- [ ] **Step 3: Close out the jump-link test**

Every page now has a comparison, so replace the test from Task 4 Step 1 with:

```elixir
  test "every demo page advertises and renders its LiveView comparison", %{conn: conn} do
    for {path, _marker} <- demo_pages() ++ [{~p"/presence", nil}] do
      response = conn |> recycle() |> get(path) |> html_response(200)

      assert response =~ ~s[href="#comparison"], "#{path} has no comparison jump link"
      assert response =~ ~s[id="comparison"], "#{path} renders no comparison section"
      assert response =~ "If this were LiveView"
      assert response =~ "illustrative, never compiled or run"
    end
  end
```

- [ ] **Step 4: Run the tests**

Run: `mix test`
Expected: PASS. `snippet_drift_test.exs` now checks all eight demos have a complete comparison.

- [ ] **Step 5: Hand the eight comparisons to Rico**

This is the spec's review gate, and it is the only checkpoint on the LiveView code — nothing compiles or runs it. Present all eight notes together and ask specifically whether any of them reads as advocacy rather than assessment.

- [ ] **Step 6: Commit**

```bash
git add lib/dstar_demo_web/snippets.ex lib/dstar_demo_web/pages/presence_page.ex \
  test/dstar_demo_web/pages_test.exs
git commit -m "Add the Presence LiveView comparison"
```

---

### Task 12: Restyle the home page

Last, per the spec's migration order. The home page does not use `demo_shell` — it is built from `demo_tile` and is restyled on its own.

**Files:**
- Modify: `lib/dstar_demo_web/pages/home_page.ex`
- Test: `test/dstar_demo_web/pages_test.exs`

**Interfaces:**
- Consumes: theme tokens (Task 1); `Layouts.theme_toggle/1`, which now drives both themes.
- Produces: nothing other pages consume.

- [ ] **Step 1: Write the failing test**

Extend the existing `"GET /"` test in `test/dstar_demo_web/pages_test.exs` with:

```elixir
    # Every demo is reachable from the home page, including presence, which the
    # original test omitted.
    assert response =~ ~s[href="/presence"]

    # Restyled onto theme tokens — no leftover hardcoded dark utilities.
    refute response =~ "bg-zinc-950"
    refute response =~ "text-zinc-100"
    refute response =~ "bg-emerald-300"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/dstar_demo_web/pages_test.exs`
Expected: FAIL — the home page still renders `bg-zinc-950` and has no `/presence` link in the assertions' reach (the tile exists; the `refute`s are what fail).

- [ ] **Step 3: Restyle the page**

Replace `render/1` and `demo_tile/1` in `lib/dstar_demo_web/pages/home_page.ex` with:

```elixir
  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="min-h-screen bg-base-100 text-base-content">
      <div class="mx-auto w-full max-w-[1100px] px-5 py-10 sm:px-8">
        <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 pb-5">
          <a href={~p"/"} class="flex items-center gap-2.5 text-sm font-semibold tracking-tight">
            <span class="grid size-7 place-items-center bg-primary text-primary-content">
              <.icon name="hero-bolt-micro" class="size-4" />
            </span>
            Dstar Demo
          </a>
          <Layouts.theme_toggle />
        </header>

        <h1 class="mt-10 max-w-[68ch] text-4xl font-semibold tracking-tight sm:text-5xl">
          Dstar server UI showcase
        </h1>
        <p class="mt-4 max-w-[68ch] text-base leading-7 text-base-content/70">
          Eight focused Dstar.Page modules for commands, signals, element patches, streaming,
          components, and presence — each page is one module and one router line, shown beside
          how Phoenix LiveView would solve the same problem.
        </p>

        <section id="map" class="mt-10 grid border-t border-l border-base-300 sm:grid-cols-2">
          <.demo_tile
            title="Form Validation"
            href={~p"/commands"}
            icon="hero-clipboard-document-check"
            body="A native form submits fields with contentType: 'form' and patches feedback only."
          />
          <.demo_tile
            title="Active Search"
            href={~p"/search"}
            icon="hero-magnifying-glass"
            body="Typing sends signals and patches only the result panel."
          />
          <.demo_tile
            title="Streaming Dashboard"
            href={~p"/streaming"}
            icon="hero-signal"
            body="handle_connect and handle_info drive a bounded, deduplicated SSE stream."
          />
          <.demo_tile
            title="Patch Lab"
            href={~p"/patch-lab"}
            icon="hero-squares-plus"
            body="outer, inner, append, prepend, before, after, and remove."
          />
          <.demo_tile
            title="Server Components"
            href={~p"/components"}
            icon="hero-cube-transparent"
            body="A Dstar.Component colocates shared UI with its event handlers."
          />
          <.demo_tile
            title="Signals Inspector"
            href={~p"/signals"}
            icon="hero-adjustments-horizontal"
            body="patch_signals, remove_signals, and the signals handed to handle_event."
          />
          <.demo_tile
            title="Script Helpers"
            href={~p"/scripts"}
            icon="hero-code-bracket-square"
            body="execute_script, console_log, and a safe redirect target."
          />
          <.demo_tile
            title="Presence Room"
            href={~p"/presence"}
            icon="hero-user-group"
            body="Multiple tabs join one room, update the roster, and send pings."
          />
        </section>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :body, :string, required: true

  def demo_tile(assigns) do
    ~H"""
    <a
      href={@href}
      class="group border-r border-b border-base-300 p-5 transition hover:bg-base-200 focus:outline-none focus:ring-2 focus:ring-primary/40 focus:ring-inset"
    >
      <div class="flex items-center gap-2.5">
        <.icon name={@icon} class="size-5 shrink-0 text-base-content/45 transition group-hover:text-primary" />
        <h2 class="text-base font-semibold tracking-tight">{@title}</h2>
      </div>
      <p class="mt-2 max-w-[52ch] text-sm leading-6 text-base-content/65">{@body}</p>
    </a>
    """
  end
```

The `status` attr and its "ready" badge are dropped: all eight demos are ready, so the badge carried no information and eight identical green pills were the loudest thing on the page. The grid becomes a hairline lattice — borders on the container's top and left, on each tile's right and bottom — which is why tiles no longer have their own card treatment.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/dstar_demo_web/pages_test.exs`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `mix test`
Expected: PASS, all tests.

- [ ] **Step 6: Look at the whole site**

Run: `mix phx.server`. Walk all nine pages in light and dark. Check the sub-`lg` disclosure by narrowing the window below 1024px.

- [ ] **Step 7: Commit**

```bash
git add lib/dstar_demo_web/pages/home_page.ex test/dstar_demo_web/pages_test.exs
git commit -m "Restyle the home page as a documentation index"
```

---

## Self-review notes

Run through these before starting, and again at the end.

**Spec coverage.** Every section of `docs/superpowers/specs/2026-07-25-docs-restyle-design.md` maps to a task: Scope → Tasks 1-12; Decisions table → Tasks 1 (palette, theming, typography), 2 (code), 3 (layout, measure, navigation aid), 4-11 (comparison); Component architecture → Task 3 (shell, dropped `eyebrow`, facts into `key_points`, derived jump links) and Tasks 2 and 4 (`code_block`, `compare`); Layout → Task 3; Theme → Task 1; Typography → Task 1's constraint not to override `font-sans`; Code highlighting → Task 2; The LiveView comparison → Tasks 4-11, with the drift test in Task 3 and the review gate in Task 11 Step 5; Migration order → the task order; Testing → Tasks 1, 2, 3, 12; Risks → see below.

**Deliberate deviations,** all recorded in *Corrections to the spec* above: theme declared in `app.css` not the vendored plugin; themes named `light`/`dark`; four Makeup deps not one; `code_block` takes an attr not a slot; `Snippets` and `snippet_drift_test.exs` in place of `Comparisons` and `comparison_test.exs`, widened to cover the wiring excerpts too; `pages_test.exs` needs no repair.

**Two spec risks change status.** The `pages_test.exs` churn risk is **closed**, not mitigated — no assertion in the suite matches anything this restyle changes, so there is no opportunity to mask a regression by updating one carelessly. The "eight comparisons only validated at the end" risk **stands as written**: the spec considered and rejected pilot-first sequencing, so Tasks 4-11 write all eight before the gate in Task 11 Step 5. If the first two come back wrong, the correction cost multiplies across the remaining six. That was Rico's call and the plan follows it; the only hedge available is to review Task 4's comparison when it lands rather than waiting for Task 11.

**One risk this plan adds.** Task 3's token translation is 8 files of find-and-replace across roughly 1,900 lines, and no test asserts colour. A missed `bg-zinc-900` shows up as a dark panel on a white page, which Step 15's manual pass is there to catch. Grep for `zinc-`, `emerald-`, `sky-`, `amber-` and `rose-` under `lib/dstar_demo_web/pages/` before committing; the only legitimate remaining hits should be none.

**Interaction with other work,** per the spec's closing section: the `:demo` slot is free-form and imposes no grid, wrapper, or width on its contents, so the Live Collections three-panel layout tracked on [Map: a self-demonstrating nudge demo](https://github.com/ricotrevisan/dstar-demo/issues/1) drops in without further shell changes. Nothing in this plan invalidates that map. A ninth demo does need adding to the `@demos` list in `demo_components.ex` and to the home page's tiles — two lines, in the places this plan already touches.

**One thing left for the reviewer to decide.** The spec says to use DaisyUI "for theme tokens plus `btn`, `badge`, `kbd` and `tabs`". This plan uses the tokens everywhere and those four component classes nowhere: `action_button` and `pill` stay hand-written, because DaisyUI's `btn` brings its own radius, shadow and hover treatment, and overriding them back out costs more utilities than writing the button. Adopting them later is a component-level change — but note the stylesheet does **not** ship unused component classes: Tailwind prunes them, so `badge`, `kbd` and `tabs` are absent from the build today and appear only once something uses them. Flagging it rather than deciding silently — if `btn` is wanted on `action_button`, say so and it is a one-component edit in Task 3 Step 3.
