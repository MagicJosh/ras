# Plan page

A plan page shows what will be built before it is built, so the reader can approve it or change it. A mock-up of a screen is the "What you will see" section on its own. For a ras spec (`specs/current.md`), build the spec page instead: [`spec-page.md`](spec-page.md).

[`../gallery.html`](../gallery.html) shows every part named here with its markup: stage strip, link map, mock dashboard, cell grid, build order, cards.

## Sections, in order

Use a section only when the plan has that content. The header, "Still open" and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What is this, and what state is it in? | Page frame. The `h1` names what the plan delivers. The `.badge` says the state: "waiting for approval", "approved", "in progress". The `.meta` line adds the date and the branch. |
| The path | How does it work, end to end? | Stage strip: 3 to 5 stages, with `.hl` on each stage this job adds or changes. |
| The map | What feeds what? | Link map: what exists on the left, what uses it on the right, `later: true` on what comes after this job. Put the `.legend` above it. |
| What you will see | What will it look like? | Mock dashboard: one `.mock` per screen, each with an `.ex` tag in its `.mbar`. |
| Build order | What happens first, and what runs side by side? | Build order: one `.wave` per step that must finish before the next starts, `.pk.gate` for a review or an approval. |
| Left out on purpose | Why is X missing? | Cards: one per thing the reader would expect, with the reason. |
| Still open | What is not decided or not checked yet? | Cards: one per open item, with what will settle it. |
| Footer | Where do these facts come from? | The sources and the as-of date. |

## Skeleton

The page frame around this is in `SKILL.md`. Each part's full markup is in the gallery and in the `parts.css` section of the same name.

```html
<h2>The path</h2>
<p class="sub">One sentence: how the pieces pass the work along.</p>
<div class="pipe">
  <div class="card stage"><div class="k">1 · writes</div><div class="t">Name</div><p class="note">What it does.</p></div>
  <div class="arrow" aria-hidden="true">→</div>
  <div class="card stage hl"><div class="k">2 · new in this job</div><div class="t">Name</div><p class="note">What changes.</p></div>
</div>

<h2>The map</h2>
<p class="sub">Left: what exists. Right: what this job builds. Point at a box to see its links.</p>
<div class="legend"><span><i></i>built now</span><span><i class="dash"></i>planned after</span><span><i class="hot"></i>the one you point at</span></div>
<div class="map" id="map"></div>

<h2>What you will see</h2>
<p class="sub">A sketch of the screen. The numbers are made up and tell one story: [the story]. The names and limits are the real ones from [source].</p>
<div class="mock">
  <div class="mbar"><b>Screen name</b><span class="ex">example values</span><span class="r">window · refresh rate</span></div>
  <div class="gd"><div class="gp span4"><div class="gt">Panel title <span>its source</span></div><div class="big">42</div><div class="small">detail line</div></div></div>
</div>

<h2>Build order</h2>
<p class="sub">Who does the work, and when a wave may start.</p>
<div class="waves">
  <div class="wave"><div class="wk"><span>Wave 0</span><span>parallel</span></div><div class="pk"><b>A</b>Task name<div class="pd">what it delivers</div></div></div>
  <div class="wave"><div class="wk"><span>Wave 1</span><span>gate</span></div><div class="pk gate"><b>R</b>Review<div class="pd">what must hold before the work is done</div></div></div>
</div>

<h2>Left out on purpose</h2>
<div class="grid"><div class="card"><h4>The thing</h4><p class="note">Why the plan skips it.</p></div></div>

<h2>Still open</h2>
<div class="grid"><div class="card"><h4>The question</h4><p class="note">What is unknown, and what will settle it.</p></div></div>
```

## Rules for a plan

- **The mock tells one story.** Pick one example situation, such as one queue stalled at 14:02. Every mock, caption and `aria-label` shows that same situation. The section's `p.sub` says what the story is, which values are made up and which are real.
- **Real names in the mock.** The accuracy rules in `SKILL.md` apply inside a sketch: only readings are made up.
- **Every link is read.** A link in the map is a dependency you saw in the source. A guessed link goes under "Still open".
- **A wave has a start condition.** The `p.sub` of "Build order" says what must be true before the next wave starts, such as merged and tests green.
- **Charts in a mock** follow the data rules in [`data-page.md`](data-page.md).

## Done when

Each section answers its question without the reader opening another file. Every planned thing that is not built yet reads as planned, and every unchecked fact has a "Still open" card. `node lint.mjs <page>` prints PASS.
