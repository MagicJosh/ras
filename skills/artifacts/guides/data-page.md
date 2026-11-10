# Data page

A data page is full of numbers: a dashboard-style page, a status overview, a comparison. Its reader wants one value fast, with its unit, its source and where it sits against its limit. The parts do most of this when you pass them units, limits and sources.

The data rules below hold for every tile, table, chart, heatmap and meter, on any kind of page. [`../gallery.html`](../gallery.html) shows every case in this guide with example values, and the markup and call of each.

## Data rules

- **A unit on every number:** in the table header, after the tile value, on the chart axis label, or as the panel header's `.pu`. A unit only in the prose does not count.
- **One format.** Numbers go through `CrispChart.fmt`: thousands separators, fixed decimals per column, a real minus, a space before the unit ("74 %", "16.30 s"). Dates read "2 Nov 2026", times are 24 h, and the time zone is named on the axis.
- **Missing is said, never 0.** A missing reading is a gap in a line, "no data" in a cell or tile, a hatched heatmap cell. Pass `null`, never 0 or a blank.
- **Color has one job per chart.** `--st-*` colors mean a state, and every state also shows an icon and a word (`.st` chips). `--s1` to `--s6` mean which series. Never mix the two in one chart. Text never takes a series color: names use the text color, joined to their line by a short colored key line.
- **Names at the line ends.** `chart.js` swaps in a legend only when the names do not fit. A one-series bar chart needs neither: the panel title names it.
- **Limits are drawn and named.** A limit is a dashed line or a shaded band with its label ("IDLE ≤ 30 %"). A tile or meter that judges a value shows its limits in words; with no limits, it shows no verdict.
- **Every chart has words and numbers.** An `aria-label` that says what the drawn data shows, a `.cap` sentence with the finding, and, for a key chart, its numbers in a `details.tv` table twin (`CrispChart.tableOf`).
- **Small text is `--muted`**, never `--faint`, so it stays readable in both themes.

The sections from "Labels and formats" on give the detail and the reason behind each rule.

## Sections, in order

Go from "what is it now" to "how did it get there" to "which one exactly". Use a section only when the page has that content. The header and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What is this, for which period? | Page frame. The `.meta` line names the window, the time zone and the as-of date. |
| Now | What is it now, and is it fine? | Stat tiles. |
| Over time | How did it change? | Panel grid of charts. |
| Which one | Which one, and what are its numbers? | Data table. |
| Where | Where on the grid? | Heatmap. |
| Fixed facts | What is this thing? | Spec table. |
| Footer | Where do these numbers come from? | The sources and the as-of date. |

```html
<h2>Now</h2>
<p class="sub">What these numbers cover, and their source.</p>
<div class="tiles" id="kpi"></div>

<h2>Over time</h2>
<p class="sub">The window and the time zone.</p>
<div class="gd">
  <section class="panel span8">
    <div class="ph"><h3>What, for which thing</h3><span class="pu">unit, window</span><span class="ps">source</span></div>
    <svg class="ch" id="ch-main" viewBox="0 0 620 250" role="img" aria-label="What the drawn data shows, with its numbers."></svg>
    <div class="cap">One sentence with the finding and its numbers.</div>
    <details class="tv"><summary>Show the numbers</summary><div id="ch-main-t"></div></details>
  </section>
  <section class="panel span4">...a ranking beside it...</section>
</div>

<h2>Which one</h2>
<div id="t-detail"></div>
```

A report that leads with findings follows [`report.md`](report.md) and uses these same rules.

## Pick the part by the reader's question

| The reader asks | Part | Notes |
|---|---|---|
| What is it now, and is it fine? | stat tiles | 3 to 6 in a row. Pass `warn` and `crit` so the tile judges; without them it shows the value and no verdict. More than about 8: use a table. |
| Which one, and what are its numbers? | data table | Exact values, many columns, sorting. Put the name in a row header (`head: true`), group rows by what the reader scans by (`groups`), and highlight the one row the page is about (`highlight`). |
| What is this one thing? | spec table | Fixed facts: version, supply, limits, rates. A fact you did not check says "not checked" (`dd.unk`). |
| How did it change over time? | line chart | `step: true` for a value that holds until the next reading. `lo`/`hi` for a range around an average. `events` for something that happened at a time. `bands` and `limits` for thresholds. |
| Which is biggest? | horizontal bars | Sorted largest first. Long category names fit on the left. |
| How do a few groups compare? | grouped vertical bars | Up to 3 series when the reader compares every pair. |
| What makes up the total? | stacked bars | Up to 4 segments, the biggest first, at the bottom. The readout adds a total row. |
| Where on the grid? | heatmap | Each cell prints its name and value; the color only helps find highs and lows. Mark the cell the caption talks about. |
| Which way is it heading? (inside a tile or cell) | sparkline | Shape only, with the newest value as a dot. The number sits beside it. |

A chart answers "how" and "which way". When the reader needs the exact value, add a table twin: `CrispData.table(el, CrispChart.tableOf(o, 'caption'))` inside `<details class="tv">`.

## Panels on the grid

The panel grid has 12 columns. Common splits:

- A wide time series: `span8` or `span12`. A ranking beside it: `span4`.
- Two charts the reader compares: `span6` + `span6`, with the same y range when they show the same quantity.
- Small bar charts: `span3` each.

On a tablet (1000 px and narrower), `span2` widens to 4 columns, `span3` and `span4` to 6, and wider spans fill the row. On a phone (760 px and narrower), every panel fills the row. Chart text stays 10.5 px at every width (11 px on a phone), because `chart.js` redraws each chart at its panel's real width.

Each panel starts with a `.ph` header:

- `h3`: what, for which thing ("Build time per day, host C3"). The unit is left out of the title.
- `.pu`: the unit, and the window if there is one ("jobs, last 30 d").
- `.ex`: when the panel holds made-up values.
- `.ps`: the source, pushed to the right.

Under the chart, one `.cap` sentence says the finding, with the numbers ("Rack 3 drops to about 40 an hour from 15:00").

## Labels and formats

- **Axis labels** carry the quantity and unit once ("open time, s"), so tick labels are bare numbers. The time axis label names the zone ("time, UTC"). `chart.js` dates use `en-GB` with UTC by default, so every viewer reads the same times.
- **Table headers** carry the unit under the label (`unit`). Each number column has fixed decimals (`dp`), so the decimal points line up.
- **Numbers** use thousands commas and a decimal point (22,317.5), a space before every unit including % ("74 %"), and a real minus sign (−3). Compact numbers (12.9K) only appear on axis ticks.
- **Limits** are written out: "warn ≥ 80 %, alarm ≥ 90 %". The limit value itself counts as reached. Pass `dir: 'down'` when a low value is the bad one.
- **States** use the words ok, warn, alarm, off and unknown, or the domain's own words through `tones` (active, paused, flagged, inactive). Each one also has an icon shape: ● ▲ ■ ○ ?.
- **Deltas** on a tile show an arrow, the signed value, what it compares against ("vs 1 Nov") and "better" or "worse" in words. The direction never rests on the color.

## Color: the dataviz method on these tokens

The `dataviz` skill gives a method and a placeholder palette. Here the method runs on this house style's tokens instead of replacing them.

- **Series, `--s1` to `--s6`.** The house hues and their order were kept. Their lightness and chroma were adjusted until the dataviz palette check passed in light and dark, on both `--panel` and `--bg`. The check covers the lightness band, the chroma floor, separation for color-blind readers, separation for normal vision, and contrast against the surface. The command is in `style.css` above the tokens: run it again after changing any series color.
- **Heatmap, `--q1` to `--q5`.** One teal hue, light to dark. In dark mode the scale flips, so high is still the brightest. Text is `--text` on `--q1` to `--q3` and `--panel` on `--q4` and `--q5`. The contrast was checked at that step in both themes.
- **States, `--st-*`.** These are unchanged. They always show with an icon and a word.
- **`--s1` and `--st-active` are different teals.** `--s1` was adjusted for series use. Keep each one for its own job.
- **Text never takes a series color.** Thin colored text fails contrast. Line-end names use the text color, and a 2 px key line in the series color joins each name to its line.
- **Legend only as a fallback.** The dataviz skill always shows a legend. This house style puts names at the line ends instead. `chart.js` switches to a legend when the longest name plus its key line is wider than the right margin (`right`, default 54 px), or when the names do not fit 11 px apart.
- **Marks.** Lines are 2 px. Bars are at most 24 px thick, with a 2 px gap between touching bars and between stacked segments, and rounded only at the data end. Shaded bands use 10 % opacity, range bands 16 %.
- **Readout.** A crosshair with a dot on each series. The values come first, the names after. It is built with `textContent`, so data never runs as markup.

## Accessibility built into the parts

- **Charts:** `role="img"` and an `aria-label` that says what the drawn data shows (the lint checks both). Each chart takes focus. The arrow keys move the readout, Home and End jump, and Esc hides it. A live region reads the readout aloud on keyboard moves only, and the visual tooltip is hidden from screen readers so nothing is read twice.
- **Tables:** a real `<table>` with a caption, row and column headers, and sort buttons in the headers that update `aria-sort`. The scroll box is a focusable region with its own label, so a keyboard user can scroll it sideways.
- **Heatmap:** a table. Every cell holds its name and value as text, and a marked cell says so to a screen reader.
- **Meters** are hidden from screen readers. The number beside a meter carries the value, and a warn or alarm also shows its icon.

## Known limits

- **Daylight saving.** Time ticks read the zone offset once per axis. A local-time axis that spans a daylight saving change can put ticks an hour off for part of the axis. The default UTC is never affected.
- **Bars start at 0.** There are no negative bars, diverging scales, scatter plots or pies. Show parts of a total as stacked bars.
- **Hidden bar values.** A vertical bar's value label is left out when it is wider than its bar's slot. The readout still shows it.
- **Estimated text width.** Label room is estimated at 6.3 px per character, not measured. A label with very wide characters can run slightly past its slot.
- **Page-wide class names.** `.ok`, `.warn`, `.crit`, `.off` and `.unknown` set a `--tone` variable wherever they appear, so do not reuse these names for other things on a page that inlines the "tags" section.

## Done when

Every number has its unit and its source on the page, every chart has an `aria-label`, a `.cap` and (for a key chart) a table twin, and every made-up value sits in a block tagged `.ex`. `node lint.mjs <page>` prints PASS.
