// Spec page: builds the Artifact view of specs/current.md, and merges text edited on the page back into the spec.
//   node spec-page.mjs build specs/current.md specs/current.html [--date "2 Nov 2026"] [--example]
//   node spec-page.mjs merge specs/current.md <saved live page.html>
// build: reads the spec's sections, its date (the file's change date, or --date) and its cksum, the same checksum the
//   ras gate uses, and writes one page: style.css, parts.css, linkmap.js and spec-page.js inlined, the spec as JSON.
// merge: reads the JSON from the live page (the file the Artifact tool's read action saved); if it was saved with edits, it
//   writes the edited goal, decisions, criteria, non-goals and assumptions into the spec and prints each change. It
//   refuses when an edited page was built from another version of the spec (its cksum differs): the edits cannot be placed.
// The spec stays the single source of truth: the page is a view of it, and approval happens only in the terminal.
import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const here = f => new URL('./' + f, import.meta.url);
const EDITABLE = ['goal', 'decisions', 'criteria', 'nongoals', 'assumptions'];
const HEAD = { goal: 'Goal', decisions: 'Decisions', criteria: 'Acceptance criteria', nongoals: 'Non-goals', assumptions: 'Assumptions' };

/** POSIX cksum of a byte buffer, as `cksum < file` prints it: "<crc> <bytes>". */
const T = Array.from({ length: 256 }, (_, i) => {
  let c = i << 24;
  for (let k = 0; k < 8; k++) c = c & 0x80000000 ? (c << 1) ^ 0x04c11db7 : c << 1;
  return c >>> 0;
});
export function cksum(buf) {
  let c = 0;
  const step = b => { c = ((c << 8) ^ T[((c >>> 24) ^ b) & 255]) >>> 0; };
  for (const b of buf) step(b);
  for (let n = buf.length; n > 0; n = Math.floor(n / 256)) step(n & 255);
  return `${~c >>> 0} ${buf.length}`;
}

/** The spec's title and its ## sections, in order: [{ heading, lines }]. */
export function sections(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n'), out = [];
  let title = '', cur = null;
  for (const l of lines) {
    const h1 = l.match(/^# (?:Spec:\s*)?(.+?)\s*$/), h2 = l.match(/^## (.+?)\s*$/);
    if (h2) out.push(cur = { heading: h2[1], lines: [] });
    else if (h1 && !cur && !title) title = h1[1];
    else if (cur) cur.lines.push(l);
  }
  return { title, list: out };
}

/** List items of a section body; an indented line continues the item above it. Text that is not a list: []. */
function items(lines) {
  const out = [];
  for (const l of lines) {
    const m = l.match(/^\s{0,3}(?:[-*+]|\d+[.)])\s+(.*)$/);
    if (m) out.push(m[1].trim());
    else if (out.length && /^\s+\S/.test(l)) out[out.length - 1] += ' ' + l.trim();
  }
  return out;
}
const prose = lines => lines.map(l => l.trim()).filter(Boolean).join(' ');
const key = heading => Object.keys(HEAD).find(k => heading.toLowerCase() === HEAD[k].toLowerCase());

/** One decision line: "<choice>. Rejected: <alternative>. Hard to undo: yes|no." Other shapes keep the whole line. */
export function decision(line) {
  const m = line.match(/^(.*?)\.?\s+Rejected:\s*(.*?)\.?\s+Hard to undo:\s*(yes|no)\.?$/i);
  return m ? { choice: m[1].trim(), rejected: m[2].trim(), hard: m[3].toLowerCase() } : { choice: line, rejected: null, hard: null };
}
const decisionLine = d => d.rejected == null ? d.choice
  : `${d.choice.replace(/\.$/, '')}. Rejected: ${d.rejected.replace(/\.$/, '')}. Hard to undo: ${d.hard}.`;

/** Blast radius line "`path`: what changes. Callers: `a`, `b`." -> { file, note, users }. */
function blastItem(line) {
  const [head, callers = ''] = line.split(/\b(?:Callers|Used by):/i);
  const file = (head.match(/`([^`]+)`/) || head.match(/^(\S+)/) || [])[1] || head;
  const note = head.replace(/`[^`]+`/, '').replace(/^[\s:.,-]+/, '').trim();
  const users = [...callers.matchAll(/`([^`]+)`/g)].map(m => m[1]);
  if (!users.length && callers.trim()) users.push(...callers.split(',').map(s => s.trim().replace(/\.$/, '')).filter(Boolean));
  return { file: file.replace(/[.,:]$/, ''), note, users };
}

/** Work packages: "- Wave 0: <package>. <detail>" lines, grouped by the label before the colon. */
function waves(list) {
  const out = [];
  for (const it of list) {
    const m = it.match(/^([^:]{1,30}):\s*(.*)$/), name = m ? m[1].trim() : 'Work', rest = m ? m[2] : it;
    const [, t, d] = rest.match(/^(.*?)(?:\.\s+(.*))?$/);
    let w = out.find(x => x.name === name);
    if (!w) out.push(w = { name, items: [] });
    w.items.push({ title: t.replace(/\.$/, ''), detail: d || '' });
  }
  return out;
}

/** The page data for a spec. */
export function specData(md, { date, sum, example = false }) {
  const { title, list } = sections(md);
  const D = { title, date, cksum: sum, source: 'specs/current.md', example, edited: false,
    goal: '', decisions: [], decisionsNote: '', criteria: [], nongoals: [], assumptions: [], blast: [], waves: [], other: [] };
  for (const s of list) {
    const k = key(s.heading);
    if (k === 'goal') D.goal = prose(s.lines);
    else if (k === 'decisions') { D.decisions = items(s.lines).map(decision); if (!D.decisions.length) D.decisionsNote = prose(s.lines); }
    else if (k) D[k] = items(s.lines);
    else if (/^blast radius$/i.test(s.heading)) D.blast = items(s.lines).map(blastItem);
    else if (/^work packages$/i.test(s.heading)) D.waves = waves(items(s.lines));
    else D.other.push({ heading: s.heading, md: s.lines.join('\n').trim() });
  }
  return D;
}

/** "2 Nov 2026" */
export const day = d => d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }).replace('Sept', 'Sep');

const json = D => JSON.stringify(D, null, 1).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

/** The page. Its order matches documentFor() in spec-page.js, so a save from the page keeps the same shape. */
export function buildPage(D) {
  const read = f => {
    const s = readFileSync(here(f), 'utf8');
    const tag = f.endsWith('.css') ? 'style' : 'script';
    if (new RegExp(`</${tag}`, 'i').test(s)) throw new Error(`${f} holds a closing </${tag}>, which would end the inlined block early`);
    return s;
  };
  const name = D.title.split(/\s+/).slice(0, 4).join(' ') || 'Spec';
  // Attributes are written the way a browser serializes them (data-keep="", &amp;), so a save from the page matches.
  return `<title>${esc(name)}</title>
<meta name="claude:viewport-fit-sides" content="cover" data-keep="">
<link rel="preconnect" href="https://fonts.googleapis.com" data-keep="">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="" data-keep="">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&amp;family=JetBrains+Mono:wght@400;700&amp;display=swap" rel="stylesheet" data-keep="">
<style data-keep="">
${read('style.css')}
${read('parts.css')}
</style>
<script type="application/json" id="spec-data">${json(D)}</script>
<div class="wrap" id="app"></div>
<script data-keep="">
${read('linkmap.js')}
${read('spec-page.js')}
</script>
`;
}

/** The page data inside a page, saved or freshly built. */
export function pageData(html) {
  const m = html.match(/<script type="application\/json" id="spec-data">([\s\S]*?)<\/script>/);
  if (!m) throw new Error('no spec data in this page; is it a spec page?');
  return JSON.parse(m[1]);
}

/** Write the edited sections of page data P into the spec md. Returns { md, changes }. */
export function merge(md, P) {
  if (!P.edited) return { md, changes: [] };  // nothing saved on the page since it was built
  const now = cksum(Buffer.from(md, 'utf8'));
  if (P.cksum !== now) throw new Error(`the page was built from spec cksum ${P.cksum}, the spec is now ${now}; merge the page text by hand`);
  const D = specData(md, {}), changes = [], nl = md.includes('\r\n') ? '\r\n' : '\n';
  let out = md.replace(/\r\n/g, '\n');
  for (const k of EDITABLE) {
    const a = JSON.stringify(D[k]), b = JSON.stringify(P[k] ?? D[k]);
    if (a === b) continue;
    let body;
    if (k === 'goal') { body = P.goal; changes.push(`Goal: "${D.goal}" -> "${P.goal}"`); }
    else {
      const was = k === 'decisions' ? D[k].map(decisionLine) : D[k], is = k === 'decisions' ? P[k].map(decisionLine) : P[k];
      const n = Math.max(was.length, is.length);
      for (let i = 0; i < n; i++) if (was[i] !== is[i])
        changes.push(`${HEAD[k]} ${i + 1}: ${was[i] == null ? 'added' : `"${was[i]}"`} -> ${is[i] == null ? 'removed' : `"${is[i]}"`}`);
      const numbered = /\n\s*\d+[.)]\s/.test(sectionText(out, HEAD[k]));
      body = is.map((t, i) => (numbered ? `${i + 1}. ` : '- ') + t).join('\n') || 'none';
    }
    out = replaceSection(out, HEAD[k], body);
  }
  return { md: out.replace(/\n/g, nl), changes };
}
function span(md, heading) {
  const re = new RegExp(`^## ${heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`, 'mi'), m = re.exec(md);
  if (!m) return null;
  const start = m.index + m[0].length, next = md.slice(start).search(/^## /m);
  return [start, next < 0 ? md.length : start + next];
}
function sectionText(md, heading) { const s = span(md, heading); return s ? md.slice(s[0], s[1]) : ''; }
function replaceSection(md, heading, body) {
  const s = span(md, heading);
  if (!s) return md.replace(/\n*$/, `\n\n## ${heading}\n${body}\n`);
  const tail = s[1] < md.length ? '\n\n' : '\n';
  return md.slice(0, s[0]) + '\n' + body + tail + md.slice(s[1]);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [cmd, spec, page] = process.argv.slice(2), opt = process.argv.slice(5);
  const usage = 'usage: node spec-page.mjs build <spec.md> <page.html> [--date "2 Nov 2026"] [--example]\n       node spec-page.mjs merge <spec.md> <saved page.html>';
  try {
    if (!spec || !page) throw new Error(usage);
    const md = readFileSync(spec);
    if (cmd === 'build') {
      const di = opt.indexOf('--date'), date = di >= 0 ? opt[di + 1] : day(statSync(spec).mtime);
      const D = specData(md.toString('utf8'), { date, sum: cksum(md), example: opt.includes('--example') });
      writeFileSync(page, buildPage(D));
      console.log(`built ${page} from ${spec} (cksum ${D.cksum}, ${D.date})`);
    } else if (cmd === 'merge') {
      const { md: out, changes } = merge(md.toString('utf8'), pageData(readFileSync(page, 'utf8')));
      if (!changes.length) { console.log('no edits on the page'); }
      else { writeFileSync(spec, out); console.log(`merged ${changes.length} edits into ${spec}:\n` + changes.map(c => '  ' + c).join('\n')); }
    } else throw new Error(usage);
  } catch (e) { console.error('spec-page: ' + e.message); process.exitCode = 1; }
}
