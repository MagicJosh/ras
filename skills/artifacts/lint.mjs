// artifacts skill page lint. Usage: node lint.mjs page.html [more.html]   Exits 1 on any error; warnings pass.
// Checks a finished page against the Artifact page contract and the house rules in SKILL.md:
//   colors   a literal color (#hex, rgb(), hsl(), a named color) only as a --custom-property value, so a data
//            color is fine once declared as a token; scripts pass var(--token) (terminal.js's palette is exempt)
//   text     no em dashes anywhere: copy, markup, CSS, scripts
//   theme    tokens on bare :root; both dark guards present, each with color-scheme: dark, holding the same
//            tokens and values; body sets a background (light-first pages, which the house look is)
//   hosts    <script src> only from the CDN allowlist at an exact x.y.z version; stylesheets only from Google
//            Fonts; no remote img, iframe, video, audio or embed
//   phone    the claude:viewport-fit-sides meta plus both max(16px, env(safe-area-inset-*)) gutters; an own
//            viewport meta must say viewport-fit=cover (the publish skeleton already adds one)
//   frame    a <title> in the first 8 KB, 2 to 4 words (warning); no doctype, html, head or body tags in the
//            markup (a page that saves itself keeps the publish skeleton in a script, as const SKELETON = '...'; on one line)
//   data     every <svg class="ch"> has role="img" and an aria-label; a page that makes values with CrispChart.rng
//            shows an "example values" tag (class="ex", or ex: true on a CrispData part)
// Relative <link rel=stylesheet> and <script src> files are read and checked as part of the page.
// Layout is out of its reach: phone overflow, contrast and chart scale need the preview look.
import { readFileSync, existsSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const CDN = ['https://cdnjs.cloudflare.com/', 'https://cdn.jsdelivr.net/npm/', 'https://unpkg.com/', 'https://cdn.tailwindcss.com/', 'https://code.jquery.com/'];
const LITERAL = /#[0-9a-f]{3,8}\b|\b(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(/i;
const NAMED = /\b(?:white|black|red|green|blue|gr[ae]y|orange|yellow|purple|pink|brown|navy|teal|silver|maroon|olive|lime|aqua|fuchsia|gold|indigo|violet)\b/i;
const EMDASH = /\u2014|&mdash;|&#8212;|&#x2014;|\\u2014/gi;
const blank = s => s.replace(/[^\n]/g, ' ');  // hides text but keeps offsets, so line numbers stay right
const attr = (tag, name) => (tag.match(new RegExp(`\\s${name}\\s*=\\s*["']?([^"'\\s>]+)`, 'i')) || [])[1];
const remote = url => /^(https?:)?\/\//i.test(url);

/** The text between the { at index open and its matching }. */
function body(css, open) {
  for (let i = open, depth = 0; i < css.length; i++) {
    if (css[i] === '{') depth++;
    else if (css[i] === '}' && --depth === 0) return css.slice(open + 1, i);
  }
  return css.slice(open + 1);
}
const bodies = (css, re) => [...css.matchAll(re)].map(m => body(css, m.index + m[0].length - 1));
const tokens = text => [...text.matchAll(/(--[\w-]+)\s*:\s*([^;{}]+)/g)].map(m => [m[1], m[2].trim()]);

/** Lint page text. dir resolves the page's relative files. Returns { errors, warnings } as "file:line: msg". */
export function lintText(html, file = 'page.html', dir = '.') {
  const errors = new Set(), warnings = new Set();
  const at = (src, name, i) => `${name}:${src.slice(0, i).split('\n').length}`;
  const files = [{ src: html, name: file }], css = [], js = [];  // css and js chunks: { src, name, at, text }
  const inner = m => m.index + m[0].indexOf('>') + 1;

  const local = (url, list, i) => {
    const p = resolve(dir, url.split(/[?#]/)[0]);
    if (!existsSync(p)) return errors.add(`${at(html, file, i)}: ${url} is not next to the page`);
    const src = readFileSync(p, 'utf8'), name = basename(p);
    files.push({ src, name });
    list.push({ src, name, at: 0, text: src });
  };
  const noScript = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, blank);  // a <style> inside a script string is not page CSS
  for (const m of noScript.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)) css.push({ src: html, name: file, at: inner(m), text: m[1] });
  for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
    const src = attr(m[1], 'src'), where = at(html, file, m.index);
    if (!src) js.push({ src: html, name: file, at: inner(m), text: m[2] });
    else if (!remote(src)) local(src, js, m.index);
    else if (!CDN.some(h => src.replace(/^\/\//, 'https://').startsWith(h))) errors.add(`${where}: script host is not on the CDN allowlist: ${src}`);
    else if (!/\d+\.\d+\.\d+/.test(src) || /@(latest|next)\b/.test(src)) errors.add(`${where}: pin an exact x.y.z version: ${src}`);
  }
  for (const m of html.matchAll(/<link\b[^>]*>/gi)) {
    const href = attr(m[0], 'href');
    if (!href || !/stylesheet/i.test(attr(m[0], 'rel') || '')) continue;
    if (!remote(href)) local(href, css, m.index);
    else if (!href.startsWith('https://fonts.googleapis.com/')) errors.add(`${at(html, file, m.index)}: stylesheets load only from fonts.googleapis.com: ${href}`);
  }
  for (const m of html.matchAll(/<(img|iframe|video|audio|source|embed|object)\b[^>]*\s(?:src|data)\s*=\s*["']?(?:https?:)?\/\//gi))
    errors.add(`${at(html, file, m.index)}: the page CSP blocks a remote <${m[1]}>; embed it as a data: URI or link out`);

  // colors: CSS declarations, style="" attributes, and color strings in scripts
  const decls = (text, src, name, base) => {
    for (const m of text.matchAll(/([-\w]+)\s*:\s*([^;{}]+)/g)) {
      if (m[1].startsWith('--')) continue;
      const v = m[2].replace(/var\([^()]*\)|url\([^()]*\)|"[^"]*"|'[^']*'/g, '');
      const hit = v.match(LITERAL) || v.match(NAMED);
      if (hit) errors.add(`${at(src, name, base + m.index)}: literal color "${hit[0]}" in ${m[1]}; use a token, or declare a data token on :root`);
    }
  };
  const nocomments = t => t.replace(/\/\*[\s\S]*?\*\//g, blank);
  for (const c of css) decls(nocomments(c.text), c.src, c.name, c.at);
  for (const m of html.matchAll(/\sstyle\s*=\s*(?:"([^"]*)"|'([^']*)')/gi)) decls(m[1] ?? m[2], html, file, m.index + m[0].search(/["']/) + 1);
  for (const c of js) {
    const text = c.text.replace(/const CrispTerm = \(\(\) => \{[\s\S]*?\n\}\)\(\);/, blank)  // terminal colors are data
      .replace(/const SKELETON = '[^\n]*';/, blank);  // the publish skeleton's own colors
    for (const m of text.matchAll(/(['"`])\s*(?:#[0-9a-f]{3,8}|(?:rgba?|hsla?)\([^)'"`]*\))\s*\1|(?:color|background|fill|stroke|border[-\w]*)\s*:\s*#[0-9a-f]{3,8}\b/gi))
      errors.add(`${at(c.src, c.name, c.at + m.index)}: literal color in a script; pass var(--token) instead`);
  }

  for (const f of files) for (const m of f.src.matchAll(EMDASH)) errors.add(`${at(f.src, f.name, m.index)}: em dash; use a colon, a comma or a new sentence`);

  // theme: every dark token starts on bare :root, and both dark blocks agree
  const all = css.map(c => nocomments(c.text)).join('\n');
  const root = new Map(bodies(all, /(?:^|[\s;{}]):root\s*\{/g).flatMap(tokens));
  const media = bodies(all, /@media\s*\(\s*prefers-color-scheme\s*:\s*dark\s*\)\s*\{/g).flatMap(b => bodies(b, /:root:not\(\[data-theme=["']?light["']?\]\)\s*\{/g));
  const toggle = bodies(all, /:root\[data-theme=["']?dark["']?\]\s*\{/g);
  if (!media.length) errors.add(`${file}: no dark guard: @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { ... } }`);
  if (!toggle.length) errors.add(`${file}: no :root[data-theme="dark"] block, so the viewer's toggle cannot switch to dark`);
  const m1 = new Map(media.flatMap(tokens)), m2 = new Map(toggle.flatMap(tokens));
  for (const k of new Set([...m1.keys(), ...m2.keys()])) {
    if (!root.has(k)) errors.add(`${file}: ${k} is set only in a dark block; define it on bare :root first`);
    if (media.length && toggle.length && m1.get(k) !== m2.get(k)) errors.add(`${file}: ${k} differs between the two dark blocks (${m1.get(k)} vs ${m2.get(k)})`);
  }
  if ([...media, ...toggle].some(b => !/color-scheme\s*:\s*dark/.test(b))) errors.add(`${file}: a dark block lacks color-scheme: dark`);
  if (!/(?:^|[\s;{}])body\s*\{[^}]*background/.test(all)) errors.add(`${file}: body sets no background, so the host's background shows through`);

  // phone gutter and viewport
  const sides = html.match(/<meta\b[^>]*claude:viewport-fit-sides[^>]*>/i);
  if (!sides || !/content\s*=\s*["']?cover/i.test(sides[0])) errors.add(`${file}: no <meta name="claude:viewport-fit-sides" content="cover"> beside the title`);
  for (const s of ['left', 'right'])
    if (!new RegExp(`padding-${s}\\s*:\\s*max\\(\\s*16px\\s*,\\s*env\\(\\s*safe-area-inset-${s}`).test(all)) errors.add(`${file}: no padding-${s}: max(16px, env(safe-area-inset-${s}, 0px)) gutter (style.css .wrap has it)`);
  const vp = html.match(/<meta\b[^>]*name\s*=\s*["']?viewport["'\s>][^>]*>/i);
  if (vp && !/viewport-fit\s*=\s*cover/i.test(vp[0])) errors.add(`${at(html, file, vp.index)}: an own viewport meta needs viewport-fit=cover, or drop it: the skeleton adds one`);

  // frame
  const t = html.slice(0, 8192).match(/<title>([^<]*)<\/title>/i);
  if (!t) errors.add(`${file}: no <title> in the first 8 KB`);
  else {
    const name = t[1].trim(), words = name.split(/\s+/).filter(Boolean).length;
    if (words < 2 || words > 4) warnings.add(`${file}: title "${name}" has ${words} words; a page name is usually 2 to 4`);
    if (/\s[-–|]\s|:\s/.test(name)) warnings.add(`${file}: title "${name}" carries an explainer; put it in the publish description`);
  }

  // data: charts say what they draw, and made-up values are tagged as such. Only the page's own markup and script
  // count: the helper files and comments show these tags in their usage notes.
  const markup = html.replace(/<(style|script)\b[^>]*>[\s\S]*?<\/\1>|<!--[\s\S]*?-->/gi, blank);
  const sk = markup.match(/<(!doctype|html|head|body)[\s>]/i);
  if (sk) errors.add(`${at(html, file, sk.index)}: own <${sk[1]}> tag; the publish skeleton supplies it`);
  const pageJs = js.map(c => c.text.replace(/const Crisp\w+ = \(\(\) => \{[\s\S]*?\n\}\)\(\);/g, '').replace(/\/\*[\s\S]*?\*\//g, '')).join('\n');
  for (const m of markup.matchAll(/<svg\b[^>]*>/gi)) {
    if (!/\sclass\s*=\s*["']?[^"'>]*\bch\b/i.test(m[0])) continue;
    if (!/\srole\s*=\s*["']?img\b/i.test(m[0]) || !/\saria-label\s*=\s*(?:"[^"]*\S[^"]*"|'[^']*\S[^']*')/i.test(m[0]))
      errors.add(`${at(html, file, m.index)}: a chart <svg class="ch"> needs role="img" and an aria-label that says what the drawn data shows`);
  }
  if (/\bCrispChart\.rng\(/.test(pageJs) && !/class\s*=\s*["']?[^"'>]*\bex\b/.test(markup + pageJs) && !/\bex\s*:\s*true\b/.test(pageJs))
    errors.add(`${file}: the page makes values with CrispChart.rng but shows no <span class="ex">example values</span> tag`);

  return { errors: [...errors], warnings: [...warnings] };
}

export const lintFile = path => lintText(readFileSync(path, 'utf8'), basename(path), dirname(resolve(path)));

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const pages = process.argv.slice(2);
  if (!pages.length) console.log('usage: node lint.mjs page.html [more.html]');
  let failed = !pages.length;
  for (const p of pages) {
    const { errors, warnings } = lintFile(p);
    for (const e of errors) console.log('  error ' + e);
    for (const w of warnings) console.log('  warn  ' + w);
    console.log(`${errors.length ? 'FAIL' : 'PASS'} ${basename(p)}: ${errors.length} errors, ${warnings.length} warnings`);
    failed ||= errors.length > 0;
  }
  process.exitCode = failed ? 1 : 0;
}
