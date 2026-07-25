# Restyle dstar_demo as a documentation site

**Date:** 2026-07-25
**Status:** approved, not yet implemented

## Goal

Turn dstar_demo from a dark app-like demo gallery into a light, minimal
documentation site. Every demo page shows the live demo, explains the Dstar
wiring, and then compares it to how Phoenix LiveView would solve the same
problem.

## Scope

**In:** `demo_shell` and `demo_components`, all eight demo pages, the home page,
the root layout, `assets/css/app.css`, `assets/vendor/daisyui-theme.js`, and a
LiveView comparison for each of the eight demos.

**Out:** working LiveView implementations (the comparison is static code — see
[Comparison](#the-liveview-comparison)); the Live Collections demo itself, which
is a separate effort tracked on its own map.

## Decisions

| Decision | Choice |
|---|---|
| Layout | Persistent left sidebar + wide content column; no right-hand rail |
| Text measure | Asymmetric — prose at `68ch`, demo and code panes full column width |
| Navigation aid | Jump-to links under the title, derived from which slots are present |
| Palette | Light default: white / near-black / gray, `#e8590c` orange accent |
| Theming | DaisyUI for theme tokens and light/dark, plus a few components |
| Typography | System stacks for both sans and mono — no web fonts |
| Code | Makeup, server-side, no JavaScript |
| Comparison | Static side-by-side code, not a running LiveView |

## Component architecture

`demo_shell` is **rewritten in place**, not added alongside. All eight call sites
change together; two shells would drift. The home page does not use
`demo_shell` — it is built from `demo_tile` and is restyled separately.

```elixir
attr :active, :string, required: true
attr :title, :string, required: true
attr :summary, :string, required: true

slot :demo, required: true          # the live, interactive thing
slot :how_it_works, required: true  # prose at reading measure + Dstar code
slot :comparison                    # optional side-by-side
```

`eyebrow` is dropped. It currently repeats the nav label directly above the
title; with a persistent sidebar that is the third time the page says where you
are.

The `:aside` slot is dropped, but **its content is not**. Every demo's four
`demo_facts` bullets are the sharpest writing on these pages. They become a
`key_points` list leading the **How it works** section — same words, now
introducing the explanation instead of sitting in a column beside it.

Jump links are derived from which slots are populated, so a page without a
`:comparison` renders two links rather than three. No list to keep in sync.

Two new components:

```elixir
<.compare>
  <:dstar>...</:dstar>
  <:liveview>...</:liveview>
  <:note>...</:note>
</.compare>

<.code_block language="elixir">...</.code_block>
```

## Layout

- Sidebar 240px, sticky, full height, listing the eight demos.
- Below `lg`, the sidebar collapses to a disclosure above the content — not a
  drawer. The nav is short and this needs no JavaScript.
- Content column fills the remainder, capped at 1100px.
- Prose capped at `68ch`. Demo and code panes span the full column.

The comparison is two code panes side by side, which is precisely why the column
is wide and why prose is capped separately.

## Theme

One custom DaisyUI theme in the already-vendored `assets/vendor/daisyui-theme.js`,
defined in both modes. `app.css` currently defaults to dark (`:root {
color-scheme: dark }`); that flips to light.

| token | light | dark |
|---|---|---|
| `base-100` | `#ffffff` | `#0c0c0c` |
| `base-200` | `#fafafa` | `#141414` |
| `base-300` | `#e2e2e2` | `#262626` |
| `base-content` | `#111111` | `#f2f2f2` |
| `primary` | `#e8590c` | `#e8590c` |

DaisyUI is already vendored (`assets/vendor/daisyui.js`) but **not enabled** —
`app.css` only plugs in heroicons. Enabling it is one `@plugin` line.

Use DaisyUI for theme tokens plus `btn`, `badge`, `kbd` and `tabs`. Everything
structural — sidebar, panels, code blocks, the comparison grid — stays
hand-written Tailwind utilities, so DaisyUI's rounded, shadowed product-app look
does not override the minimal design.

### Accessibility constraint on the accent

`#e8590c` on white measures **3.58:1**. That passes WCAG AA for large text
(≥3:1) and UI components, and **fails** the 4.5:1 required for normal body text.
On `#0c0c0c` it measures 5.33:1 and passes.

Therefore, in light mode the orange is for rules, active states, borders, the
logo, and large text **only** — never small body copy and never inline links
inside a paragraph. If orange is later wanted in running prose, darken it to
approximately `#c2410c` (~5.9:1).

## Typography

System stacks, no web fonts:

- Sans: Tailwind's default `font-sans` — do not override it.
- Mono: `ui-monospace` and friends.

Zero bytes over the wire, no `@font-face`, no FOUT, nothing in
`priv/static/fonts/`. The cost is that the site renders slightly differently
across platforms and carries no typographic personality — identity comes from
layout, spacing, hairlines and the accent. Adding a face later is a one-file
change that nothing here blocks.

## Code highlighting

Makeup, rendered server-side. It understands Elixir and HEEx, needs no
JavaScript, and keeps rendering consistent with everything else on these pages.

## The LiveView comparison

The riskiest part of this work. It is comparative advocacy about someone else's
framework, and a strawman would discredit the whole site.

**The Dstar side is real code, enforced by a test.** Each snippet is an excerpt
from the actual page module. `comparison_test.exs` reads the source file and
asserts the snippet appears verbatim. Snippets drifting from the code they
document is the standard failure mode of documentation sites; the suite catches
it here.

**The LiveView side is explicitly labelled illustrative.** Nothing compiles or
runs it. The page says so rather than letting readers assume otherwise.

**Fairness rules — requirements, not guidance:**

1. **Like for like.** Both sides solve the same problem with the same features.
   No dropping the debounce on one side or hand-waving error handling on the
   other.
2. **No strawmen.** Idiomatic LiveView as a competent LiveView developer would
   write it — not the worst version that makes the point.
3. **Concede where LiveView wins.** The `<:note>` must say what LiveView does
   better wherever that is true. It genuinely is for stateful, high-frequency UI
   and for anything wanting client-side optimistic updates. A comparison that
   never concedes reads as marketing.

**Review gate:** all eight comparisons are reviewed by Rico before they ship.

## Migration

Order of work:

1. Theme and shell. The signature change breaks all eight pages at once; there
   is no incremental path, so shell and page updates land in one commit.
2. Per-page content — facts moved into **How it works**.
3. The eight comparisons.
4. Home page.

## Testing

Of the 38 existing tests, most assert behaviour — SSE patches, event
round-trips, `assert_patched_element` — and are untouched by the restyle. The
at-risk set is the page-render assertions in `pages_test.exs` that match titles
and copy; dropping `eyebrow` and moving the facts breaks some of those. They are
updated as part of this work, not treated as regressions.

One new test: the snippet-drift check described above.

## Risks

- **Eight LiveView comparisons are only validated at the end.** A pilot-first
  sequencing was considered and explicitly rejected in favour of one pass. The
  review gate is the sole checkpoint; if the first comparisons come back wrong,
  the correction cost is multiplied across all eight.
- **Accuracy of the LiveView code** cannot be verified by the compiler or the
  suite, since nothing runs it. Mitigated by the fairness rules and the review
  gate, not eliminated.
- **`pages_test.exs` churn** may mask a real regression if assertions are
  updated carelessly. Update them deliberately, one page at a time.

## Interaction with other work

The `:demo` slot is free-form, so the Live Collections three-panel layout drops
in without further shell changes. This restyle does not invalidate anything on
that map.
