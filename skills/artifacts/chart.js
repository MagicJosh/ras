/* artifacts skill charts: number series -> SVG, drawn at the panel's real pixel width so chart text stays 10.5 px
   on a phone. Needs parts.css's "charts" rules. No dependencies; every color is a var(--token) string.

   LINE CHART  <svg class="ch" id="ch-pos" viewBox="0 0 620 240" role="img" aria-label="what the data shows"></svg>
               The viewBox height is the drawn height in px; the width always follows the panel.
     CrispChart.render('ch-pos', {
       series: [{ name: 'Rack 1', color: 'var(--s1)', data: [0, 88, null, 91] },   // null = a gap, never a 0
                { name: 'avg', color: 'var(--s3)', data: avg, lo: low, hi: high },  // range band around the line
                { name: 'fan', color: 'var(--s2)', data: pos, step: true }],     // holds each value until the next
       x: times, time: { tz: 'UTC' },   // optional x values; with time they are ms timestamps, ticks land on round times
       gap: 2 * 3600e3,                 // optional: also break a line where x jumps further than this
       unit: '%', dp: 0,                // readout and table text, via fmt(v, { dp, unit }); or fmt: v => text
       yLabel: 'fan duty, %', xLabel: 'time, UTC',      // say the unit once, on the axis
       yMin: 0, yMax: 100, yTicks: [0, 50, 100], yFmt: v => v + ' %',   // all optional: round ticks from the data
       xTicks: [[0, '00:00'], [3, '18:00']], xFmt: x => 'hour ' + x,    // optional [x, label]; readout x text
       bands: [{ from: 0, to: 30, label: 'IDLE ≤ 30 %' }, { from: 70, to: 100, label: 'FULL ≥ 70 %' }],
       limits: [{ y: 80, label: 'amber 80 %' }],          // dashed threshold line; color: optional token
       events: [{ x: 14, label: 'Rack 2 halted' }],         // vertical marker, x in x units
       legend: false, right: 54 });     // names sit at the line ends; a legend replaces them only when they do not fit
   BAR CHART   CrispChart.bars('ch-fail', { cats: ['E1', 'B4'], series: [{ name: 'failed', color: 'var(--s1)', data: [41, 17] }],
                 horizontal: true, stacked: false, unit: 'jobs', limits: [{ y: 30, label: 'review at 30' }] });
               Values are 0 or more. Two or more series get a legend. Horizontal bars set their own height, one row per
               category plus a row for limit labels: sort a ranked list largest first. Vertical bars use the viewBox height.
   SPARKLINE   CrispChart.spark(data, { w: 96, h: 24, fmt, limit, label }) -> an <svg class="spark"> string
   TABLE TWIN  CrispData.table(el, CrispChart.tableOf(o, 'caption')): the chart's numbers as a table (data.js)
   FORMATS     fmt(1234.5, { dp: 1, unit: 'V' }) -> '1,234.5 V'; date(ms, 'day' | 'year' | 'time' | 'stamp', tz)
   Every chart takes keyboard focus: arrows move the readout, Home and End jump, Esc hides it; a screen reader hears it.
   Example data only: const rnd = CrispChart.rng(11) gives the same 0..1 sequence on every load. Label it .ex. */
const CrispChart = (() => {
  const CW = 6.3, GAP = 11, LH = 16, KEY = 13;  // mono char width at 10.5 px, end-label spacing, legend row, key room
  const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  const f1 = n => n.toFixed(1);
  const ok = v => v != null && !Number.isNaN(v);
  const tw = s => String(s).length * CW;  // estimated text width

  /** Number -> text: thousands separators, fixed decimals, a real minus, a space before the unit.
      null or NaN -> 'no data' (or o.empty). compact: 12.9K. sign: a leading + on positive values. */
  function fmt(v, o = {}) {
    if (!ok(v)) return o.empty ?? 'no data';
    const dp = o.dp ?? (Number.isInteger(v) || Math.abs(v) >= 100 ? 0 : Math.abs(v) >= 10 ? 1 : 2);
    let s = o.compact ? new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 }).format(v)
      : v.toLocaleString('en-US', { minimumFractionDigits: dp, maximumFractionDigits: dp });
    if (/^-0(\.0*)?$/.test(s)) s = s.slice(1);
    s = s.replace('-', '−');
    if (o.sign && v > 0 && /[1-9]/.test(s)) s = '+' + s;
    return o.unit ? s + ' ' + o.unit : s;
  }

  const DF = {};
  /** ms timestamp -> '2 Nov 2026' (year), '2 Nov' (day), '14:02' (time), '2 Nov 14:02' (stamp). tz defaults to UTC,
      so every viewer reads the same times; name the zone on the axis. */
  function date(ms, kind = 'day', tz = 'UTC') {
    if (kind === 'stamp') return date(ms, 'day', tz) + ' ' + date(ms, 'time', tz);
    const opt = { year: { day: 'numeric', month: 'short', year: 'numeric' }, day: { day: 'numeric', month: 'short' },
      time: { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' } }[kind];
    return (DF[kind + tz] ||= new Intl.DateTimeFormat('en-GB', { timeZone: tz, ...opt })).format(ms);
  }

  /** Round tick values covering lo..hi, about n of them, in steps of 1, 2, 2.5 or 5 x 10^k. */
  function ticks(lo, hi, n = 5) {
    if (!(hi > lo)) hi = lo + 1;
    const raw = (hi - lo) / Math.max(1, n - 1), p = 10 ** Math.floor(Math.log10(raw));
    const step = [1, 2, 2.5, 5, 10].map(m => m * p).find(s => s >= raw * 0.999), out = [];
    for (let k = Math.floor(lo / step + 1e-9); k <= Math.ceil(hi / step - 1e-9); k++) out.push(+(k * step).toFixed(10));
    return out;
  }

  const MIN = 6e4, HR = 36e5, DAY = 864e5;
  const TSTEPS = [MIN, 5 * MIN, 15 * MIN, 30 * MIN, HR, 2 * HR, 3 * HR, 6 * HR, 12 * HR, DAY, 2 * DAY, 7 * DAY, 14 * DAY, 28 * DAY];
  /** ms to add to an instant to read tz's wall clock. */
  function zoneOffset(ms, tz) {
    const p = {};
    for (const x of new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: 'numeric',
      day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric' }).formatToParts(ms)) p[x.type] = +x.value;
    return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second) - Math.floor(ms / 1000) * 1000;
  }
  /** At most max ticks on round wall-clock times in lo..hi: [[ms, '14:00' | '2 Nov']]; midnight shows the date.
      shortcut: the zone offset is read once per axis, so ticks after a DST change sit an hour off; upgrade when a page spans one. */
  function timeTicks(lo, hi, max, tz = 'UTC') {
    const step = TSTEPS.find(s => (hi - lo) / s <= Math.max(1, max)) || TSTEPS[TSTEPS.length - 1];
    const off = zoneOffset(lo, tz), out = [];
    for (let t = Math.ceil((lo + off) / step) * step - off; t <= hi; t += step)
      out.push([t, step >= DAY || (t + off) % DAY === 0 ? date(t, 'day', tz) : date(t, 'time', tz)]);
    return out;
  }

  /** Keep the tick labels that do not touch a neighbour; the last tick wins a place over the one before it.
      tk: [[px, label]]. */
  function thin(tk) {
    const half = t => tw(t[1]) / 2 + 4, kept = [];
    for (const t of tk) if (!kept.length || t[0] - half(t) >= kept[kept.length - 1][0] + half(kept[kept.length - 1])) kept.push(t);
    const last = tk[tk.length - 1];
    if (kept.length > 1 && kept[kept.length - 1] !== last) {
      const fit = kept.filter(t => t[0] + half(t) <= last[0] - half(last));
      if (fit.length) return [...fit, last];
    }
    return kept;
  }

  /** Runs of consecutive indexes where has(i) holds; a missing value or an x jump over gap starts a new run. */
  function runs(n, has, xs, gap) {
    const out = [];
    let cur = null;
    for (let i = 0; i < n; i++) {
      if (!has(i)) { cur = null; continue; }
      if (!cur || (gap && xs[i] - xs[i - 1] > gap)) out.push(cur = []);
      cur.push(i);
    }
    return out;
  }

  /** Index of the value in ascending xs nearest to x. */
  function nearest(xs, x) {
    let lo = 0, hi = xs.length - 1;
    while (hi - lo > 1) { const m = (lo + hi) >> 1; if (xs[m] < x) lo = m; else hi = m; }
    return Math.abs(xs[hi] - x) < Math.abs(x - xs[lo]) ? hi : lo;
  }

  /** Legend items packed left to right into rows of width W: [{ x, row, s }]. */
  function legendRows(series, W) {
    let x = 0, row = 0;
    return series.map(s => {
      const w = 19 + tw(s.name) + 14;
      if (x && x + w > W) { x = 0; row++; }
      const it = { x, row, s };
      x += w;
      return it;
    });
  }
  const legend = items => items.map(({ x, row, s }) => {
    const y = 12 + row * LH;
    return `<line class="key" x1="${x}" x2="${x + 14}" y1="${y - 3.5}" y2="${y - 3.5}" style="stroke:${s.color}"/><text class="lg" x="${x + 19}" y="${y}">${esc(s.name)}</text>`;
  }).join('');
  const halo = (x, y, s, cls, anchor) => `<text class="${cls} halo" x="${f1(x)}" y="${f1(y)}"${anchor ? ` text-anchor="${anchor}"` : ''}>${esc(s)}</text>`;
  const xLabels = (xt, y, W) => thin(xt).map(([px, l]) => {
    const half = tw(l) / 2, a = px + half > W ? 'end' : px - half < 0 ? 'start' : 'middle';
    return `<text x="${f1(a === 'end' ? W - 1 : a === 'start' ? 1 : px)}" y="${y}" text-anchor="${a}">${esc(l)}</text>`;
  }).join('');

  /** A line chart for a W x H drawing: { g: svg markup, n, at(i), pick(px), overlay(i), readout(i) }. Pure. */
  function lineChart(W, H, o) {
    const S = o.series, n = S[0].data.length, xs = o.x || S[0].data.map((_, i) => i), tz = (o.time && o.time.tz) || 'UTC';
    const vals = S.flatMap(s => [...s.data, ...(s.lo || []), ...(s.hi || [])]).concat((o.limits || []).map(l => l.y)).filter(ok);
    const yTicks = o.yTicks || ticks(o.yMin ?? Math.min(...vals), o.yMax ?? Math.max(...vals), H < 170 ? 3 : 5);
    const yMin = o.yMin ?? yTicks[0], yMax = o.yMax ?? yTicks[yTicks.length - 1];
    const tdp = Math.max(...yTicks.map(v => (String(v).split('.')[1] || '').length));
    const yText = o.yFmt || (v => fmt(v, { dp: tdp, compact: Math.max(...yTicks.map(Math.abs)) >= 1e4 }));
    const L = Math.max(46, Math.ceil(Math.max(...yTicks.map(v => tw(yText(v))))) + 10), B = 26 + (o.xLabel ? 14 : 0);
    let R = o.right ?? 54, top = 10 + (o.yLabel ? LH : 0), items = [];
    const wide = Math.max(...S.map(s => tw(s.name))) + KEY + 2 > R, crowded = S.length * GAP > H - top - B;
    if (o.legend ?? (wide || crowded)) {
      items = legendRows(S, W);
      R = 14;
      top += (items[items.length - 1].row + 1) * LH;
    }
    const T = top, w = W - L - R, h = H - T - B, x0 = xs[0], x1 = xs[n - 1];
    const X = x => L + ((x - x0) / ((x1 - x0) || 1)) * w;
    const Y = v => T + h - ((v - yMin) / ((yMax - yMin) || 1)) * h;
    const vf = o.fmt || (o.unit != null || o.dp != null ? v => fmt(v, { dp: o.dp, unit: o.unit }) : o.yFmt || fmt);
    const vText = v => ok(v) ? vf(v) : 'no data';
    const tickAt = new Map(o.xTicks || []);
    const xText = i => o.xFmt ? o.xFmt(xs[i]) : o.time ? date(xs[i], 'stamp', tz) : tickAt.has(xs[i]) ? tickAt.get(xs[i]) : fmt(xs[i]);

    let g = legend(items), txt = '';  // marks first, then the labels that sit on top of them
    for (const b of o.bands || []) {
      const ya = Y(Math.min(b.to ?? yMax, yMax)), yb = Y(Math.max(b.from ?? yMin, yMin));
      if (yb - ya < 1) continue;
      g += `<rect class="band" x="${L}" y="${f1(ya)}" width="${f1(w)}" height="${f1(yb - ya)}" style="fill:${b.color || 'var(--muted)'}"/>`;
      if (b.label) txt += halo(L + 6, ya + 13, b.label, 'bl');
    }
    for (const v of yTicks) {
      g += `<line class="ax" x1="${L}" x2="${L + w}" y1="${Y(v)}" y2="${Y(v)}"/>`;
      g += `<text x="${L - 6}" y="${Y(v) + 3.5}" text-anchor="end">${esc(yText(v))}</text>`;
    }
    const xt = o.xTicks || (o.time ? timeTicks(x0, x1, Math.floor(w / 64), tz)
      : ticks(x0, x1, Math.max(2, Math.floor(w / 64))).filter(v => v >= x0 && v <= x1).map(v => [v, o.xFmt ? o.xFmt(v) : fmt(v)]));
    g += xLabels(xt.map(([x, l]) => [X(x), l]), T + h + 18, W);
    if (o.yLabel) g += `<text class="axl" x="0" y="${T - 7}">${esc(o.yLabel)}</text>`;
    if (o.xLabel) g += `<text class="axl" x="${L + w}" y="${T + h + 33}" text-anchor="end">${esc(o.xLabel)}</text>`;
    for (const l of o.limits || []) {
      if (l.y < yMin || l.y > yMax) continue;
      const y = Y(l.y);
      g += `<line class="lim" x1="${L}" x2="${L + w}" y1="${f1(y)}" y2="${f1(y)}"${l.color ? ` style="stroke:${l.color}"` : ''}/>`;
      if (l.label) txt += halo(L + w - 4, y - 4, l.label, 'll', 'end');
    }
    const rowEnd = [];  // event labels take the first row where they clear the label before them
    for (const e of [...(o.events || [])].sort((a, b) => a.x - b.x)) {
      const px = X(e.x);
      if (px < L - 0.5 || px > L + w + 0.5) continue;
      g += `<line class="ev" x1="${f1(px)}" x2="${f1(px)}" y1="${T}" y2="${T + h}"/>`;
      if (!e.label) continue;
      const wd = tw(e.label), right = px + 4 + wd <= L + w, left = right ? px + 4 : px - 4 - wd;
      let r = rowEnd.findIndex(end => left >= end + 6);
      if (r < 0) r = rowEnd.length;
      rowEnd[r] = left + wd;
      txt += halo(right ? px + 4 : px - 4, T + 11 + r * 12, e.label, 'el', right ? null : 'end');
    }

    const ends = [];
    for (const s of S) {
      if (s.lo && s.hi) for (const r of runs(n, i => ok(s.lo[i]) && ok(s.hi[i]), xs, o.gap)) {
        const pts = [...r.map(i => `${f1(X(xs[i]))},${f1(Y(s.hi[i]))}`), ...[...r].reverse().map(i => `${f1(X(xs[i]))},${f1(Y(s.lo[i]))}`)];
        g += `<polygon class="rng" style="fill:${s.color}" points="${pts.join(' ')}"/>`;
      }
      for (const r of runs(n, i => ok(s.data[i]), xs, o.gap)) {
        if (r.length === 1) { g += `<circle class="pt" cx="${f1(X(xs[r[0]]))}" cy="${f1(Y(s.data[r[0]]))}" r="2.5" style="fill:${s.color}"/>`; continue; }
        const pts = [];
        r.forEach((i, k) => {
          if (s.step && k) pts.push(`${f1(X(xs[i]))},${f1(Y(s.data[r[k - 1]]))}`);
          pts.push(`${f1(X(xs[i]))},${f1(Y(s.data[i]))}`);
        });
        g += `<polyline class="ln" style="stroke:${s.color}" points="${pts.join(' ')}"/>`;
      }
      let last = n - 1;
      while (last >= 0 && !ok(s.data[last])) last--;
      if (last >= 0) ends.push({ y: Y(s.data[last]), y0: Y(s.data[last]), name: s.name, color: s.color });
    }
    if (!items.length) {
      // name each line at its end: push labels apart downward, lift them all if the lowest left the plot,
      // and join each name to its line end with a short line in the series color
      ends.sort((a, b) => a.y - b.y);
      for (let i = 1; i < ends.length; i++) ends[i].y = Math.max(ends[i].y, ends[i - 1].y + GAP);
      const over = ends.length ? ends[ends.length - 1].y - (T + h) : 0;
      for (const e of ends) {
        if (over > 0) e.y -= over;
        g += `<polyline class="key" points="${f1(L + w + 2)},${f1(e.y0)} ${f1(L + w + KEY - 3)},${f1(e.y)}" style="stroke:${e.color}"/>`;
        txt += `<text class="lbl" x="${f1(L + w + KEY)}" y="${f1(e.y + 3.5)}">${esc(e.name)}</text>`;
      }
    }

    return {
      g: g + txt, n,
      at: i => ({ x: X(xs[i]), y: T }),
      pick: px => nearest(xs, x0 + ((px - L) / (w || 1)) * (x1 - x0)),
      overlay: i => {
        const px = f1(X(xs[i]));
        return `<line class="xh" x1="${px}" x2="${px}" y1="${T}" y2="${T + h}"/>` + S.filter(s => ok(s.data[i]))
          .map(s => `<circle class="dot" cx="${px}" cy="${f1(Y(s.data[i]))}" r="4" style="fill:${s.color}"/>`).join('');
      },
      readout: i => ({ x: xText(i), rows: S.map(s => ({ name: s.name, color: s.color, text: vText(s.data[i]) +
        (s.lo && s.hi && ok(s.lo[i]) && ok(s.hi[i]) ? ` (range ${vText(s.lo[i])} to ${vText(s.hi[i])})` : '') })) })
    };
  }

  /** The line chart's inner SVG for a W x H viewBox. Pure, so check.mjs can test it. */
  const markup = (W, H, o) => lineChart(W, H, o).g;

  /** One bar from a (baseline side) to b (data end) along the value axis, c..c+t across it, rounded only at the data end. */
  function barPath(hz, a, b, c, t, r, color) {
    r = Math.max(0, Math.min(r, t / 2, Math.abs(b - a)));
    const d = hz
      ? `M${f1(a)},${f1(c)}H${f1(b - r)}Q${f1(b)},${f1(c)} ${f1(b)},${f1(c + r)}V${f1(c + t - r)}Q${f1(b)},${f1(c + t)} ${f1(b - r)},${f1(c + t)}H${f1(a)}Z`
      : `M${f1(c)},${f1(a)}V${f1(b + r)}Q${f1(c)},${f1(b)} ${f1(c + r)},${f1(b)}H${f1(c + t - r)}Q${f1(c + t)},${f1(b)} ${f1(c + t)},${f1(b + r)}V${f1(a)}Z`;
    return `<path class="bar" d="${d}" style="fill:${color}"/>`;
  }

  /** A bar chart for a W x H drawing: { g, H (horizontal bars set their own), n, at, pick, overlay, readout }. Pure.
      Bars are at most 24 px thick with a 2 px gap between touching bars and stacked segments. */
  function barChart(W, H, o) {
    const S = o.series, cats = o.cats, n = cats.length, k = S.length, hz = !!o.horizontal, stk = !!o.stacked && k > 1;
    const val = (s, i) => ok(s.data[i]) ? s.data[i] : null;
    const total = i => S.some(s => ok(s.data[i])) ? S.reduce((a, s) => a + (val(s, i) || 0), 0) : null;
    const vf = o.fmt || (v => fmt(v, { dp: o.dp, unit: o.unit })), vText = v => ok(v) ? vf(v) : 'no data';
    const tip = i => stk ? total(i) : val(S[0], i);  // the value printed at the bar end
    const showVal = o.values ?? (k === 1 || stk);
    const items = k > 1 ? legendRows(S, W) : [];
    const limRow = hz && (o.limits || []).some(l => l.label) ? 14 : 0;  // horizontal bars print limit labels above the bars
    const top = 10 + (items.length ? (items[items.length - 1].row + 1) * LH : 0) + (o.yLabel ? LH : 0) + limRow;
    const peak = Math.max(0, ...cats.map((_, i) => stk ? total(i) : Math.max(0, ...S.map(s => val(s, i) || 0))).filter(ok),
      ...(o.limits || []).map(l => l.y));
    const tdp = t => Math.max(...t.map(v => (String(v).split('.')[1] || '').length));
    let g = legend(items), txt = '', out;
    if (o.yLabel) g += `<text class="axl" x="0" y="${top - limRow - 7}">${esc(o.yLabel)}</text>`;

    if (hz) {
      const one = k === 1 || stk, band = o.band || (one ? 28 : k * 12 + 12), th = one ? 16 : 10;
      const L = Math.min(W * 0.4, Math.max(30, Math.ceil(Math.max(...cats.map(tw))) + 12));
      const R = showVal ? Math.ceil(Math.max(...cats.map((_, i) => tw(vText(tip(i)))))) + 12 : 14;
      const w = W - L - R, base = top + n * band;
      const tk = o.ticks || ticks(0, peak || 1, Math.max(2, Math.min(6, Math.floor(w / 70))));
      const vMax = o.max ?? tk[tk.length - 1], V = v => L + (v / vMax) * w, tt = o.yFmt || (v => fmt(v, { dp: tdp(tk) }));
      for (const t of tk) g += `<line class="ax" x1="${f1(V(t))}" x2="${f1(V(t))}" y1="${top}" y2="${base}"/>`;
      g += xLabels(tk.map(t => [V(t), tt(t)]), base + 16, W);
      if (o.xLabel) g += `<text class="axl" x="${L + w}" y="${base + 31}" text-anchor="end">${esc(o.xLabel)}</text>`;
      cats.forEach((c, i) => {
        const y0 = top + i * band, mid = y0 + band / 2;
        g += `<text x="${L - 8}" y="${f1(mid + 3.5)}" text-anchor="end">${esc(c)}</text>`;
        if (stk) {
          const segs = S.map(s => [s, val(s, i)]).filter(([, v]) => v > 0);
          let cum = 0;
          segs.forEach(([s, v], j) => {
            const a = V(cum) + (j ? 1 : 0), b = V(cum + v) - (j < segs.length - 1 ? 1 : 0);
            cum += v;
            if (b > a) g += barPath(true, a, b, mid - th / 2, th, j === segs.length - 1 ? 4 : 0, s.color);
          });
        } else S.forEach((s, j) => {
          const v = val(s, i);
          if (v > 0) g += barPath(true, V(0), V(v), y0 + (band - (k * th + (k - 1) * 2)) / 2 + j * (th + 2), th, 4, s.color);
        });
        if (showVal) txt += `<text class="vl" x="${f1((ok(tip(i)) ? V(tip(i)) : L) + 5)}" y="${f1(mid + 3.5)}">${esc(vText(tip(i)))}</text>`;
      });
      for (const l of o.limits || []) {
        if (l.y > vMax) continue;
        g += `<line class="lim" x1="${f1(V(l.y))}" x2="${f1(V(l.y))}" y1="${top - 4}" y2="${base}"${l.color ? ` style="stroke:${l.color}"` : ''}/>`;
        if (l.label) txt += V(l.y) + 4 + tw(l.label) > W ? halo(V(l.y) - 4, top - 6, l.label, 'll', 'end') : halo(V(l.y) + 4, top - 6, l.label, 'll');
      }
      out = { H: base + 26 + (o.xLabel ? 14 : 0), at: i => ({ x: V(Math.max(0, tip(i) || 0)), y: top + i * band }),
        pick: (px, py) => Math.floor((py - top) / band),
        overlay: i => `<rect class="hb" x="0" y="${f1(top + i * band)}" width="${W}" height="${band}"/>` };
    } else {
      const tk = o.ticks || ticks(0, peak || 1, H < 170 ? 3 : 5), tt = o.yFmt || (v => fmt(v, { dp: tdp(tk) }));
      const vMax = o.max ?? tk[tk.length - 1], T = top + (showVal ? 6 : 0), B = 26 + (o.xLabel ? 14 : 0);
      const L = Math.max(40, Math.ceil(Math.max(...tk.map(t => tw(tt(t))))) + 10), R = 12;
      const w = W - L - R, h = H - T - B, band = w / n, V = v => T + h - (v / vMax) * h;
      const th = Math.max(2, Math.min(24, stk ? band * 0.6 : (band * 0.7 - (k - 1) * 2) / k));
      for (const t of tk) {
        g += `<line class="ax" x1="${L}" x2="${L + w}" y1="${f1(V(t))}" y2="${f1(V(t))}"/>`;
        g += `<text x="${L - 6}" y="${f1(V(t) + 3.5)}" text-anchor="end">${esc(tt(t))}</text>`;
      }
      g += xLabels(cats.map((c, i) => [L + band * (i + 0.5), c]), T + h + 18, W);
      if (o.xLabel) g += `<text class="axl" x="${L + w}" y="${T + h + 33}" text-anchor="end">${esc(o.xLabel)}</text>`;
      cats.forEach((c, i) => {
        const mid = L + band * (i + 0.5);
        if (stk) {
          const segs = S.map(s => [s, val(s, i)]).filter(([, v]) => v > 0);
          let cum = 0;
          segs.forEach(([s, v], j) => {
            const a = V(cum) - (j ? 1 : 0), b = V(cum + v) + (j < segs.length - 1 ? 1 : 0);
            cum += v;
            if (a > b) g += barPath(false, a, b, mid - th / 2, th, j === segs.length - 1 ? 4 : 0, s.color);
          });
        } else S.forEach((s, j) => {
          const v = val(s, i);
          if (v > 0) g += barPath(false, V(0), V(v), mid - (k * th + (k - 1) * 2) / 2 + j * (th + 2), th, 4, s.color);
        });
        const t = vText(tip(i));
        if (showVal && tw(t) <= band - 2) txt += `<text class="vl" x="${f1(mid)}" y="${f1(V(Math.max(0, tip(i) || 0)) - 5)}" text-anchor="middle">${esc(t)}</text>`;
      });
      for (const l of o.limits || []) {
        if (l.y > vMax) continue;
        g += `<line class="lim" x1="${L}" x2="${L + w}" y1="${f1(V(l.y))}" y2="${f1(V(l.y))}"${l.color ? ` style="stroke:${l.color}"` : ''}/>`;
        if (l.label) txt += halo(L + w - 4, V(l.y) - 4, l.label, 'll', 'end');
      }
      out = { H, at: i => ({ x: L + band * (i + 0.5), y: T }), pick: px => Math.floor((px - L) / band),
        overlay: i => `<rect class="hb" x="${f1(L + i * band)}" y="${T}" width="${f1(band)}" height="${h}"/>` };
    }
    const pick = out.pick;
    return { ...out, g: g + txt, n, pick: (px, py) => Math.max(0, Math.min(n - 1, pick(px, py))),
      readout: i => ({ x: cats[i], rows: S.map(s => ({ name: s.name, color: s.color, text: vText(val(s, i)) }))
        .concat(stk ? [{ name: 'total', color: '', text: vText(total(i)) }] : []) }) };
  }

  /** A sparkline as an <svg class="spark"> string: the line in --muted, the newest value as a --clay dot. */
  function spark(data, o = {}) {
    const w = o.w || 96, h = o.h || 24, p = 3, n = data.length, vals = data.filter(ok), f = o.fmt || fmt;
    if (!vals.length) return '<span class="na">no data</span>';
    const lims = ok(o.limit) ? [o.limit] : [];
    const lo = o.min ?? Math.min(...vals, ...lims), hi = o.max ?? Math.max(...vals, ...lims);
    const X = i => p + (i / ((n - 1) || 1)) * (w - 2 * p), Y = v => h - p - ((v - lo) / ((hi - lo) || 1)) * (h - 2 * p);
    let g = lims.length ? `<line class="lim" x1="0" x2="${w}" y1="${f1(Y(o.limit))}" y2="${f1(Y(o.limit))}"/>` : '';
    for (const r of runs(n, i => ok(data[i])))
      g += r.length > 1 ? `<polyline class="ln" style="stroke:${o.color || 'var(--muted)'}" points="${r.map(i => f1(X(i)) + ',' + f1(Y(data[i]))).join(' ')}"/>`
        : `<circle cx="${f1(X(r[0]))}" cy="${f1(Y(data[r[0]]))}" r="1.5" style="fill:${o.color || 'var(--muted)'}"/>`;
    let last = n - 1;
    while (!ok(data[last])) last--;
    g += `<circle cx="${f1(X(last))}" cy="${f1(Y(data[last]))}" r="2.5" style="fill:${o.accent || 'var(--clay)'}"/>`;
    const label = o.label || `trend from ${f(vals[0])} to ${f(vals[vals.length - 1])}, low ${f(Math.min(...vals))}, high ${f(Math.max(...vals))}`;
    return `<svg class="spark" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${esc(label)}">${g}</svg>`;
  }

  /** A chart's numbers as CrispData.table options: one row per x or category, one column per series (plus low and
      high for a range band). Numbers stay numbers, so the table formats and sorts them. */
  function tableOf(o, caption) {
    const c = o.cats ? null : lineChart(640, 320, o), n = o.cats ? o.cats.length : o.series[0].data.length;
    const cols = [{ key: 'x', label: o.xLabel || (o.cats ? 'category' : 'x'), head: true }];
    o.series.forEach((s, j) => {
      cols.push({ key: 's' + j, label: s.name, unit: o.unit, dp: o.dp });
      if (s.lo && s.hi) cols.push({ key: 'l' + j, label: s.name + ' low', unit: o.unit, dp: o.dp }, { key: 'h' + j, label: s.name + ' high', unit: o.unit, dp: o.dp });
    });
    const rows = Array.from({ length: n }, (_, i) => {
      const r = { x: o.cats ? o.cats[i] : c.readout(i).x };
      o.series.forEach((s, j) => { r['s' + j] = s.data[i]; if (s.lo && s.hi) { r['l' + j] = s.lo[i]; r['h' + j] = s.hi[i]; } });
      return r;
    });
    return { caption, cols, rows, sort: false };
  }

  /** Draw a chart into an <svg class="ch"> (element or id) at its rendered width; redraw when that width changes. */
  function draw(svg, o, build) {
    if (typeof svg === 'string') svg = document.getElementById(svg);
    const st = svg._crisp || (svg._crisp = { H0: svg.viewBox.baseVal.height, W0: svg.viewBox.baseVal.width });
    st.o = o; st.build = build;
    const paint = () => {
      st.W = Math.round(svg.getBoundingClientRect().width) || st.W0;
      st.c = st.build(st.W, st.H0, st.o);
      svg.setAttribute('viewBox', `0 0 ${st.W} ${st.c.H || st.H0}`);
      svg.innerHTML = st.c.g + '<g class="hov"></g>';
    };
    paint();
    if (!st.wired) {
      st.wired = true;
      if (window.ResizeObserver) new ResizeObserver(() => { if (Math.round(svg.getBoundingClientRect().width) !== st.W) paint(); }).observe(svg);
      else window.addEventListener('resize', paint);
      if (o.interactive !== false) interact(svg);
    }
    return svg;
  }

  /** The hover and keyboard readout: a crosshair or band, a tooltip with every series at that x, and a status line. */
  function interact(svg) {
    const st = svg._crisp, host = svg.parentElement;
    const el = (tag, cls) => { const e = document.createElement(tag); if (cls) e.className = cls; return e; };
    if (getComputedStyle(host).position === 'static') host.style.position = 'relative';
    const tip = el('div', 'chtip'), live = el('div', 'vh');
    tip.hidden = true;
    tip.setAttribute('aria-hidden', 'true');
    live.setAttribute('role', 'status');
    svg.after(tip, live);
    svg.setAttribute('tabindex', '0');
    let cur = -1;
    const hide = () => { tip.hidden = true; const hov = svg.querySelector('.hov'); if (hov) hov.innerHTML = ''; };
    const show = (i, speak) => {
      const c = st.c;
      cur = Math.max(0, Math.min(c.n - 1, i));
      svg.querySelector('.hov').innerHTML = c.overlay(cur);
      const r = c.readout(cur), head = el('div', 'tx');
      head.textContent = r.x;  // names and values go in as text, never as markup
      tip.replaceChildren(head, ...r.rows.map(row => {
        const d = el('div', 'r'), key = el('i'), b = el('b'), s = el('span');
        if (row.color) key.style.borderTopColor = row.color; else key.style.visibility = 'hidden';
        b.textContent = row.text;
        s.textContent = row.name;
        d.append(key, b, s);
        return d;
      }));
      tip.hidden = false;
      // an <svg> has no offsetLeft/offsetTop, so place the tip from both boxes, relative to the host's padding box
      const p = c.at(cur), b = svg.getBoundingClientRect(), hb = host.getBoundingClientRect(), k = b.width / (st.W || 1);
      const x = b.left - hb.left - host.clientLeft + p.x * k, y = b.top - hb.top - host.clientTop + p.y * k;
      tip.style.left = Math.max(0, p.x > st.W / 2 ? x - 12 - tip.offsetWidth : x + 12) + 'px';
      tip.style.top = y + 'px';
      if (speak) live.textContent = `${r.x}: ${r.rows.map(row => `${row.name} ${row.text}`).join(', ')}`;
    };
    const pick = e => {
      const b = svg.getBoundingClientRect(), k = st.W / (b.width || 1);
      return st.c.pick((e.clientX - b.left) * k, (e.clientY - b.top) * k);
    };
    svg.addEventListener('pointermove', e => show(pick(e)));
    svg.addEventListener('pointerdown', e => show(pick(e)));
    svg.addEventListener('pointerleave', hide);
    svg.addEventListener('focus', () => show(cur < 0 ? st.c.n - 1 : cur, true));
    svg.addEventListener('blur', hide);
    svg.addEventListener('keydown', e => {
      const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
      if (step) show(cur + step, true);
      else if (e.key === 'Home') show(0, true);
      else if (e.key === 'End') show(st.c.n - 1, true);
      else if (e.key === 'Escape') hide();
      else return;
      e.preventDefault();
    });
  }

  /** Seeded 0..1 generator (Park-Miller) for example data that is the same on every load. */
  function rng(seed) {
    return () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  }

  return {
    render: (svg, o) => draw(svg, o, lineChart), bars: (svg, o) => draw(svg, o, barChart),
    markup, lineChart, barChart, spark, tableOf, fmt, date, ticks, timeTicks, thin, nearest, rng
  };
})();
