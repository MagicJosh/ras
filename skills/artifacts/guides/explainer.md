# Explainer page

An explainer shows how something works: a system, a flow, a file format, a decision. The reader wants the answer first and the detail after, and may stop after any section.

[`../gallery.html`](../gallery.html) shows every part named here with its markup: stage strip, link map, cards, spec table, terminal.

## Sections, in order

Lead with the answer, then the mechanism, then the details. Use a section only when the subject has that content. The header and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What is this about, and what is the answer? | Page frame. The `h1` names the thing explained. The `.lede` gives the answer in two sentences, with `<b>` on the key facts. |
| How it flows | What happens, step by step? | Stage strip: 3 to 5 stages in the order the work passes through them. `.files` lists what each stage reads or writes. |
| What depends on what | Which piece uses which? | Link map: the sources left, their users right. |
| The pieces | What is each piece, in one idea? | Cards: one idea per card. The `h4` names it, one or two sentences explain it, a `pre` holds the one command or snippet that shows it. |
| Fixed facts | Which version, limit, path or port? | Spec table: key and value. A fact you did not check reads "not checked" (`dd.unk`). |
| See it run | What does it print? | Terminal, with captured output: [`terminal.md`](terminal.md). |
| The numbers | How much, how fast, how often? | Tiles, a chart or a table, by the data rules in [`data-page.md`](data-page.md). |
| Still open | What did you not check? | Cards: one per open item, with what will settle it. |
| Footer | Where do these facts come from? | The sources and the as-of date. |

## Skeleton

The page frame around this is in `SKILL.md`. Each part's full markup is in the gallery and in the `parts.css` section of the same name.

```html
<h2>How it flows</h2>
<p class="sub">One sentence: where the work starts and where it ends.</p>
<div class="pipe">
  <div class="card stage"><div class="k">1 · reads</div><div class="t">Name</div><p class="note">What it does.</p>
    <div class="files"><div class="f"><span>input.json</span><span>read</span></div></div></div>
  <div class="arrow" aria-hidden="true">→</div>
  <div class="card stage"><div class="k">2 · writes</div><div class="t">Name</div><p class="note">What it does.</p></div>
</div>

<h2>The pieces</h2>
<p class="sub">One idea per card.</p>
<div class="grid">
  <div class="card"><h4>Name of the piece</h4><p>What it is, in one or two sentences.</p><pre>the one command or snippet</pre></div>
</div>

<h2>Fixed facts</h2>
<div class="panel">
  <dl class="spec">
    <div><dt>Version</dt><dd>1.4.2</dd></div>
    <div><dt>Timeout</dt><dd>30 <small>s</small></dd></div>
    <div><dt>Retry limit</dt><dd class="unk">not checked</dd></div>
  </dl>
</div>
```

## Rules for an explainer

- **The answer comes first.** The `h1` and the `.lede` answer the question on their own. The sections below add how and why.
- **One idea per card.** A card that needs a second heading is two cards.
- **Code is copied from the source.** A command or snippet in a `pre` is one you ran or read in this session, with its file in the footer.
- **A mechanism no part draws** (a state machine, a sequence, a layout) is an inline SVG built from the same tokens and type. Load the `artifact-diagramming` skill for it when it is available.

## Done when

A reader who stops after the header knows the answer, and one who reads on finds each section complete on its own. Every fact has a source in the footer, and every unchecked fact has a "Still open" card. `node lint.mjs <page>` prints PASS.
