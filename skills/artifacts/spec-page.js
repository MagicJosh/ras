/* artifacts skill spec page: renders the spec data (the JSON that spec-page.mjs put in #spec-data) and lets a viewer
   who can edit the page change its text blocks in place. Needs linkmap.js before it and parts.css's "spec page" rules.
   Saving publishes the whole page again through the artifact capability, with the edited data and edited: true;
   Claude merges that text into specs/current.md with spec-page.mjs merge. The page never approves anything: the ras
   gate trusts only the phrase typed in the terminal. Comments go through the comments capability's composer.
   Declare on publish: capabilities { artifact: {}, comments: { composer_only: true } }. */
const SpecPage = (() => {
  // The publish skeleton, exactly as the Artifact tool wraps a page, so a later publish from the tool replaces it.
  const SKELETON = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}html{scroll-padding-top:env(safe-area-inset-top,0px)}body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#000}img{max-width:100%}[hidden]:not([hidden=until-found i]){display:none!important}</style></head><body>';
  const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const inline = s => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>').replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
  const json = D => JSON.stringify(D, null, 1).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');

  /** Read-only markdown for the sections the page does not edit: paragraphs, lists and pipe tables. */
  function prose(md) {
    const out = [];
    let list = null, table = null;
    const flush = () => {
      if (list) out.push('<ul>' + list.map(t => `<li>${inline(t)}</li>`).join('') + '</ul>');
      if (table) out.push('<table>' + table.filter(r => !/^[\s|:-]+$/.test(r)).map((r, i) => '<tr>' + r.replace(/^\||\|$/g, '').split('|')
        .map(c => i ? `<td>${inline(c.trim())}</td>` : `<th scope="col">${inline(c.trim())}</th>`).join('') + '</tr>').join('') + '</table>');
      list = table = null;
    };
    for (const l of md.split('\n')) {
      const li = l.match(/^\s*(?:[-*+]|\d+[.)])\s+(.*)$/);
      if (/^\s*\|/.test(l)) { if (!table) flush(); (table = table || []).push(l.trim()); }
      else if (li) { if (!list) flush(); (list = list || []).push(li[1]); }
      else if (!l.trim()) flush();
      else { flush(); out.push(`<p>${inline(l.trim())}</p>`); }
    }
    flush();
    return out.join('');
  }

  /** The whole page for data D, in the order spec-page.mjs builds it: skeleton, title, kept head, data, app, kept script. */
  function documentFor(D) {
    const keep = sel => [...document.querySelectorAll(sel)].map(e => e.outerHTML).join('\n');
    return SKELETON + `<title>${esc(document.title)}</title>\n` + keep('meta[data-keep], link[data-keep], style[data-keep]') +
      `\n<script type="application/json" id="spec-data">${json(D)}<\/script>\n<div class="wrap" id="app"></div>\n` +
      keep('script[data-keep]') + '\n</body></html>';
  }

  // One editable text block: data-f is its path in the data ("goal", "criteria.2", "decisions.0.rejected").
  const ed = (path, text, editing, tag = 'span') =>
    `<${tag} class="t" data-f="${path}"${editing ? ' contenteditable="plaintext-only" spellcheck="true"' : ''}>${editing ? esc(text) : inline(text)}</${tag}>`;
  const sec = (id, title, sub, body) =>
    `<section class="sec" data-sec="${id}"><h2>${title} <button type="button" class="cmt" hidden>Comment</button></h2>${sub ? `<p class="sub">${sub}</p>` : ''}${body}</section>`;

  function render(D, editing) {
    const ex = D.example ? ' <span class="ex">example values</span>' : '';
    const decisions = D.decisions.length ? '<div class="grid">' + D.decisions.map((d, i) => `<div class="card dec"><h4>Decision ${i + 1}${d.hard == null ? ''
      : d.hard === 'yes' ? ' <span class="st crit">hard to undo</span>' : ' <span class="st ok">easy to undo</span>'}</h4>${ed(`decisions.${i}.choice`, d.choice, editing, 'p')}${d.rejected == null ? ''
      : `<p class="alt">Rejected: ${ed(`decisions.${i}.rejected`, d.rejected, editing)}</p>${editing ? `<p class="alt">Hard to undo: ${ed(`decisions.${i}.hard`, d.hard, editing)}</p>` : ''}`}</div>`).join('') + '</div>'
      : `<p class="note">${inline(D.decisionsNote || 'None: the change has one obvious shape.')}</p>`;
    const list = (k, cls, mark) => D[k].length ? `<ol class="${cls}">` + D[k].map((t, i) =>
      `<li${mark ? ` class="${mark}"` : ''}>${cls === 'checks' ? `<span class="box" aria-hidden="true"></span><span class="n">${i + 1}</span>` : ''}${ed(`${k}.${i}`, t, editing)}</li>`).join('') + '</ol>'
      : '<p class="note">None written.</p>';
    const users = [...new Set(D.blast.flatMap(b => b.users))];
    const map = !D.blast.length ? '<p class="note">None written.</p>' : users.length
      ? '<div class="legend"><span><i class="hot"></i>the one you point at</span></div><div class="map" id="map"></div>'
      : '<ol class="plain">' + D.blast.map(b => `<li><span class="t"><code>${esc(b.file)}</code> ${inline(b.note)}</span></li>`).join('') + '</ol>';
    let letter = 0;
    const waves = D.waves.length ? sec('waves', 'Work packages', 'From the spec\'s Work packages section, in order.', '<div class="waves">' + D.waves.map(w =>
      `<div class="wave"><div class="wk"><span>${esc(w.name)}</span></div>` + w.items.map(p =>
        `<div class="pk"><b>${String.fromCharCode(65 + letter++)}</b>${inline(p.title)}${p.detail ? `<div class="pd">${inline(p.detail)}</div>` : ''}</div>`).join('') + '</div>').join('') + '</div>') : '';
    return `<header>
  <div class="eyebrow">Spec · ${esc(D.source)}</div>
  <h1>${esc(D.title || 'Spec')}</h1>
  <p class="lede">${ed('goal', D.goal, editing)}</p>
  <div class="meta"><span class="badge">view of ${esc(D.source)}</span><span>spec of ${esc(D.date)}</span><span>cksum ${esc(D.cksum)}</span>${D.edited ? '<span class="st warn">edited here, not merged yet</span>' : ''}${ex}</div>
  <p class="gate">This page cannot approve the spec. Approval is the reply <code>approve spec</code>, typed in the terminal. Text saved here changes the spec, so Claude merges it into <code>${esc(D.source)}</code> and asks for approval again.</p>
  <div class="tools" hidden><button type="button" class="btn" data-act="edit">Edit text</button><button type="button" class="btn" data-act="save" hidden>Save edits</button><button type="button" class="btn" data-act="cancel" hidden>Cancel</button><span class="say" role="status" aria-live="polite"></span></div>
</header>
${sec('decisions', 'Decisions', 'Each choice next to the alternative it beat, and whether it is hard to undo.', decisions)}
${sec('blast', 'What changes', 'From Blast radius: the files the change touches, joined to the callers the spec names.', map)}
${waves}
${sec('criteria', 'Acceptance criteria', 'Checks that can run, with their commands. The boxes stay empty: this page does not run them.', list('criteria', 'checks'))}
${sec('nongoals', 'Non-goals', 'What this change will not do.', list('nongoals', 'plain'))}
${sec('assumptions', 'Assumptions and open items', 'Decided without the user, each with the default taken. Not confirmed yet.', list('assumptions', 'plain', 'assumed'))}
${D.other.map((o, i) => sec('other' + i, esc(o.heading), '', `<div class="prose">${prose(o.md)}</div>`)).join('\n')}
<footer>Source: <code>${esc(D.source)}</code>, cksum ${esc(D.cksum)}, as of ${esc(D.date)}. Built by the artifacts skill's <code>spec-page.mjs</code>; the diagrams are rebuilt from the spec, not edited here.${D.example ? ' Every value on this page is an example.' : ''}</footer>`;
  }

  /** Start: render, then light up editing and comments when the viewer's shell grants them. */
  function start() {
    const app = document.getElementById('app');
    let D = JSON.parse(document.getElementById('spec-data').textContent), editing = false, artifact = null, comments = null;
    const $ = s => app.querySelector(s);
    const say = t => { $('.say').textContent = t; };
    const draw = () => {
      app.innerHTML = render(D, editing);
      if (!editing && $('#map')) {
        const users = [...new Set(D.blast.flatMap(b => b.users))];
        CrispMap.mount($('#map'),
          [{ head: 'Changes', note: 'files in Blast radius', items: D.blast.map((b, i) => ({ id: 'f' + i, name: `<code>${esc(b.file)}</code>`, desc: inline(b.note) })) }],
          [{ head: 'Used by', note: 'callers the spec names', items: users.map((u, j) => ({ id: 'u' + j, name: `<code>${esc(u)}</code>`,
            from: D.blast.map((b, i) => b.users.includes(u) ? 'f' + i : null).filter(Boolean) })) }]);
      }
      if (artifact) { $('.tools').hidden = false; ['edit', 'save', 'cancel'].forEach(a => { $(`[data-act="${a}"]`).hidden = (a === 'edit') === editing; }); }
      if (comments) app.querySelectorAll('.cmt').forEach(b => { b.hidden = false; });
    };
    const readOnly = () => { artifact = null; editing = false; draw(); $('.tools').hidden = false; say('This view is read-only.'); };
    async function save() {
      const next = JSON.parse(JSON.stringify(D));
      app.querySelectorAll('[data-f]').forEach(el => {
        const path = el.dataset.f.split('.'), last = path.pop();
        path.reduce((o, k) => o[k], next)[last] = el.textContent.replace(/\s+/g, ' ').trim();
      });
      for (const k of ['criteria', 'nongoals', 'assumptions']) next[k] = next[k].filter(Boolean);  // an emptied item is removed
      next.decisions.forEach(d => { if (d.hard != null) d.hard = /^y/i.test(d.hard) ? 'yes' : 'no'; });
      if (JSON.stringify(next) === JSON.stringify(D)) { editing = false; draw(); say('Nothing changed.'); return; }
      next.edited = true;
      say('Saving...');
      try {
        await artifact.publish(documentFor(next));  // every open view reloads to the new version
      } catch (e) {
        const code = e && e.code;
        if (code === 'conflict') say('Someone saved first. The page reloads to their version.');
        else if (code === 'rate_limited') say('Saving too often. Wait a minute, then save again.');
        else if (['not_writer', 'not_granted', 'not_declared', 'consent_required', 'capability_disabled', 'capability_removed'].includes(code)) readOnly();
        else say(`Could not save (${code || 'error'}). Your text is still in the boxes.`);
      }
    }
    app.addEventListener('click', e => {
      const b = e.target.closest('button');
      if (!b) return;
      if (b.classList.contains('cmt') && comments) comments.openComposer({ element: b.closest('section') }).catch(() => {});
      else if (b.dataset.act === 'edit') { editing = true; draw(); say('Edit the boxed text. Clear an item to remove it.'); }
      else if (b.dataset.act === 'cancel') { editing = false; draw(); say(''); }
      else if (b.dataset.act === 'save') save();
    });
    draw();
    const claude = window.claude;  // missing in a local preview: the page then stays read-only
    if (claude && claude.use) {
      const later = () => { if (!editing) draw(); };
      claude.use('artifact').then(a => { artifact = a; later(); }).catch(() => {});
      claude.use('comments').then(c => { comments = c; later(); }).catch(() => {});
    }
  }

  if (typeof document !== 'undefined' && document.getElementById('spec-data')) start();
  return { prose, render, documentFor, SKELETON };
})();
