---
name: artifacts
description: Use when you build, restyle or check an HTML Artifact page, such as a spec page, plan, explainer, report, dashboard-style page or mock-up, or a page that shows numbers, tables, charts or terminal output. Gives the house look, ready parts, a guide per kind of page, accuracy rules, a spec page builder and a page lint.
---

# Artifacts

The house style for Artifact pages, and the rules that keep every fact on them true. This folder holds the parts that proved themselves on real pages, so a new page reuses them instead of reinventing them.

The Artifact flow still runs first: the quickstart or `artifact-design`, whose page contract holds in full. This skill replaces only the look, so it wins over generic advice to give each page a fresh identity. An Artifact made from a type (slides, docs, dashboard) keeps its type's look.

## Guides: one per kind of page

A guide is the recipe for one kind of page: its sections in order, the part for each section, a skeleton to copy, its own rules, and when it is done. Read the guide for your page before any markup.

| The page | Guide |
|---|---|
| Says what will be built: a plan, or a mock-up of a screen | [`guides/plan.md`](guides/plan.md) |
| Is the page of a ras spec (`specs/current.md`) | [`guides/spec-page.md`](guides/spec-page.md) |
| Explains how something works | [`guides/explainer.md`](guides/explainer.md) |
| Reports what was measured or found | [`guides/report.md`](guides/report.md) |
| Is full of numbers: a dashboard-style page, a status overview | [`guides/data-page.md`](guides/data-page.md) |
| Shows terminal, CLI or status line output | [`guides/terminal.md`](guides/terminal.md) |

A page that mixes kinds follows the guide of its main question and borrows sections from the others. **Any tile, table, chart, heatmap or meter, on any page, follows the data rules in [`guides/data-page.md`](guides/data-page.md):** read them before the first one.

## Parts: which part for which need

[`gallery.html`](gallery.html) shows every part below as a live demo with its markup and its call: read a part's section there before you use it. Each file's header lists every option of its calls.

| Need on the page | Part | Inline | Call |
|---|---|---|---|
| Every page: tokens, type, header, `.meta` status line, `footer` | page frame | `style.css`, all of it | |
| A few short notes side by side: findings, open items, things left out | cards | in `style.css` | `.grid > .card` with an `h4` |
| A small label: a state, a filter value, "example values", a meter | tags | `parts.css` "tags" | `.st`, `.chip`, `.ex`, `.cm` |
| A process in stages, A to B to C | stage strip | "stage strip" | |
| What feeds what: sources left, their users right | link map | "link map" + `linkmap.js` | `CrispMap.mount(el, left, right)` |
| A sketch of a screen or dashboard | mock dashboard | "mock dashboard", "panel grid", "cell grid" | |
| Work in waves or phases | build order | "build order" | |
| Questions only the reader can answer, each with a recommended answer | your call | "your call" + `ask.js` | `CrispAsk.mount(form)` |
| One decision's options against the same criteria | options board | "options board" | |
| The files a job touches: new, changed, deleted | change map | "change map" | |
| One case followed step by step through a process | walkthrough | "walkthrough", "stage strip", "spec table" + `walk.js` | `CrispWalk.mount(el)` |
| A few lines of a file with notes on the lines that matter, or a fix as removed and added lines | annotated code | "annotated code" | |
| A claim, its reasons, and the evidence for each | why chain | "why chain" | |
| A familiar picture mapped to the system pair by pair | analogy pairs | "analogy pairs" | |
| A few headline numbers, each against its limits | stat tiles | "stat tiles" + `chart.js` + `data.js` | `CrispData.tiles(el, list)` |
| Several panels sharing the page | panel grid | "panel grid" | `.gd > .panel.spanN` with a `.ph` header |
| Numbers over time, against limits or bands | line chart | "charts" + `chart.js` | `CrispChart.render(id, o)` |
| Amounts across categories: a ranking, a comparison, parts of a total | bar chart | "charts" + `chart.js` | `CrispChart.bars(id, o)` |
| A trend inside a tile or a table cell | sparkline | "charts" + `chart.js` | `CrispChart.spark(data, o)` |
| Many values to look up, compare or sort, rows by columns | data table | "data table" + `chart.js` + `data.js` | `CrispData.table(el, o)` |
| One thing's fixed facts: version, supply, limits | spec table | "spec table" | markup only |
| One value per cell of a grid | heatmap | "heatmap" + `chart.js` + `data.js` | `CrispData.heat(el, o)` |
| Terminal, CLI or status line output | terminal | in `style.css` + `terminal.js` | `CrispTerm.render(el, ansi)` |
| A spec as a page that can be edited in place | spec page | built whole by `spec-page.mjs` | [`guides/spec-page.md`](guides/spec-page.md) |

Every `parts.css` section needs the "tags" section. When a page needs something these parts lack, build it from the same tokens and type, inside that page.

## Build a page

1. **Pick the guide** from the table above and read it, then read the gallery section of each part it names. Done when you can name the page's sections in order and the part for each.
2. **Collect the facts.** Before any markup, list every number, name, version, path, limit and date the page will state, each with its source: a file:line, a command you ran and its output, or a doc URL. This list becomes the footer. Done when every planned fact has a source or is a labelled example (rules below).
3. **Start the file** with the page frame below.
4. **Compose** the guide's sections inside `<div class="wrap">`, each as `h2` + `p.sub` + content. Add "Still open" cards when anything is unverified, and "Left out on purpose" cards when you skip something the reader would expect.
5. **Script:** one `<script>` at the end with the helper files you use (`chart.js` before `data.js`), then the page's own calls.
6. **Lint:** run `node lint.mjs <page.html>` from this folder until it prints PASS. Then take the one preview look `artifact-design` allows (desktop and phone, light and dark), fix what it shows, and publish.

The page frame, the same on every page:

```html
<title>Two To Four Words</title>
<meta name="claude:viewport-fit-sides" content="cover">
<!-- the two font <link> lines from the header of style.css -->
<style>/* all of style.css, then the parts.css sections the page uses, "tags" first */</style>

<div class="wrap">
<header>
  <div class="eyebrow">project · topic</div>
  <h1>What the page answers</h1>
  <p class="lede">The answer in two sentences, with <b>the key facts</b> in bold.</p>
  <div class="meta"><span class="badge">status</span><span>the date, as "2 Nov 2026"</span></div>
</header>

<h2>Section</h2>
<p class="sub">What this section shows, and which of its values are made up.</p>
<!-- the guide's part for this section -->

<footer>Sources: <code>file:line</code>, <code>the command you ran</code>. As of [date].</footer>
</div>

<script>/* the helper files the page uses, then its own calls */</script>
```

## Accuracy rules

People act on these pages. One invented number makes every other number on the page suspect.

- **Sourced.** Every fact traces to something you read or ran in this session, and the footer names those sources and the as-of date. Write dates as dates ("2 Nov 2026"), never "today".
- **Examples are labelled.** Made-up values (readings, counts, timings in a sketch) live only in a block tagged `<span class="ex">example values</span>`, and that section's `p.sub` says which values are made up and which are real. Generate them with `CrispChart.rng(seed)` so every viewer sees the same story, and make each caption and `aria-label` describe the data actually drawn.
- **No invented facts in a mock.** Only readings may be made up. Names, versions, thresholds, paths, ports, refresh rates and counts are real and sourced, even inside a sketch. A fact you have not read stays visibly unknown ("not checked") and goes under "Still open".
- **Unverified is said.** Anything assumed, planned but not built, or not checked shows as such: a "Still open" card, a `later` item in the link map, a status badge. Every link in a link map is a dependency you read in the source.
- **Terminal output is captured.** Run the program and keep its real ANSI frames.

## Page rules

The lint checks what a script can see; the preview look checks the layout.

- `<title>` is a name of 2 to 4 words. The explanation goes in the publish `description`.
- Colors come from `style.css` tokens. Data uses the data tokens: `--st-*` for states, `--s1` to `--s6` for series, `--q1` to `--q5` for heatmap steps. A new data color is a new token on bare `:root` and in both dark blocks, never a literal in a rule or a script; check it with the palette command in `style.css`. Clay is the one accent: eyebrow, focus ring, active and highlighted states.
- Dark mode works: tokens on bare `:root`, redefined with `color-scheme: dark` in both guards, `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }` and `:root[data-theme="dark"]`.
- Phone width works: the `.wrap` gutter (16px or the safe-area inset) and no sideways page scroll. Only tables, heatmaps, cell grids and terminals scroll sideways, inside their own box. Each part already stacks to one column.
- Interactions work by keyboard: charts and sort buttons take focus and show the clay focus ring, and the readout is read aloud. Keep that when you add your own.
- Scripts load only from the CDN allowlist (cdnjs, jsDelivr `/npm/`, unpkg, Tailwind's CDN, jQuery's CDN) at an exact `x.y.z` version. These parts need none.
- Copy is plain and direct, with no em dashes: use a colon, a comma or a new sentence. Address the reader as "you".

## Changing this skill

A part joins this folder once a real page has proved it. A new part gets a test in `check.mjs` and a demo in `gallery.html`, in a block marked `data-part="<its parts.css section name>"`. A new kind of page gets a guide in `guides/` and a row in the guides table. A guide with a worked example keeps the example's sections in step with its table.

After any edit here, run `node check.mjs` in this folder and see PASS. It tests the scripts, the spec page and the lint, checks that `example.html` matches a fresh build of `example-spec.md`, lints `example.html`, `gallery.html` and the two worked examples (`example-plan.html`, `example-explainer.html`), checks that each worked example's sections are rows of its guide's table, in the guide's order, and checks that every guide is linked from this file, every link resolves, and every `parts.css` section has its demo. Rebuild the example with `node spec-page.mjs build example-spec.md example.html --date "2 Nov 2026" --example`.
