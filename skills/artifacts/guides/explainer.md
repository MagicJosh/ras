# Explainer page

An explainer shows how something works: a system, a flow, a file format, a decision. The reader wants the answer first and the detail after, and may stop after any section.

[`../gallery.html`](../gallery.html) shows every part named here with its markup: stage strip, link map, cards, spec table, terminal, analogy pairs, walkthrough, annotated code, why chain. [`../example-explainer.html`](../example-explainer.html) is a worked example of this guide.

## Sections, in order

Lead with the answer, then the mechanism, then the details. Use a section only when the subject has that content. The header and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What is this about, and what is the answer? | Page frame. The `h1` names the thing explained. The `.lede` gives the answer in two sentences, with `<b>` on the key facts. |
| The picture | What is it like, in something I already know? | Analogy pairs: 3 to 5 pairs, the picture left and the system right, then the note that says where the picture breaks. |
| How it flows | What happens, step by step? | Stage strip: 3 to 5 stages in the order the work passes through them. `.files` lists what each stage reads or writes. |
| Walk through it | What happens to one case, step by step? | Walkthrough: one case followed along a stage strip. Each step marks its stage and shows what it changed (`.d` on a changed value). Needs `walk.js`. A walkthrough holds its own stage strip, so a page with one can drop "How it flows". |
| What depends on what | Which piece uses which? | Link map: the sources left, their users right. |
| The pieces | What is each piece, in one idea? | Cards: one idea per card. The `h4` names it, one or two sentences explain it, a `pre` holds the one command or snippet that shows it. A piece that is a few lines of one file is shown as annotated code instead. |
| Why it is this way | Why was it built like this? | Why chain: a claim, then "because", "so" and "but" links under it. Each link names its evidence. |
| Fixed facts | Which version, limit, path or port? | Spec table: key and value. A fact you did not check reads "not checked" (`dd.unk`). |
| See it run | What does it print? | Terminal, with captured output: [`terminal.md`](terminal.md). |
| The numbers | How much, how fast, how often? | Tiles, a chart or a table, by the data rules in [`data-page.md`](data-page.md). |
| Still open | What did you not check? | Cards: one per open item, with what will settle it. |
| Footer | Where do these facts come from? | The sources and the as-of date. |

## Skeleton

The page frame around this is in `SKILL.md`. Each part's full markup is in the gallery and in the `parts.css` section of the same name.

```html
<h2>The picture</h2>
<p class="sub">One sentence: the picture, and what it stands for.</p>
<div class="ana">
  <div><span class="hd">The picture</span><span></span><span class="hd">The system</span></div>
  <div><span class="a">The picture's side of the pair</span><span class="eq">=</span><span class="b">The system's side</span></div>
</div>
<p class="note"><b>Where the picture breaks.</b> The first place it stops being true.</p>

<h2>How it flows</h2>
<p class="sub">One sentence: where the work starts and where it ends.</p>
<div class="pipe">
  <div class="card stage"><div class="k">1 · reads</div><div class="t">Name</div><p class="note">What it does.</p>
    <div class="files"><div class="f"><span>input.json</span><span>read</span></div></div></div>
  <div class="arrow" aria-hidden="true">→</div>
  <div class="card stage"><div class="k">2 · writes</div><div class="t">Name</div><p class="note">What it does.</p></div>
</div>

<h2>Walk through it</h2>
<p class="sub">One case, step by step. Say whether the case is real or an example.</p>
<div class="walk" id="walk">  <!-- the page's script calls CrispWalk.mount(document.getElementById('walk')) -->
  <div class="pipe">
    <div class="card stage" data-s="a"><div class="k">1 · reads</div><div class="t">Name</div></div>
    <div class="arrow" aria-hidden="true">→</div>
    <div class="card stage" data-s="b"><div class="k">2 · writes</div><div class="t">Name</div></div>
  </div>
  <ol class="steps">
    <li data-s="a"><button type="button" class="sb"><b>What happens in this step</b><span class="chip">Name</span></button>
      <p>The step in one or two sentences.</p>
      <dl class="spec"><div class="d"><dt>status</dt><dd>new value</dd></div><div><dt>count</dt><dd>0</dd></div></dl></li>
  </ol>
</div>

<h2>The pieces</h2>
<p class="sub">One idea per card.</p>
<div class="grid">
  <div class="card"><h4>Name of the piece</h4><p>What it is, in one or two sentences.</p><pre>the one command or snippet</pre></div>
</div>
<figure class="anno"><figcaption>app/file.py · lines 14 to 15</figcaption>
  <div class="code" tabindex="0" role="region" aria-label="file.py, lines 14 to 15, line 15 marked">
    <div class="l"><i>14</i><code>def next_try(count):</code></div>
    <div class="l mk"><i>15</i><code>    if count &gt;= LIMIT:</code><span class="pin">1</span></div>
  </div>
  <ol class="pins"><li><span><b>Line 15 is the stop.</b> Why it matters.</span></li></ol>
</figure>

<h2>Why it is this way</h2>
<p class="sub">The claim, and the reasons under it. Each link names its evidence.</p>
<ol class="why">
  <li><span class="w">claim</span><span>What is true.</span><span class="e"><span class="chip">read: file.py:12</span></span></li>
  <li><span class="w">because</span><span>The reason.</span><span class="e"><span class="st unknown">assumed</span></span></li>
  <li><span class="w">so</span><span>What follows.</span><span class="e"><span class="chip">follows from the line above</span></span></li>
</ol>

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
- **Every link in a why chain names its evidence:** read, ran, computed, follows from the line above, or assumed. An assumed link also gets a "Still open" card.
- **Every picture names where it breaks.** The note under the analogy pairs says so.
- **A walkthrough follows one case from start to end.** It says whether that case is real or an example.
- **Line numbers in annotated code are the file's own.**
- **A mechanism no part draws** (a state machine, a sequence, a layout) is an inline SVG built from the same tokens and type. Load the `artifact-diagramming` skill for it when it is available.

## Done when

A reader who stops after the header knows the answer, and one who reads on finds each section complete on its own. Every fact has a source in the footer, and every unchecked fact has a "Still open" card. `node lint.mjs <page>` prints PASS.
