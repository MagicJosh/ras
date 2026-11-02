# Data pages

How to lay out a page full of numbers with the parts of this skill, and why the data rules in `SKILL.md` are what they are. `gallery.html` shows every case below with example values.

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
