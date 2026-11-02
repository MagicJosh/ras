---
name: artifacts
description: Use when you build, restyle or check an HTML Artifact page, such as a spec page, plan, explainer, report, dashboard-style page or mock-up, or a page that shows numbers, tables, charts or terminal output. Gives the house look, ready parts, accuracy rules, a spec page builder and a page lint.
---

# Artifacts

This house style for Artifact pages, and the rules that keep every fact on them true. This folder holds the parts that proved themselves on real pages, so a new page reuses them instead of reinventing them.

The Artifact flow still runs first: the quickstart or `artifact-design`, whose page contract holds in full. This skill replaces only the look, so it wins over generic advice to give each page a fresh identity. An Artifact made from a type (slides, docs, dashboard) keeps its type's look.

## Parts: which part for which need

| Need on the page | Part | Inline | Call |
|---|---|---|---|
| Every page: tokens, type, header, `.meta` status line, `.card` grid, `footer` | page frame | `style.css`, all of it | |
| A spec as a page that can be edited in place | spec page | built whole by `spec-page.mjs` | see "Spec pages" |
| A few headline numbers, each against its limits | stat tiles | `parts.css` "stat tiles" + `chart.js` + `data.js` | `CrispData.tiles(el, list)` |
| Many values to look up, compare or sort, rows by columns | data table | "data table" + `chart.js` + `data.js` | `CrispData.table(el, o)` |
| One thing's fixed facts: version, supply, limits | spec table | "spec table" | markup only |
| One value per cell of a grid | heatmap | "heatmap" + `chart.js` + `data.js` | `CrispData.heat(el, o)` |
| Numbers over time, against limits or bands | line chart | "charts" + `chart.js` | `CrispChart.render(id, o)` |
| Amounts across categories: a ranking, a comparison, parts of a total | bar chart | "charts" + `chart.js` | `CrispChart.bars(id, o)` |
| A trend inside a tile or a table cell | sparkline | "charts" + `chart.js` | `CrispChart.spark(data, o)` |
| Several panels sharing the page | panel grid | "panel grid" | `.gd > .panel.spanN` with a `.ph` header |
| A process in stages, A to B to C | stage strip | "stage strip" | |
| What feeds what: sources left, their users right | link map | "link map" + `linkmap.js` | `CrispMap.mount(el, left, right)` |
| A sketch of a screen or dashboard | mock dashboard | "mock dashboard", "cell grid" | |
| Work in waves or phases | build order | "build order" | |
| Terminal, CLI or status line output | terminal | `style.css` terminal mock + `terminal.js` | `CrispTerm.render(el, ansi)` |

Every `parts.css` section needs its "tags" section. Each file's header shows the markup it expects and every option of its calls. [`example.html`](example.html) is a sample spec page built from [`example-spec.md`](example-spec.md): read it before building a plan, and copy its page frame. [`gallery.html`](gallery.html) shows every data part with example values: read it before building a data page. [`references/data-pages.md`](references/data-pages.md) says how to lay out a page full of data and the reasons behind the data rules. When a page needs something these parts lack, build it from the same tokens and type, inside that page.

## Build a page

1. **Collect the facts.** Before any markup, list every number, name, version, path, limit and date the page will state, each with its source: a file:line, a command you ran and its output, or a doc URL. This list becomes the footer. Done when every planned fact has a source or is a labelled example (rules below).
2. **Start the file:** `<title>`, then `<meta name="claude:viewport-fit-sides" content="cover">`, then the font links from `style.css`'s header, then one `<style>` holding `style.css` and the `parts.css` sections you use.
3. **Compose** inside `<div class="wrap">`: a header (`.eyebrow`, an `h1` naming what the page answers, a `.lede` with `<b>` on the key facts, a `.meta` line with a status `.badge` and the date), then sections of `h2` + `p.sub` + content, then `<footer>` with the sources and "As of <date>". Add "Still open" cards when anything is unverified, and "Left out on purpose" cards when you skip something the reader would expect.
4. **Script:** one `<script>` at the end with the helper files you use (`chart.js` before `data.js`), then the page's own calls.
5. **Lint:** run `node lint.mjs <page.html>` from this folder until it prints PASS. Then take the one preview look `artifact-design` allows (desktop and phone, light and dark), fix what it shows, and publish.

## Spec pages

The `spec` skill uses this part. `specs/current.md` stays the single source of truth; the page is a view built from it.

- **Build:** `node <this folder>/spec-page.mjs build specs/current.md specs/current.html`. It reads the sections, the spec's date and its `cksum` (the checksum the ras gate uses), and writes one page with everything inlined. The header shows the date and the cksum, so a stale page is visible. Then lint it.
- **What it shows:** the goal; each decision beside its rejected alternative and "hard to undo"; a link map from Blast radius lines written as `` - `path`: what changes. Callers: `a`, `b`. ``; waves from an optional `## Work packages` section (`- Wave 0: Package. Detail.`); acceptance criteria as a checklist; non-goals; assumptions, marked as not confirmed; every other section as read-only text.
- **Publish** with `capabilities: { artifact: {}, comments: { composer_only: true } }`. A viewer who can edit changes the goal, decisions, criteria, non-goals and assumptions in place, and saving publishes a new version marked "edited here, not merged yet". The diagrams are rebuilt from the spec, never edited on the page.
- **One page per spec.** Keep its link in `specs/current.url`, one line (git ignores all of `specs/`, and the gate always allows it). The first publish writes it. Every change to the spec rebuilds the page and publishes it to that link (`url`), also in a later session. When no `specs/current.md` exists yet, delete a leftover `specs/current.url`; `finalize` deletes it with the spec's archive step.
- **Merge first.** When a notice says the page changed, and before each republish, read the live page with the Artifact tool's `read` action, then run `node <this folder>/spec-page.mjs merge specs/current.md <the saved file it names>`. It writes the page's edits into the spec and prints each one, or prints `no edits on the page`. It refuses when an edited page was built from another version of the spec; then merge the text by hand. A merge changes the spec, so its approval is gone.
- **Never approval.** The page has no approve button and says that approval is the reply typed in the terminal. Do not add one: the gate trusts only the typed phrase.

## Accuracy rules

People act on these pages. One invented number makes every other number on the page suspect.

- **Sourced.** Every fact traces to something you read or ran in this session, and the footer names those sources and the as-of date. Write dates as dates ("2 Nov 2026"), never "today".
- **Examples are labelled.** Made-up values (readings, counts, timings in a sketch) live only in a block tagged `<span class="ex">example values</span>`, and that section's `p.sub` says which values are made up and which are real. Generate them with `CrispChart.rng(seed)` so every viewer sees the same story, and make each caption and `aria-label` describe the data actually drawn.
- **No invented facts in a mock.** Only readings may be made up. Names, versions, thresholds, paths, ports, refresh rates and counts are real and sourced, even inside a sketch. A fact you have not read stays visibly unknown ("not checked") and goes under "Still open".
- **Unverified is said.** Anything assumed, planned but not built, or not checked shows as such: a "Still open" card, a `later` item in the link map, a status badge. Every link in a link map is a dependency you read in the source.
- **Terminal output is captured.** Run the program and keep its real ANSI frames.

## Data rules

A reader of a data page wants one value fast, with its unit, its source and where it sits against its limit. The parts do most of this when you pass them units, limits and sources.

- **A unit on every number:** in the table header, after the tile value, on the chart axis label, or as the panel header's `.pu`. A unit only in the prose does not count.
- **One format.** Numbers go through `CrispChart.fmt`: thousands separators, fixed decimals per column, a real minus, a space before the unit ("74 %", "16.30 s"). Dates read "2 Nov 2026", times are 24 h, and the time zone is named on the axis.
- **Missing is said, never 0.** A missing reading is a gap in a line, "no data" in a cell or tile, a hatched heatmap cell. Pass `null`, never 0 or a blank.
- **Color has one job per chart.** `--st-*` colors mean a state, and every state also shows an icon and a word (`.st` chips). `--s1` to `--s6` mean which series. Never mix the two in one chart. Text never takes a series color: names use the text color, joined to their line by a short colored key line.
- **Names at the line ends.** `chart.js` swaps in a legend only when the names do not fit. A one-series bar chart needs neither: the panel title names it.
- **Limits are drawn and named.** A limit is a dashed line or a shaded band with its label ("IDLE ≤ 30 %"). A tile or meter that judges a value shows its limits in words; with no limits, it shows no verdict.
- **Every chart has words and numbers.** An `aria-label` that says what the drawn data shows, a `.cap` sentence with the finding, and, for a key chart, its numbers in a `details.tv` table twin (`CrispChart.tableOf`).
- **Small text is `--muted`**, never `--faint`, so it stays readable in both themes.

## Page rules

The lint checks what a script can see; the preview look checks the layout.

- `<title>` is a name of 2 to 4 words. The explanation goes in the publish `description`.
- Colors come from `style.css` tokens. Data uses the data tokens: `--st-*` for states, `--s1` to `--s6` for series, `--q1` to `--q5` for heatmap steps. A new data color is a new token on bare `:root` and in both dark blocks, never a literal in a rule or a script; check it with the palette command in `style.css`. Clay is the one accent: eyebrow, focus ring, active and highlighted states.
- Dark mode works: tokens on bare `:root`, redefined with `color-scheme: dark` in both guards, `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }` and `:root[data-theme="dark"]`.
- Phone width works: the `.wrap` gutter (16px or the safe-area inset) and no sideways page scroll. Only tables, heatmaps, cell grids and terminals scroll sideways, inside their own box. Each part already stacks to one column.
- Interactions work by keyboard: charts and sort buttons take focus and show the clay focus ring, and the readout is read aloud. Keep that when you add your own.
- Scripts load only from the CDN allowlist (cdnjs, jsDelivr `/npm/`, unpkg, Tailwind's CDN, jQuery's CDN) at an exact `x.y.z` version. These parts need none.
- Copy is plain and direct, with no em dashes: use a colon, a comma or a new sentence. Address the reader as "you".

## Terminal output

Fonts draw block glyphs (`█ ▌ ▀ ▛ ▂`) with seams, and a glyph the font lacks comes from a fallback font that shifts it. `terminal.js` draws each block glyph as a CSS shape that fills its cell, and pins every other non-ASCII glyph to one 1ch cell. Capture finished frames (colors and styles are kept, cursor moves dropped), put `.term > .bar + .scr > .screen` on the page, and call `CrispTerm.render(screenEl, ansiText)` once per frame.

## Changing this skill

A part joins this folder once a real page has proved it. A new part gets a test in `check.mjs` and a demo in `gallery.html` or `example.html`. After any edit here, run `node check.mjs` in this folder and see PASS: it tests the scripts, the spec page and the lint, checks that `example.html` matches a fresh build of `example-spec.md`, and lints `example.html` and `gallery.html`. Rebuild the example with `node spec-page.mjs build example-spec.md example.html --date "2 Nov 2026" --example`.
