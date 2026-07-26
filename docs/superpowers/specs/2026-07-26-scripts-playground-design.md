# Turn the Scripts page into a script playground

**Date:** 2026-07-26
**Status:** approved, not yet implemented
**Task:** #2 — improve scripts page

## Problem

Two of the page's three buttons have no visible effect.

`execute` sets `document.documentElement.dataset.dstarScriptPulse` — invisible
unless you inspect `<html>` in DevTools. `console` writes to the browser console
— invisible unless DevTools is open. Only `redirect` visibly does anything. A
visitor clicks all three, watches a counter increment, and leaves with no
evidence that the server ran code in their browser. The page's own summary
claims Dstar "can append safe script actions over SSE for one-off browser
effects" and then gives the reader no way to confirm it.

Three smaller faults compound it:

- **"Helper log" is not a log.** `script_log/1` renders three fixed sentences
  that never change. A panel labelled "log" that never accumulates entries
  teaches the wrong mental model.
- **`auto_remove: false` is explained but never shown.** The prose says it
  "leaves the tag in the DOM after it has run, so you can go and look at it" —
  and then does not show you where.
- **The best writing on the page is dead content.** `snippets.ex` carries a
  sharp, honest note (`push_event/3` sends *data*; `execute_script/3` sends
  *code*), and `compare` has a `:note` slot built to hold exactly that. No page
  in the repo passes `<:note>`. Nobody has ever read that paragraph.

## Goal

The visitor supplies the input, watches their own code cross the wire, and sees
three independent proofs that it ran. The security tradeoff stops being an
abstract warning and becomes the thing they just did.

## Scope

**In:** `lib/dstar_demo_web/pages/scripts_page.ex`, the `:scripts` entry in
`lib/dstar_demo_web/snippets.ex`, and one small page script (~25 lines) for the
console mirror and DOM residue observer.

**Out:** No changes to `demo_components.ex`; the `:note` slot already exists and
just needs a caller.

**Not a risk:** snippet drift. `snippets.ex` hand-copies handler source, but
`test/dstar_demo_web/snippet_drift_test.exs` already asserts that every `wiring`
snippet still appears verbatim (modulo leading whitespace) in the page module it
claims to quote. Changing these handlers *will* fail that test until the snippet
is updated in the same commit, which is the desired behaviour.

## Decisions

| Decision | Choice |
|---|---|
| Page shape | JS editor as hero, two compact inputs below |
| Editor | Plain `<textarea>`, mono — no CodeMirror |
| Console output | Mirrored in-page **and** a DevTools nudge |
| Helper log | Real append-only log via `mode: :prepend` |
| `auto_remove: false` | Shown as a live list of surviving `<script>` tags |
| Code prefill | Presets only — **never** from a URL param |

## The demo section

Three input surfaces, one per helper. Each keeps its real API shape rather than
being flattened into one box — the page should teach the actual signatures.

### Hero: the JS editor (`execute_script/3`)

A mono `<textarea>` bound to a `$script_source` signal, a **Run** button, and a
row of preset buttons that load starter snippets into the editor:

- *Pulse the page* — sets a `data-` attribute on `<html>` (the current demo)
- *Move an element* — mutates something visible on the page
- *Throw an error* — proves the code is genuinely running in the browser

Presets write `$script_source` client-side; only **Run** makes a round trip.

### Below it: two compact inputs

- **`console_log/3`** — a JSON payload field (`$console_payload`) and a level
  select (`info` / `warn` / `error`).
- **`redirect/3`** — a path field (`$redirect_path`), prefilled
  `/scripts?redirected=1`.

## Observability

Three panels, all fed by **one** page script. It lives inline in the Scripts
page template, not in `assets/js/app.js` — `app.js` is shared by all eight
demos, and nothing outside this page needs a console wrapper.

### Helper log

Replaces the static `script_log/1`. Each run prepends a server-rendered row into
`#helper-log` with `mode: :prepend` — helper name, the exact argument sent, and
the run number. A **Clear** button resets it.

This makes the log a second Patch Lab lesson for free: the visitor watches
`:prepend` build a list while learning the script helpers.

**Redirect turns its own destructiveness into the lesson.** `redirect/3` is a
full page load, so it wipes the log. On `?redirected=1`, seed the log with one
row: *"redirect/3 navigated the browser here. Full page load, which is why this
log starts empty."*

### Console mirror

The page script wraps `console.log/info/warn/error`, echoing entries into a
panel. A callout sits beside it:

> Open DevTools (⌘⌥J) — these are real console entries. This panel is only a
> copy.

The mirror makes the page self-contained; the callout keeps it honest about
where the output actually goes.

### Script residue

A `MutationObserver` lists the `script[data-demo-script]` tags still sitting in
the DOM. This is what `auto_remove: false` means, finally shown instead of
described.

`Dstar.Scripts.execute/3` adds `data-effect="el.remove()"` when `auto_remove` is
true and omits it when false, so the surviving tags are real evidence, not a
simulation.

## Handlers

```elixir
handle_event(conn, "run", signals)       # execute_script with $script_source
handle_event(conn, "console", signals)   # console_log with parsed $console_payload
handle_event(conn, "redirect", signals)  # redirect to $redirect_path
handle_event(conn, "clear", signals)     # reset #helper-log
```

Each also `patch_signals` the run count and prepends its log row.

**Input handling.** The page is *about* untrusted signal input, so it should
model treating it that way:

- `console` parses the JSON field. On success it passes a map, which
  `console_log/3` renders through `Jason.encode!/1`. On failure it logs an error
  row and does not call the helper.
- `redirect` requires a leading `/`. This is a **demo-scoping guard, not a
  security one** — `Dstar.Scripts.redirect/3` already runs the URL through
  `Jason.encode!/1`. The guard exists so the visitor does not accidentally leave
  the demo.
- `run` passes `$script_source` through verbatim. That is the entire point of
  the page, and it is why the security section below is not optional.

## Security

Three moves, in the order the reader meets them.

**1. Inline note beside the editor.** Your JS reaches only your own browser.
Signals are client-owned and arrive per connection, so a visitor can only run
code in their own tab. This is self-XSS, which is not a vulnerability.

**2. The `<:note>` slot on `compare`.** Pass the existing paragraph from
`snippets.ex`: `push_event/3` sends **data** to a hook already in your bundle;
`execute_script/3` sends **code**. This page is the reason that slot was built.

**3. A hard rule, stated in a code comment at the editor.** Never prefill
`$script_source` from a URL param. Typed JS is harmless; a `?code=` param would
produce a shareable link that runs attacker-authored JS in a victim's browser —
turning self-XSS into real XSS. The comment exists so a later contributor
adding "shareable snippets" hits the reasoning before the vulnerability.

## Writing

- Rewrite `summary` around the new shape: the visitor writes the code.
- Rewrite `key_points`. Drop "The helper scripts stay inert after they execute"
  — the residue panel now shows this, and the bullet was vague anyway.
- Swap the wiring snippet from the old `execute` handler to the new `run`
  handler, which is the interesting one.
- Keep the LiveView comparison snippet as is; the hook-vs-code contrast still
  holds and gets sharper now that the visitor has typed code into the box.

## Verification

- `mix test`
- Via `browser_eval`: type JS into the editor, run it, confirm the effect
  happens, a log row appears, and a `script[data-demo-script]` tag shows in the
  residue panel.
- Confirm `console_log` output appears in both the mirror panel and the real
  console.
- Confirm malformed JSON produces an error row and no console call.
- Confirm redirect returns to `/scripts?redirected=1` with the seeded log row.
