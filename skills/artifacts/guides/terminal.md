# Terminal page

A terminal page shows what a program prints: a CLI's output, a TUI screen, a status line, or several variants of one. The reader wants to see the real output, as their terminal would draw it.

[`../gallery.html`](../gallery.html) shows the terminal, the `.mini` rows and the variant pill with their markup and calls.

## Why a renderer

Fonts draw block glyphs (`█ ▌ ▀ ▛ ▂`) with seams, and a glyph the font lacks comes from a fallback font that shifts it. `terminal.js` draws each block glyph as a CSS shape that fills its cell, and pins every other non-ASCII glyph to one 1ch cell. It keeps colors and styles (bold, dim, italic, underline; 16, 256 and true colors) and drops cursor moves.

## Capture the frames

1. Run the program with color forced on, and send its output to a file. A program that redraws its screen needs one finished screen per frame, since cursor moves are dropped.
2. Put the frames in the page's script as strings with their `\x1b[` codes intact, or as JSON in a `<script type="application/json">`.
3. Note for the footer: the command, the terminal width in columns, and the date.

Done when every frame on the page came out of the program, at the width the `.lede` names.

## Sections, in order

Use a section only when the page has that content. The header, the live view and the footer are always there.

| Section | The reader asks | Part |
|---|---|---|
| Header | What program is this, and what am I looking at? | Page frame. The `.lede` names the program, the width in columns, and how the frames were made. |
| The live view | What does it look like? | One `.term`. Several frames play in place, with a Pause `.btn` and an `input[type=range]` to step through them. |
| Variants or moments | How does it compare, or change? | `.mini` rows: one small terminal per variant or per moment, each with a `.lbl`. A `button.mini` selects that variant, and `.on` marks the chosen one. |
| The pill | Which one am I on? | `.sw`: a fixed pill at the bottom with ← and →, the name and one dot per variant. Use it when the page compares three or more variants. |
| Notes | What should I notice in this one? | Cards for the chosen variant: what it shows, what it costs, when to pick it. |
| Using it | How do I run or switch it? | Cards with the command in a `pre` and the keys as `kbd`. |
| Footer | Where does this output come from? | The command, the width and the as-of date. |

## Skeleton

The page frame around this is in `SKILL.md`. The terminal rules are in `style.css`, which every page inlines whole; add `terminal.js` to the page's script.

```html
<div class="term">
  <div class="bar"><i></i><i></i><i></i><span class="ttl">program · folder</span><span class="tag">variant A</span></div>
  <div class="scr"><div class="screen" id="stage" role="img" aria-label="What this frame shows, in words."></div></div>
</div>

<h2>All variants</h2>
<p class="sub">Click one to select it.</p>
<div class="grid">
  <button type="button" class="mini on" aria-pressed="true"><div class="lbl"><b>A</b><span>one line</span></div>
    <div class="scr"><div class="screen" id="mini-a"></div></div></button>
</div>

<nav class="sw" aria-label="Variant switcher">
  <button type="button" aria-label="Previous variant">←</button>
  <div class="now"><div><b>A</b>one line</div><div class="dots"><i class="on"></i><i></i><i></i></div></div>
  <button type="button" aria-label="Next variant">→</button>
</nav>

<script>
/* terminal.js here, then: */
CrispTerm.render(document.getElementById('stage'), frames[0]);  /* once per frame; it sets the width to the widest row */
</script>
```

## Rules for a terminal page

- **Output is captured.** Every frame is the program's own output. A frame you typed by hand is an example and wears the `.ex` tag.
- **A frame says what it shows.** Each `.screen` has `role="img"` and an `aria-label` that describes the frame in words. Update the label when the frame changes.
- **Motion can stop.** A page that plays frames has a Pause button, and starts paused when `matchMedia('(prefers-reduced-motion: reduce)')` matches.
- **The terminal stays dark** in both themes: terminal colors are made for a dark background, and `style.css` keeps its own `--term-*` tokens for it.
- **Controls are the page's own.** The row that holds the Pause button and the slider is page CSS, built from the tokens. The button is `.btn`, and the slider takes the clay accent from `style.css`.

## Done when

Every frame is captured and drawn by `CrispTerm.render`, each `.screen` has a label that matches its frame, and the footer names the command, the width and the date. `node lint.mjs <page>` prints PASS.
