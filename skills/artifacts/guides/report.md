# Report page

A report says what was measured or found: a test run, an audit, an incident, a benchmark. The reader wants the verdict first, then the evidence, then the detail to look things up.

Every tile, chart and table here follows the data rules in [`data-page.md`](data-page.md): read it before the first one. [`../gallery.html`](../gallery.html) shows every part named here with its markup and call.

## Sections, in order

Use a section only when the report has that content. The header, the findings, "Still open" and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What did you find? | Page frame. The `h1` states the main finding, with its number. The `.badge` gives the verdict in the report's own word: "passed", "2 failed", "needs review". The `.meta` line names the period covered and the date. |
| Headline numbers | How big is it? | Stat tiles: 3 to 6. Pass `warn` and `crit` where a limit exists, so the tile judges the value. |
| Findings | What exactly, in order of weight? | Cards: one finding per card, the heaviest first. The `h4` says the finding. The body gives the number that proves it and where it came from. |
| Evidence | What does the data look like? | Panel grid of charts. Each `.cap` states what its chart shows, with the numbers. A key chart gets a table twin. |
| The detail | Which one, and what are its values? | Data table: sortable, grouped by what the reader scans by, with the row the report is about highlighted. |
| Method | How was this measured? | Spec table: the period, the tool and its version, the command, what was excluded. |
| Still open | What could not be measured or explained? | Cards: one per open item, with what will settle it. |
| Footer | Where do these numbers come from? | The sources and the as-of date. |

## Skeleton

The page frame around this is in `SKILL.md`. Each part's markup and call are in the gallery and in the header of `chart.js` and `data.js`.

```html
<h2>Headline numbers</h2>
<p class="sub">The window these numbers cover, and their source.</p>
<div class="tiles" id="kpi"></div>

<h2>Findings</h2>
<div class="grid">
  <div class="card"><h4>The finding, in a few words</h4><p>The number that proves it, with its unit.</p><p class="note">Source: file or command.</p></div>
</div>

<h2>Evidence</h2>
<p class="sub">What the charts cover.</p>
<div class="gd">
  <section class="panel span8">
    <div class="ph"><h3>What, for which thing</h3><span class="pu">unit, window</span><span class="ps">source</span></div>
    <svg class="ch" id="ch-main" viewBox="0 0 620 250" role="img" aria-label="What the drawn data shows, with its numbers."></svg>
    <div class="cap">The finding this chart supports, with the numbers.</div>
    <details class="tv"><summary>Show the numbers</summary><div id="ch-main-t"></div></details>
  </section>
</div>

<h2>The detail</h2>
<div id="t-detail"></div>

<h2>Method</h2>
<div class="panel"><dl class="spec"><div><dt>Period</dt><dd>1 Nov to 2 Nov 2026</dd></div><div><dt>Tool</dt><dd>name 1.4.2</dd></div></dl></div>
```

## Rules for a report

- **Every value is measured.** A report holds values you read from a file or a command's output in this session. A value you lack reads "no data", and the gap goes under "Still open".
- **The finding is in the heading.** The `h1`, each card's `h4` and each `.cap` state a result ("Rack 3 lost half its throughput from 15:00"), where a topic ("Throughput") would make the reader work it out.
- **One number, one spelling.** A number in a finding card appears with the same digits and unit in a tile, a chart or the table. Format all of them with `CrispChart.fmt`.
- **The verdict has a rule.** A "passed" or "failed" badge names its limit somewhere on the page: in a tile's limits, a chart's limit line, or the method table.

## Done when

The header alone tells the reader the result. Each finding card points at a number that the page also shows in a tile, chart or table. Every value has a source in the footer. `node lint.mjs <page>` prints PASS.
