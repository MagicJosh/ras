/* artifacts skill data parts: stat tiles, data tables and heatmaps, rendered from plain rows so every number on the
   page is formatted one way. Needs chart.js inlined first (CrispChart.fmt, .spark) and parts.css's "tags", "stat tiles",
   "data table" and "heatmap" sections. Names and values go in escaped; only an html(v, row) cell is trusted markup.

   STATE    CrispData.state(74, { warn: 80, crit: 90 }) -> 'ok'; dir: 'down' when low is bad; null -> 'unknown'.
            CrispData.chip('warn', 'paused') -> <span class="st warn">paused</span>: an icon shape plus the word.
   TILES    <div class="tiles" id="kpi"></div>
            CrispData.tiles('kpi', [{ label: 'Disk used', value: 74, unit: '%', dp: 0, warn: 80, crit: 90, max: 100,
              src: 'System metrics', delta: 3, deltaText: 'since 1 Oct', better: 'down', spark: [70, 71, 74] }]);
            value null -> an UNKNOWN tile reading "no data" (since: 'last reading 14:03'), never a 0. max: adds a meter.
   TABLE    <div id="t-diag"></div>
            CrispData.table('t-diag', { caption: 'Latest check per host', source: 'Health checks', ex: true,
              cols: [{ key: 'host', label: 'Host', head: true, mono: true },  // row header: stays put when the box scrolls
                     { key: 'jobs', label: 'Jobs', unit: 'count', dp: 0 },  // numbers: right-aligned, fixed decimals
                     { key: 'state', label: 'State', type: 'state', tones: { active: 'ok', paused: 'warn', flagged: 'crit' } },
                     { key: 'disk', label: 'Disk', unit: '%', dp: 0, type: 'meter', max: 100, warn: 80, crit: 90 },
                     { key: 'trend', label: 'Last 30 d', type: 'spark', unit: 's', dp: 2 },   // an array of numbers
                     { key: 'link', label: 'Log', html: (v, row) => `<a href="${v}">log</a>` }],  // trusted escape hatch
              rows: [...],   or   groups: [{ label: 'Rack 1', rows: [...] }],   // groups sort inside themselves
              highlight: row => row.host === 'E1', foot: { host: 'All', jobs: 1234 }, sort: true });
            A header button sorts: numbers start largest first, text A to Z; missing values always sort last.
   HEATMAP  <div id="heat"></div>
            CrispData.heat('heat', { rows: ['Rack 1'], notes: ['4.2 kW'], cols: ['A', 'B'], data: [[23104, null]],
              names: (r, c) => 'AB'[c] + (r + 1), edges: [21000, 22000, 23000, 24000], dp: 0, unit: 'jobs',
              mark: (r, c) => false, caption, source, ex });  // edges: 4 cut points -> 5 steps; default: even steps */
const CrispData = (() => {
  const C = CrispChart;
  const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  const ok = v => v != null && !Number.isNaN(v);
  const get = el => typeof el === 'string' ? document.getElementById(el) : el;
  const WORD = { ok: 'ok', warn: 'warn', crit: 'alarm', off: 'off', unknown: 'unknown' };

  /** Where v sits against its limits: 'ok' | 'warn' | 'crit' | 'unknown'. dir 'up' (default): higher is worse. */
  function state(v, lim = {}) {
    if (!ok(v)) return 'unknown';
    const worse = (a, b) => lim.dir === 'down' ? a <= b : a >= b;
    if (ok(lim.crit) && worse(v, lim.crit)) return 'crit';
    if (ok(lim.warn) && worse(v, lim.warn)) return 'warn';
    return 'ok';
  }
  const chip = (tone, word) => `<span class="st ${tone}">${esc(word ?? WORD[tone])}</span>`;
  /** The limits in words: 'warn ≥ 80 %, alarm ≥ 90 %'. */
  function limits(lim, unit, dp) {
    const sym = lim.dir === 'down' ? '≤' : '≥', f = v => C.fmt(v, { dp, unit });
    return [ok(lim.warn) && `warn ${sym} ${f(lim.warn)}`, ok(lim.crit) && `alarm ${sym} ${f(lim.crit)}`].filter(Boolean).join(', ');
  }
  const pct = (v, lo, hi) => Math.max(0, Math.min(100, ((v - lo) / ((hi - lo) || 1)) * 100)).toFixed(1);
  /** A small bar for v on min..max (default 0..100) with a tick at each limit; the tone colors the fill. */
  function meter(v, o, tone) {
    const lo = o.min ?? 0, hi = o.max ?? 100;
    return `<span class="cm ${tone}" aria-hidden="true"><i style="width:${pct(v, lo, hi)}%"></i>${
      [o.warn, o.crit].filter(ok).map(x => `<b style="left:${pct(x, lo, hi)}%"></b>`).join('')}</span>`;
  }

  /** One stat tile's HTML. Without warn or crit a known value gets no state: nobody judged it. tone overrides. */
  function tile(o) {
    const known = ok(o.value), lim = limits(o, o.unit, o.dp), f = v => C.fmt(v, { dp: o.dp });
    const tone = o.tone || (!known ? 'unknown' : lim ? state(o.value, o) : '');
    let h = `<div class="tile${tone ? ' ' + tone : ''}"><div class="tl"><span>${esc(o.label)}</span>${o.src ? `<span class="src">${esc(o.src)}</span>` : ''}</div>`;
    h += known ? `<div class="tv">${esc(f(o.value))}${o.unit ? `<small>${esc(o.unit)}</small>` : ''}</div>` : '<div class="tv">no data</div>';
    if (known && ok(o.max)) h += meter(o.value, o, tone);
    if (tone) h += `<div class="tm">${chip(tone, o.stateText)}<span>${esc(known ? lim : o.since || 'no reading to show')}</span></div>`;
    if (known && ok(o.delta)) {
      const good = o.better && o.delta ? (o.better === 'up') === (o.delta > 0) : null;
      h += `<div class="td"><span class="ar${good == null ? '' : good ? ' good' : ' bad'}" aria-hidden="true">${
        o.delta > 0 ? '▲' : o.delta < 0 ? '▼' : '='}</span> ${esc(C.fmt(o.delta, { dp: o.dp, sign: true, unit: o.deltaUnit ?? o.unit }))}${
        o.deltaText ? ' ' + esc(o.deltaText) : ''}${good == null ? '' : good ? ', better' : ', worse'}</div>`;
    }
    if (o.spark) h += C.spark(o.spark, { w: 120, h: 26, fmt: v => C.fmt(v, { dp: o.dp, unit: o.unit }), limit: o.warn });
    return h + '</div>';
  }
  const tiles = (el, list) => { get(el).innerHTML = list.map(tile).join(''); };

  /** rows sorted by key, stable; missing values last in both directions; text compares A2 before A10. */
  function sortRows(rows, key, dir = 'asc', num = false) {
    const s = dir === 'desc' ? -1 : 1, miss = v => !ok(v) || v === '';
    return rows.map((r, i) => [r, i]).sort(([a, i], [b, j]) => {
      const x = a[key], y = b[key];
      if (miss(x) || miss(y)) return (miss(x) - miss(y)) || i - j;
      return (num ? x - y : String(x).localeCompare(String(y), 'en', { numeric: true })) * s || i - j;
    }).map(([r]) => r);
  }

  const caption = o => o.caption || o.source || o.ex ? `<caption>${o.caption ? `<span class="ct">${esc(o.caption)}</span>` : ''}${
    o.ex ? ' <span class="ex">example values</span>' : ''}${o.source ? `<span class="cs">Source: ${esc(o.source)}</span>` : ''}</caption>` : '';

  /** Render a sortable data table into el (element or id); el becomes its scroll box. */
  function table(el, o) {
    el = get(el);
    const cols = o.cols, groups = o.groups || [{ rows: o.rows }];
    const num = c => c.type === 'num' || c.type === 'meter' || ok(c.dp) ||
      (!c.type && !c.html && groups.some(g => g.rows.some(r => typeof r[c.key] === 'number')));
    const canSort = c => o.sort !== false && (c.sort ?? (c.type !== 'spark' && !c.html));
    let key = o.sortKey ?? null, dir = o.sortDir || 'asc';
    const cell = (c, r) => {
      const v = r[c.key];
      if (c.html) return c.html(v, r);
      if (c.type === 'state') return ok(v) ? chip((c.tones || {})[v] || (WORD[v] ? v : 'off'), v) : chip('unknown');
      if (c.type === 'spark') return Array.isArray(v) ? C.spark(v, { fmt: x => C.fmt(x, { dp: c.dp, unit: c.unit }), ...c.spark }) : '<span class="na">no data</span>';
      if (!ok(v)) return `<span class="na">${esc(c.empty || 'no data')}</span>`;
      if (c.type === 'meter') {
        const tone = state(v, c);
        return esc(C.fmt(v, { dp: c.dp })) + meter(v, c, tone) +
          (tone === 'warn' || tone === 'crit' ? `<span class="st i ${tone}"><span class="vh">${WORD[tone]}</span></span>` : '');
      }
      return esc(num(c) ? C.fmt(v, { dp: c.dp }) : v);
    };
    const row = r => {
      const hl = o.highlight && o.highlight(r);
      return `<tr${hl ? ' class="hl"' : ''}>${cols.map((c, j) => {
        const cls = [num(c) && 'n', c.mono && 'm'].filter(Boolean).join(' '), a = cls ? ` class="${cls}"` : '';
        const body = cell(c, r) + (hl && j === 0 ? '<span class="vh"> (highlighted)</span>' : '');
        return c.head ? `<th scope="row"${a}>${body}</th>` : `<td${a}>${body}</td>`;
      }).join('')}</tr>`;
    };
    const th = (c, j) => {
      const on = c.key === key, label = esc(c.label), unit = c.unit ? `<span class="u">${esc(c.unit)}</span>` : '';
      const inner = canSort(c) ? `<button type="button" data-k="${j}">${label}<span class="si" aria-hidden="true">${
        on ? (dir === 'asc' ? '▲' : '▼') : '↕'}</span>${unit}</button>` : label + unit;
      return `<th scope="col"${num(c) ? ' class="n"' : ''}${on ? ` aria-sort="${dir === 'asc' ? 'ascending' : 'descending'}"` : ''}>${inner}</th>`;
    };
    const paint = () => {
      const kc = cols.find(c => c.key === key), order = rows => kc ? sortRows(rows, key, dir, num(kc)) : rows;
      el.innerHTML = `<table class="dt">${caption(o)}<thead><tr>${cols.map(th).join('')}</tr></thead>${groups.map(g => `<tbody>${
        g.label ? `<tr class="grp"><th scope="rowgroup" colspan="${cols.length}">${esc(g.label)}</th></tr>` : ''}${
        order(g.rows).map(row).join('')}</tbody>`).join('')}${o.foot ? `<tfoot>${row(o.foot)}</tfoot>` : ''}</table>`;
    };
    el.classList.add('dtbox');
    el.tabIndex = 0;  // a scroll box takes focus so a keyboard can scroll it
    el.setAttribute('role', 'region');
    el.setAttribute('aria-label', o.caption || 'data table');
    el.onclick = e => {
      const b = e.target.closest('button[data-k]');
      if (!b) return;
      const c = cols[+b.dataset.k];
      if (c.key === key) dir = dir === 'asc' ? 'desc' : 'asc';
      else { key = c.key; dir = num(c) ? 'desc' : 'asc'; }
      paint();
      el.querySelector(`button[data-k="${b.dataset.k}"]`).focus();
    };
    paint();
  }

  /** Step 1..5 of v on the scale cut at the 4 edges. */
  const bin = (v, edges) => Math.min(5, 1 + edges.filter(e => v >= e).length);

  /** Render a heatmap (rows x cols, every cell printing its value) and its legend into el (element or id). */
  function heat(el, o) {
    el = get(el);
    const all = o.data.flat(), vals = all.filter(ok), lo = Math.min(...vals), hi = Math.max(...vals);
    const p = 10 ** Math.floor(Math.log10(((hi - lo) / 5) || 1));
    const edges = o.edges || [1, 2, 3, 4].map(k => Math.round((lo + ((hi - lo) * k) / 5) / p) * p);
    const f = v => C.fmt(v, { dp: o.dp }), fu = v => C.fmt(v, { dp: o.dp, unit: o.unit });
    let h = `<table>${caption(o)}<thead><tr><td></td>${o.cols.map(c => `<th scope="col">${esc(c)}</th>`).join('')}</tr></thead><tbody>`;
    o.data.forEach((line, r) => {
      h += `<tr><th scope="row">${esc(o.rows[r])}${o.notes ? `<small>${esc(o.notes[r])}</small>` : ''}</th>`;
      line.forEach((v, c) => {
        const nm = o.names ? o.names(r, c) : null, mark = o.mark && o.mark(r, c);
        h += `<td class="${ok(v) ? 'q' + bin(v, edges) : 'na'}${mark ? ' hl' : ''}" title="${esc(nm || `${o.rows[r]}, ${o.cols[c]}`)}: ${
          esc(ok(v) ? fu(v) : 'no data')}">${nm ? `<b>${esc(nm)}</b>` : ''}<span>${esc(ok(v) ? f(v) : 'no data')}</span>${
          mark ? '<span class="vh"> (highlighted)</span>' : ''}</td>`;
      });
      h += '</tr>';
    });
    const steps = [`under ${fu(edges[0])}`, ...[1, 2, 3].map(i => `${f(edges[i - 1])} to ${fu(edges[i])}`), `${fu(edges[3])} and over`];
    el.innerHTML = `<div class="heat" tabindex="0" role="region" aria-label="${esc(o.caption || 'heatmap')}">${h}</tbody></table></div>` +
      `<div class="hk">${steps.map((s, i) => `<span><i class="q${i + 1}"></i>${esc(s)}</span>`).join('')}${
        vals.length < all.length ? '<span><i class="na"></i>no data</span>' : ''}</div>`;
  }

  return { state, chip, limits, tile, tiles, sortRows, table, bin, heat };
})();
