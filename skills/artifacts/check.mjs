// Runnable check for this folder: node check.mjs (exits non-zero on failure)
// Tests terminal.js, chart.js, data.js and linkmap.js logic, the lint on good and bad pages, the spec page (spec-page.mjs
// and spec-page.js: parse, cksum, build, save shape, merge), and lints example.html and gallery.html. Then the docs:
// every guide is linked from SKILL.md, every relative link resolves, every parts.css section has a demo in gallery.html.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';
import { lintText, lintFile } from './lint.mjs';
import { cksum, specData, buildPage, pageData, merge } from './spec-page.mjs';

const read = f => readFileSync(new URL('./' + f, import.meta.url), 'utf8');
const load = (f, name) => { const ctx = {}; runInNewContext(read(f) + `\nthis.${name} = ${name};`, ctx); return ctx[name]; };
const plain = rows => JSON.parse(JSON.stringify(rows));

// ---------- terminal.js ----------
const { parse, rowHTML } = load('terminal.js', 'CrispTerm');
// truecolor + bold, reset, 16-color, 256-color, bright bg, and a cursor escape that must vanish
assert.deepEqual(plain(parse('\x1b[1;38;2;217;119;87mA\x1b[0mB\x1b[31mC\x1b[38;5;196mD\x1b[2K\x1b[39;101mE\x1b[mF')), [[
  { t: 'A', bold: true, fg: 'rgb(217,119,87)' }, { t: 'B' }, { t: 'C', fg: '#f92672' },
  { t: 'D', fg: 'rgb(255,0,0)' }, { t: 'E', bg: '#f92672' }, { t: 'F' }]]);
assert.deepEqual(plain(parse('a\r\nb')).map(r => r[0].t), ['a', 'b']);
assert.equal(plain(parse('\x1b[38;5;244mx'))[0][0].fg, 'rgb(128,128,128)');  // the grayscale ramp
assert.equal(plain(parse('\x1b[90mx'))[0][0].fg, '#75715e');  // bright black, not black

// blocks become cell-filling shapes, quadrants become one layer per filled quarter
const h = s => rowHTML(parse(s)[0]);
assert.match(h('█'), /linear-gradient\(to top,var\(--term-fg\) 100%/);
assert.match(h('▄'), /to top,var\(--term-fg\) 50%/);
assert.match(h('▏'), /to right,var\(--term-fg\) 12.5%/);
assert.equal((h('\x1b[48;2;0;0;0m▛').match(/linear-gradient/g) || []).length, 3);
assert.match(h('\x1b[48;2;0;0;0m▛'), /,rgb\(0,0,0\)"/);  // the cell's background sits under the quadrants
assert.match(h('a<b'), /a&lt;b/);
assert.match(h('♪'), /class="c "/);  // pinned to one cell

// ---------- chart.js and data.js share one context, as on a page ----------
const ctx = {};
runInNewContext(read('chart.js') + read('data.js') + '\nthis.C = CrispChart; this.D = CrispData;', ctx);
const { markup, lineChart, barChart, spark, tableOf, fmt, date, ticks, timeTicks, thin, nearest, rng } = ctx.C;
const points = g => [...g.matchAll(/class="ln"[^>]*points="([^"]*)"/g)].map(m => m[1]);
const lbl = g => [...g.matchAll(/class="lbl"[^>]*y="([\d.]+)"[^>]*>([^<]*)</g)].map(m => [m[2], +m[1]]);

// formats: one style for every number and time on the page
assert.equal(fmt(1234.5, { dp: 1, unit: 'V' }), '1,234.5 V');
assert.equal(fmt(-3.2, { dp: 1, sign: true }), '−3.2');  // a real minus
assert.equal(fmt(3, { sign: true, unit: '%' }), '+3 %');
assert.equal(fmt(-0.001, { dp: 1 }), '0.0');  // no minus on a value that rounds to zero
assert.equal(fmt(null), 'no data');
assert.equal(fmt(NaN, { empty: 'not read' }), 'not read');
assert.equal(fmt(12900, { compact: true }), '12.9K');
const t0 = Date.UTC(2026, 10, 2, 14, 2), day = Date.UTC(2026, 10, 1), hr = 36e5;
assert.equal(date(t0, 'stamp'), '2 Nov 14:02');
assert.equal(date(t0, 'year'), '2 Nov 2026');
assert.equal(date(t0, 'time', 'Europe/Amsterdam'), '15:02');
assert.deepEqual(plain(ticks(0, 92)), [0, 25, 50, 75, 100]);
assert.deepEqual(plain(ticks(16300, 17600)), [16000, 16500, 17000, 17500, 18000]);
assert.deepEqual(plain(timeTicks(day, day + 36 * hr, 6).map(t => t[1])), ['1 Nov', '06:00', '12:00', '18:00', '2 Nov', '06:00', '12:00']);
assert.deepEqual(plain(timeTicks(day + 9e5, day + 6 * hr, 6, 'Europe/Amsterdam').map(t => t[1]).slice(0, 2)), ['02:00', '03:00']);  // the zone's round hours
assert.deepEqual(plain(thin([[0, '00:00'], [20, '01:00'], [40, '02:00'], [60, '03:00'], [80, '04:00'], [100, '05:00']]).map(t => t[1])),
  ['00:00', '02:00', '05:00']);  // labels that would touch drop out, the last one stays
assert.equal(nearest([0, 10, 20, 40], 29), 2);
assert.equal(nearest([0, 10, 20, 40], 31), 3);

// line chart: a 200 x 136 drawing gives a 100 x 100 plot at x 46..146, y 10..110
const axes = { yMin: 0, yMax: 100, yTicks: [0, 50, 100], xTicks: [[0, 'a'], [3, 'b']] };
let g = markup(200, 136, { ...axes, series: [{ name: 'A', color: 'var(--s1)', data: [0, 50, null, 100] }] });
assert.deepEqual(points(g), ['46.0,110.0 79.3,60.0']);  // a null splits the line
assert.match(g, /<circle class="pt" cx="146.0" cy="10.0" r="2.5" style="fill:var\(--s1\)"\/>/);  // and a lone value still shows
assert.match(g, /<line class="ax" x1="46" x2="146" y1="60" y2="60"\/>/);
g = markup(200, 136, { ...axes, right: 70, yFmt: v => v + ' %', series: [{ name: 'R&D <x>', color: 'var(--s1)', data: [100, 100, 100, null] }] });
assert.deepEqual(lbl(g), [['R&amp;D &lt;x>', 13.5]]);  // named at its last real value, not at y = 0; text escaped
assert.match(g, /<polyline class="key" points="132.0,10.0 140.0,10.0" style="stroke:var\(--s1\)"\/>/);  // a short line in the series color
assert.doesNotMatch(g, /class="lbl"[^>]*style=/);  // the name itself wears the text color
assert.match(g, />50 %</);
g = markup(200, 136, { ...axes, series: ['A', 'B', 'C'].map(name => ({ name, color: 'var(--s1)', data: [9, 9, 9, 0] })) });
assert.deepEqual(lbl(g).map(([, y]) => y), [91.5, 102.5, 113.5]);  // pushed apart, then lifted back inside the plot
g = markup(400, 200, { series: [{ name: 'Rack 1', color: 'var(--s1)', data: [1, 2] }, { name: 'a much longer series name', color: 'var(--s2)', data: [2, 1] }] });
assert.match(g, /class="lg" x="[\d.]+" y="12">Rack 1</);  // names that do not fit at the line ends become a legend
assert.doesNotMatch(g, /class="lbl"/);

// thresholds, bands, a step line, events and axis labels: T 26 (y label row), B 40 (x label), plot x 46..366, y 26..190
const pos = lineChart(420, 230, { series: [{ name: 'fan', color: 'var(--s2)', data: [10, 80, 80, 20], step: true }],
  yMin: 0, yMax: 100, yTicks: [0, 50, 100], unit: '%', yLabel: 'fan duty, %', xLabel: 'sample',
  bands: [{ from: 0, to: 30, label: 'IDLE ≤ 30 %' }, { from: 70, to: 100, label: 'FULL ≥ 70 %' }],
  limits: [{ y: 50, label: 'half open' }], events: [{ x: 1, label: 'opened' }, { x: 1.2, label: 'second' }] });
assert.match(pos.g, /<rect class="band" x="46" y="140.8" width="320.0" height="49.2" style="fill:var\(--muted\)"\/>/);
assert.match(pos.g, /class="bl halo"[^>]*>IDLE ≤ 30 %</);
assert.match(pos.g, /class="bl halo"[^>]*>FULL ≥ 70 %</);
assert.match(pos.g, /<line class="lim" x1="46" x2="366" y1="108.0" y2="108.0"\/>/);
assert.match(pos.g, /class="ll halo"[^>]*text-anchor="end">half open</);
assert.equal(points(pos.g)[0].split(' ').slice(0, 3).join(' '), '46.0,173.6 152.7,173.6 152.7,58.8');  // holds, then steps
assert.match(pos.g, /<line class="ev" x1="152.7"/);
assert.match(pos.g, /class="el halo" x="178.0" y="49.0">second</);  // an event label that would touch moves down a row
assert.match(pos.g, /<text class="axl" x="0" y="19">fan duty, %</);
assert.match(pos.g, /<text class="axl" x="366" y="223" text-anchor="end">sample</);
assert.deepEqual(plain(pos.readout(1)), { x: '1', rows: [{ name: 'fan', color: 'var(--s2)', text: '80 %' }] });

// a range band on a time axis, broken where the samples stop for longer than gap
const xs = [0, 1, 2, 5, 6].map(i => day + i * hr), lux = [400, 410, 415, 405, 300];
const rg = { x: xs, time: {}, gap: 1.5 * hr, unit: 'lux', xLabel: 'time, UTC',
  series: [{ name: 'avg', color: 'var(--s3)', data: lux, lo: lux.map(v => v - 20), hi: lux.map(v => v + 15) }] };
const rc = lineChart(420, 230, rg);
assert.equal(points(rc.g).length, 2);
assert.equal((rc.g.match(/class="rng"/g) || []).length, 2);
assert.match(rc.g, />1 Nov</);
assert.match(rc.g, />04:00</);
assert.deepEqual(plain(rc.readout(2)), { x: '1 Nov 02:00', rows: [{ name: 'avg', color: 'var(--s3)', text: '415 lux (range 395 lux to 430 lux)' }] });
assert.equal(rc.pick(312), 3);  // the pointer snaps to the nearest sample
const tv = plain(tableOf(rg, 'Lux'));
assert.deepEqual(tv.cols.map(c => c.label), ['time, UTC', 'avg', 'avg low', 'avg high']);
assert.deepEqual(tv.rows[3], { x: '1 Nov 05:00', s0: 405, l0: 385, h0: 420 });

// bars: horizontal ranks set their own height; missing is said, never drawn as 0; stacks keep a 2 px gap
const hb = barChart(400, 999, { cats: ['E1', 'B4', 'C2'], horizontal: true, unit: 'jobs',
  series: [{ name: 'failed', color: 'var(--s1)', data: [41, null, 17] }] });
assert.equal(hb.H, 10 + 3 * 28 + 26);
assert.match(hb.g, /class="vl"[^>]*>41 jobs</);
assert.match(hb.g, /class="vl"[^>]*>no data</);
assert.equal((hb.g.match(/class="bar"/g) || []).length, 2);
assert.doesNotMatch(hb.g, /class="lg"/);  // one series: the panel title names it
assert.equal(hb.pick(0, 10 + 28 * 2 + 5), 2);
// a labelled limit gets its own row above the bars, so the label never sits on the first bar
const hl = barChart(400, 999, { cats: ['E1', 'B4'], horizontal: true, limits: [{ y: 30, label: 'review at 30' }],
  series: [{ name: 'failed', color: 'var(--s1)', data: [41, 17] }] });
assert.equal(hl.H, 10 + 14 + 2 * 28 + 26);
assert.match(hl.g, /class="ll halo" x="[\d.]+" y="18\.0">review at 30</);
assert.match(hl.g, /class="bar"[^>]*d="M[\d.]+,(2[4-9]|3\d)/);  // first bar starts below the label row
const vb = barChart(300, 200, { cats: ['R1', 'R2'], stacked: true,
  series: [{ name: 'ok', color: 'var(--s1)', data: [6, 3] }, { name: 'failed', color: 'var(--s2)', data: [2, 1] }] });
assert.match(vb.g, /class="lg"[^>]*>ok</);  // two series get a legend
assert.match(vb.g, /V68\.5Q90\.0,68\.5 90\.0,68\.5/);  // the lower segment stops 1 px short of the boundary, square
assert.match(vb.g, /M90\.0,66\.5V36\.0Q90\.0,32\.0 94\.0,32\.0/);  // the top one starts 1 px past it, rounded only at its data end
assert.deepEqual(plain(vb.readout(0)).rows.map(r => r.text), ['6', '2', '8']);  // each part, then the total

// sparkline
const sp = spark([1, 2, null, 4, 3], { fmt: v => fmt(v, { unit: 's' }) });
assert.match(sp, /aria-label="trend from 1 s to 3 s, low 1 s, high 4 s"/);
assert.equal((sp.match(/<polyline/g) || []).length, 2);
assert.equal(spark([null, null]), '<span class="na">no data</span>');

const r1 = rng(7), r2 = rng(7);
assert.equal(r1(), 117649 / 2147483647);  // the generator: seed 7 starts at 7 * 16807
r2();
assert.equal(r1(), r2());  // and two generators with one seed stay in step

// ---------- data.js ----------
const { state, limits, tile, sortRows, table, bin, heat } = ctx.D;
assert.equal(state(79.9, { warn: 80, crit: 90 }), 'ok');
assert.equal(state(80, { warn: 80, crit: 90 }), 'warn');  // a limit is reached at its value
assert.equal(state(95, { warn: 80, crit: 90 }), 'crit');
assert.equal(state(15, { warn: 20, crit: 10, dir: 'down' }), 'warn');
assert.equal(state(null, { warn: 1 }), 'unknown');
assert.equal(limits({ warn: 80, crit: 90 }, '%', 0), 'warn ≥ 80 %, alarm ≥ 90 %');
let t = tile({ label: 'Uploads waiting', value: null, unit: 'files', since: 'last reading 14:03' });
assert.match(t, /class="tile unknown"/);
assert.match(t, /<div class="tv">no data<\/div>/);
assert.match(t, /last reading 14:03/);
assert.doesNotMatch(t, />0</);  // unknown, never a fake 0
t = tile({ label: 'Disk used', value: 84, unit: '%', dp: 0, warn: 80, crit: 90, max: 100, delta: 3, deltaText: 'since 1 Oct', better: 'down' });
assert.match(t, /class="tile warn"/);
assert.match(t, /<span class="st warn">warn<\/span><span>warn ≥ 80 %, alarm ≥ 90 %<\/span>/);
assert.match(t, /<i style="width:84.0%"><\/i><b style="left:80.0%"><\/b><b style="left:90.0%"><\/b>/);
assert.match(t, /\+3 % since 1 Oct, worse/);  // the delta says better or worse in words, not only in color
t = tile({ label: 'Jobs today', value: 18432, dp: 0 });
assert.match(t, /^<div class="tile"><div class="tl"><span>Jobs today<\/span><\/div><div class="tv">18,432<\/div><\/div>$/);  // no limits: no verdict

const rows = [{ s: 'A10', v: 2 }, { s: 'A2', v: null }, { s: 'A9', v: 5 }, { s: 'B1', v: 2 }];
assert.deepEqual(plain(sortRows(rows, 'v', 'desc', true).map(r => r.s)), ['A9', 'A10', 'B1', 'A2']);  // ties keep order, missing last
assert.deepEqual(plain(sortRows(rows, 'v', 'asc', true).map(r => r.s)), ['A10', 'B1', 'A9', 'A2']);
assert.deepEqual(plain(sortRows(rows, 's').map(r => r.s)), ['A2', 'A9', 'A10', 'B1']);

const box = { innerHTML: '', classList: { add() {} }, setAttribute() {}, querySelector: () => ({ focus() {} }) };
table(box, { caption: 'Hosts', source: 'Health checks (3)', ex: true, highlight: r => r.host === 'E1',
  cols: [{ key: 'host', label: 'Host', head: true }, { key: 'jobs', label: 'Jobs', unit: 'count', dp: 0 },
    { key: 'open', label: 'Open', unit: 's', dp: 2 }, { key: 'st', label: 'State', type: 'state', tones: { paused: 'warn' } },
    { key: 'disk', label: 'Disk', unit: '%', dp: 0, type: 'meter', warn: 80, crit: 90 }, { key: 'tr', label: 'Trend', type: 'spark' }],
  groups: [{ label: 'Rack 1', rows: [{ host: 'A1', jobs: 23104, open: 16.4, st: 'active', disk: 84, tr: [1, 2] },
    { host: 'E1', jobs: 9, open: null, st: 'paused', disk: 12 }] },
    { label: 'Rack <2>', rows: [{ host: 'A2', jobs: 1200, open: 16, st: null, disk: 95 }] }],
  foot: { host: 'All', jobs: 24313 } });
let ht = box.innerHTML;
assert.match(ht, /<caption><span class="ct">Hosts<\/span> <span class="ex">example values<\/span><span class="cs">Source: Health checks \(3\)<\/span><\/caption>/);
assert.match(ht, /<th scope="col" class="n"><button type="button" data-k="1">Jobs<span class="si" aria-hidden="true">↕<\/span><span class="u">count<\/span><\/button><\/th>/);
assert.match(ht, /<td class="n">23,104<\/td><td class="n">16.40<\/td>/);  // thousands separator, fixed decimals per column
assert.match(ht, /<td class="n"><span class="na">no data<\/span><\/td>/);
assert.match(ht, /<span class="st off">active<\/span>/);  // a word without a tone stays neutral
assert.match(ht, /<span class="st warn">paused<\/span>/);
assert.match(ht, /<span class="st unknown">unknown<\/span>/);
assert.match(ht, /84<span class="cm warn"[^]*?<span class="st i warn"><span class="vh">warn<\/span><\/span>/);
assert.match(ht, /<tr class="grp"><th scope="rowgroup" colspan="6">Rack &lt;2><\/th><\/tr>/);
assert.match(ht, /<tr class="hl"><th scope="row">E1<span class="vh"> \(highlighted\)<\/span><\/th>/);
assert.match(ht, /<tfoot><tr><th scope="row">All<\/th><td class="n">24,313<\/td>/);
assert.doesNotMatch(ht, /data-k="5"/);  // sparklines do not sort
const click = k => box.onclick({ target: { closest: () => ({ dataset: { k } }) } });
click('1');
assert.match(box.innerHTML, /<th scope="col" class="n" aria-sort="descending">/);  // numbers start largest first
click('1');
ht = box.innerHTML;
assert.match(ht, /aria-sort="ascending"/);
assert.ok(ht.indexOf('>E1<') < ht.indexOf('>A1<') && ht.indexOf('>A1<') < ht.indexOf('>A2<'));  // sorted inside each group

assert.deepEqual(plain([5, 10, 99].map(v => bin(v, [10, 20, 30, 40]))), [1, 2, 5]);
const hm = { innerHTML: '' };
heat(hm, { rows: ['Rack 1'], notes: ['4.2 kW'], cols: ['A', 'B', 'C'], data: [[23104, null, 21000]], unit: 'jobs',
  names: (r, c) => 'ABC'[c] + (r + 1), edges: [21000, 22000, 23000, 24000], mark: (r, c) => c === 0, caption: 'Jobs per host' });
assert.match(hm.innerHTML, /<td class="q4 hl" title="A1: 23,104 jobs"><b>A1<\/b><span>23,104<\/span><span class="vh"> \(highlighted\)<\/span><\/td>/);
assert.match(hm.innerHTML, /<td class="na" title="B1: no data"><b>B1<\/b><span>no data<\/span><\/td>/);
assert.match(hm.innerHTML, /<td class="q2"/);  // an edge value starts its step
assert.match(hm.innerHTML, /<i class="q1"><\/i>under 21,000 jobs<\/span>[^]*<i class="q5"><\/i>24,000 jobs and over[^]*<i class="na"><\/i>no data/);

// ---------- linkmap.js ----------
const { links, path } = load('linkmap.js', 'CrispMap');
assert.deepEqual(plain(links([{ items: [{ id: 'p1', from: ['a', 'b'] }, { id: 'p2', from: ['a'], later: true }, { id: 'p3' }] }])),
  [{ t: 'a', p: 'p1', later: false }, { t: 'b', p: 'p1', later: false }, { t: 'a', p: 'p2', later: true }]);
assert.equal(path({ right: 100, top: 10, height: 20 }, { left: 300, top: 50, height: 40 }, { left: 0, top: 0 }),
  'M100.0,20.0 C200.0,20.0 200.0,70.0 300.0,70.0');

// ---------- lint.mjs: a page made the documented way passes; each broken rule is caught ----------
const good = `<title>Lint Fixture Page</title>\n<meta name="claude:viewport-fit-sides" content="cover">\n` +
  `<style>${read('style.css')}${read('parts.css')}</style>\n<div class="wrap"><i style="background:var(--st-active)"></i></div>\n` +
  `<script>${read('terminal.js')}${read('chart.js')}${read('data.js')}${read('linkmap.js')}</script>\n`;
assert.deepEqual(lintText(good), { errors: [], warnings: [] });
const errs = page => lintText(page).errors.join('\n');
const bad = good.replace('</style>', '.x { color: #fff; border-color: white } .y { --data: #abc; }</style>') +
  '<p>one \u2014 two</p><script src="https://esm.sh/react"></script>' +
  '<script src="https://cdnjs.cloudflare.com/ajax/libs/react/18/react.min.js"></script>' +
  '<script>el.style.fill = "#ff0000";</script><img src="https://example.com/a.png">';
for (const re of [/literal color "#fff" in color/, /literal color "white" in border-color/, /:\d+: em dash/,
  /not on the CDN allowlist: https:\/\/esm\.sh/, /pin an exact x\.y\.z version/, /literal color in a script/, /remote <img>/])
  assert.match(errs(bad), re);
assert.doesNotMatch(errs(bad), /--data/);  // a declared data token is fine
assert.deepEqual(lintText(good + '<p>since 2014, see #top</p>').errors, []);  // plain digits and anchors are not flagged
const noToggle = good.replace(/:root\[data-theme="dark"\] \{[^}]*\}/, '');
assert.match(errs(noToggle), /no :root\[data-theme="dark"\] block/);
assert.match(errs(good.replace('--q5: #45d3c8;\n  }\n}', '--q5: #45d3c8; --new: #123456;\n  }\n}')), /--new is set only in a dark block[\s\S]*--new differs/);
assert.match(errs(good.replace(/<meta name="claude[^>]*>/, '')), /no <meta name="claude:viewport-fit-sides"/);
assert.match(errs(good.replace(/padding-left: max\(16px[^;]*;/, '')), /no padding-left: max\(16px/);
assert.match(errs('<!doctype html>' + good), /own <!doctype> tag/);
assert.match(lintText(good.replace('Lint Fixture Page', 'Plan: what we build next')).warnings.join('\n'), /5 words[\s\S]*explainer/);
assert.match(errs(good + '<svg class="ch" id="c" viewBox="0 0 10 10"></svg>'), /needs role="img" and an aria-label/);
assert.deepEqual(lintText(good + '<svg class="ch" viewBox="0 0 10 10" role="img" aria-label="two lines"></svg>').errors, []);
const usesRng = good + '<script>const r = CrispChart.rng(3);</script>';
assert.match(errs(usesRng), /CrispChart\.rng but shows no/);  // the helper files' own notes do not count as a tag
assert.deepEqual(lintText(usesRng + '<span class="ex">example values</span>').errors, []);
assert.deepEqual(lintText(usesRng.replace('rng(3);', 'rng(3); CrispData.table(el, { ex: true });')).errors, []);

// ---------- spec page: spec-page.mjs and spec-page.js ----------
const lf = t => t.replace(/\r\n/g, '\n');  // a Windows checkout may have CRLF; the checks use LF bytes
assert.equal(cksum(Buffer.from('abc\n')), '1112837078 4');  // what cksum prints, as the ras gate reads it
assert.equal(cksum(Buffer.alloc(0)), '4294967295 0');
const exMd = lf(read('example-spec.md')), exSum = cksum(Buffer.from(exMd));
const EX = specData(exMd, { date: '2 Nov 2026', sum: exSum, example: true });
assert.equal(EX.title, 'Retry failed webhook deliveries');
assert.deepEqual(plain(EX.decisions[2]), { choice: 'Store each try as a row in `delivery_attempts`', rejected: 'a counter on the delivery row', hard: 'yes' });
assert.deepEqual(plain(EX.blast[0].users), ['app/worker.py', 'tests/test_retry.py']);
assert.deepEqual(plain(EX.waves.map(w => [w.name, w.items.length])), [['Wave 0', 1], ['Wave 1', 2], ['Wave 2', 1]]);
assert.deepEqual(plain(EX.other.map(o => o.heading)), ['Proposed additions']);
assert.equal(EX.criteria.length, 4);
assert.deepEqual(plain(specData('# Spec: t\n\n## Decisions\nnone\n', {}).decisions), []);
const built = buildPage(EX);
assert.equal(lf(read('example.html')), lf(built), 'example.html is stale: node spec-page.mjs build example-spec.md example.html --date "2 Nov 2026" --example');
assert.deepEqual(plain(pageData(built)), plain(EX));

// the page renders the data, edits in place only in edit mode, and never offers an approval
const fakeDoc = from => ({ title: 'x', getElementById: () => null, querySelectorAll: sel => {
  const tags = sel.match(/\b(meta|link|style|script)\[data-keep\]/g).map(t => t.split('[')[0]);
  return [...from.matchAll(/<(meta|link)\b[^>]*data-keep=""[^>]*>|<(style|script) data-keep="">[\s\S]*?<\/\2>/g)]
    .filter(m => tags.includes(m[1] || m[2])).map(m => ({ outerHTML: m[0] }));
} });
const pctx = { document: fakeDoc(built) };
runInNewContext(read('spec-page.js') + '\nthis.P = SpecPage;', pctx);
const view = pctx.P.render(EX, false), edit = pctx.P.render(EX, true);
assert.doesNotMatch(view, /contenteditable/);
assert.equal((edit.match(/contenteditable/g) || []).length, 1 + 3 * 3 + 4 + 2 + 2);  // goal, 3 decisions x 3 fields, criteria, non-goals, assumptions
assert.match(view, new RegExp('cksum ' + exSum));
assert.match(view, /This page cannot approve the spec/);
assert.doesNotMatch(view + edit, /<button[^>]*>[^<]*approv/i);
assert.match(view, /<span class="st crit">hard to undo<\/span>/);
assert.match(edit, /data-f="decisions\.0\.rejected" contenteditable/);
assert.match(pctx.P.prose('| A | B |\n|---|---|\n| 1 | <x> |'), /<th scope="col">A<\/th>.*<td>&lt;x&gt;<\/td>/);
// a save publishes the same shape that the build wrote, inside the publish skeleton
pctx.document.title = 'Retry failed webhook deliveries';
assert.equal(pctx.P.documentFor(EX), pctx.P.SKELETON + built + '</body></html>');

// merge: page edits go into the spec; a page built from another spec version is refused
const P = plain(EX);
P.goal = 'Retry failed deliveries, up to 5 times.';
P.decisions[0].rejected = 'a separate queue';
P.criteria[1] = 'After 5 tries the delivery is marked failed: `pytest tests/test_retry.py::test_gives_up`.';
P.nongoals = P.nongoals.slice(0, 1);
P.edited = true;
const mg = merge(exMd, P);
assert.equal(mg.changes.length, 4);
const after = specData(mg.md, {});
for (const k of ['goal', 'decisions', 'criteria', 'nongoals', 'assumptions']) assert.deepEqual(plain(after[k]), plain(P[k]), k);
assert.match(mg.md, /^2\. After 5 tries/m);  // numbered lists stay numbered
assert.match(mg.md, /## Blast radius\n- `app\/webhooks/);  // untouched sections stay as they were
assert.deepEqual(merge(exMd, EX).changes, []);
const crlf = exMd.replace(/\n/g, '\r\n');
assert.ok(merge(crlf, { ...P, cksum: cksum(Buffer.from(crlf)) }).md.includes('\r\n'));  // CRLF stays CRLF
assert.throws(() => merge(exMd + 'x', P), /built from spec cksum/);
assert.deepEqual(merge(exMd + 'x', EX).changes, []);  // an unedited page never blocks a rebuild after the spec changed

// the lint lets a self-saving page keep the publish skeleton in a script, and still catches a real doctype
assert.deepEqual(lintText(good + `<script>const SKELETON = '${pctx.P.SKELETON}';</script>`).errors, []);

for (const page of ['example.html', 'gallery.html']) {
  const res = lintFile(fileURLToPath(new URL('./' + page, import.meta.url)));
  assert.deepEqual(res, { errors: [], warnings: [] }, page + ' lint:\n' + res.errors.join('\n'));
}

// ---------- docs: guides, links and the gallery stay in step with the files ----------
const skill = read('SKILL.md'), guides = readdirSync(new URL('./guides/', import.meta.url)).filter(f => f.endsWith('.md'));
assert.ok(guides.length, 'no guides found');
for (const g of guides) assert.ok(skill.includes(`(guides/${g})`), `SKILL.md does not link guides/${g}`);
for (const doc of ['SKILL.md', ...guides.map(g => 'guides/' + g)])
  for (const [, href] of read(doc).matchAll(/\]\(([^)#\s]+)\)/g))
    if (!/^[a-z]+:/.test(href)) assert.ok(existsSync(new URL(href, new URL('./' + doc, import.meta.url))), `${doc}: broken link ${href}`);
// a part's demo lives in a gallery block marked data-part="<its parts.css section>"; the spec page's demo is example.html
const sections = [...read('parts.css').matchAll(/^\/\* -{10} ([a-z ]+?)(?::| -{10})/gm)].map(m => m[1]);
assert.ok(sections.length >= 13, 'parts.css sections not found');
const demos = [...read('gallery.html').matchAll(/data-part="([^"]*)"/g)].flatMap(m => m[1].split(',').map(s => s.trim()));
for (const s of sections) if (s !== 'spec page') assert.ok(demos.includes(s), `gallery.html has no demo marked data-part="${s}"`);

console.log('artifacts skill terminal.js, chart.js, data.js, linkmap.js, lint.mjs, spec-page.mjs, spec-page.js, example.html, gallery.html, guides and links: PASS');
