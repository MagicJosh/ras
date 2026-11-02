/* artifacts skill terminal renderer: ANSI text -> HTML rows on a fixed 1ch grid. Needs style.css's terminal rules.
   Block glyphs become CSS shapes that fill their cell exactly, the way a GPU terminal draws them. As font
   glyphs they leave seams, and glyphs the font lacks come from a fallback font that shifts them.
   Usage: CrispTerm.render(screenElement, ansiText) */
const CrispTerm = (() => {
  const rgb = (r, g, b) => `rgb(${r},${g},${b})`;
  const BASIC = ['#272822', '#f92672', '#a6e22e', '#f4bf75', '#66d9ef', '#ae81ff', '#a1efe4', '#f8f8f2',
    '#75715e', '#f92672', '#a6e22e', '#f4bf75', '#66d9ef', '#ae81ff', '#a1efe4', '#f9f8f5'];  // Monokai's 16
  const LEVEL = [0, 95, 135, 175, 215, 255];
  const c256 = n => n < 16 ? BASIC[n] : n > 231 ? rgb(8 + (n - 232) * 10, 8 + (n - 232) * 10, 8 + (n - 232) * 10)
    : rgb(LEVEL[Math.floor((n - 16) / 36)], LEVEL[Math.floor((n - 16) / 6) % 6], LEVEL[(n - 16) % 6]);

  // a fill growing from one side of the cell: [gradient direction, percent filled]
  const BLOCK = { '█': ['to top', 100], '▀': ['to bottom', 50], '▔': ['to bottom', 12.5], '▐': ['to left', 50], '▕': ['to left', 12.5] };
  [...'▁▂▃▄▅▆▇'].forEach((c, i) => { BLOCK[c] = ['to top', (i + 1) * 12.5]; });
  [...'▉▊▋▌▍▎▏'].forEach((c, i) => { BLOCK[c] = ['to right', (7 - i) * 12.5]; });
  // quadrants: bits 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right
  const QUAD = { '▘': 1, '▝': 2, '▖': 4, '▗': 8, '▚': 9, '▞': 6, '▙': 13, '▛': 7, '▜': 11, '▟': 14 };
  const QPOS = [[1, '0 0'], [2, '100% 0'], [4, '0 100%'], [8, '100% 100%']];

  /** Text -> rows of runs {t, fg, bg, bold, dim, italic, under}. Only SGR (ESC[...m) is kept; cursor moves
      and other escapes are dropped, so feed it finished frames, not a raw TUI stream. */
  function parse(text) {
    return text.replace(/\r/g, '').split('\n').map(line => {
      const runs = [];
      let st = {}, pos = 0;
      const push = t => { if (t) runs.push({ t, ...st }); };
      for (const m of line.matchAll(/\x1b\[([0-9;]*)([A-Za-z])/g)) {
        push(line.slice(pos, m.index));
        pos = m.index + m[0].length;
        if (m[2] !== 'm') continue;
        const c = m[1].split(';').map(Number);  // '' reads as 0, so a bare ESC[m resets
        for (let i = 0; i < c.length; i++) {
          const n = c[i];
          if (n === 0) st = {};
          else if (n === 1) st.bold = true;
          else if (n === 2) st.dim = true;
          else if (n === 22) st.bold = st.dim = false;
          else if (n === 3 || n === 23) st.italic = n === 3;
          else if (n === 4 || n === 24) st.under = n === 4;
          else if ((n >= 30 && n <= 37) || (n >= 90 && n <= 97)) st.fg = BASIC[n % 10 + (n >= 90 ? 8 : 0)];
          else if ((n >= 40 && n <= 47) || (n >= 100 && n <= 107)) st.bg = BASIC[n % 10 + (n >= 100 ? 8 : 0)];
          else if (n === 39) delete st.fg;
          else if (n === 49) delete st.bg;
          else if (n === 38 || n === 48) {
            const mode = c[i + 1], col = mode === 5 ? c256(c[i + 2]) : mode === 2 ? rgb(c[i + 2], c[i + 3], c[i + 4]) : null;
            if (col) st[n === 38 ? 'fg' : 'bg'] = col;
            i += mode === 5 ? 2 : mode === 2 ? 4 : 0;
          }
        }
      }
      push(line.slice(pos));
      return runs;
    });
  }

  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  function rowHTML(runs) {
    let h = '';
    for (const r of runs) {
      const fg = r.fg || 'var(--term-fg)', back = r.bg || 'transparent';
      const cls = [r.bold && 'b', r.dim && 'd', r.italic && 'i', r.under && 'u'].filter(Boolean).join(' ');
      const style = (r.fg ? `color:${r.fg};` : '') + (r.bg ? `background:${r.bg};` : '');
      let buf = '';
      const flush = () => { if (buf) h += `<span class="${cls}" style="${style}">${esc(buf)}</span>`; buf = ''; };
      for (const ch of r.t) {
        if (BLOCK[ch] || QUAD[ch]) {
          flush();
          const paint = BLOCK[ch] ? `linear-gradient(${BLOCK[ch][0]},${fg} ${BLOCK[ch][1]}%,${back} ${BLOCK[ch][1]}%)`
            : QPOS.filter(([bit]) => QUAD[ch] & bit).map(([, p]) => `linear-gradient(${fg},${fg}) ${p}/50% 50% no-repeat`).join(',') + ',' + back;
          h += `<span class="c" style="background:${paint}"> </span>`;
        } else if (ch.codePointAt(0) > 127) {
          // pin every other non-ASCII glyph to one cell, so a fallback font cannot push the grid
          // shortcut: wide glyphs (emoji, CJK) also get one cell, upgrade when a page needs them
          flush();
          h += `<span class="c ${cls}" style="${style}">${esc(ch)}</span>`;
        } else buf += ch;
      }
      flush();
    }
    return `<div class="row">${h || ' '}</div>`;
  }

  /** Draw ANSI text into a .screen element, sized to its widest row. */
  function render(el, text) {
    const rows = parse(text);
    el.style.setProperty('--cols', Math.max(1, ...rows.map(r => r.reduce((n, x) => n + [...x.t].length, 0))));
    el.innerHTML = rows.map(rowHTML).join('');
  }

  return { parse, rowHTML, render };
})();
