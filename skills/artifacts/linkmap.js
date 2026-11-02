/* artifacts skill link map: sources on the left, the things that use them on the right, joined by curves.
   Point at (or Tab to) any box to light up its links and dim the rest. Needs parts.css's "link map" rules.
   Markup: <div class="map" id="map"></div>          mount() fills it with an svg and two columns
   Call:   CrispMap.mount(document.getElementById('map'), [
             { head: 'app.db', note: 'permanent record', items: [
               { id: 't5', name: 'Event log', desc: 'every event and error' },
               { id: 'tdq', name: 'Mail queue', desc: 'alerts waiting to be sent', off: true } ] }  // off: exists, not shown
           ], [
             { head: 'Overview', note: 'home screen · 30 s', items: [
               { id: 'p2', name: 'Open error codes', desc: 'errors not cleared yet', from: ['t5'] },
               { id: 'l1', name: 'Failed jobs', desc: 'error codes over time', from: ['t2'], later: true } ] }  // later: planned
           ]);
   ids are unique across both sides. A right item's `from` lists its sources; they also show as chips under it,
   which is all a phone gets: below 820px the curves hide. A left item used only by `later` items is dashed too.
   head, note, name and desc are HTML. Every link must be a real dependency you read in the source. */
const CrispMap = (() => {
  const WIDE = '(min-width: 820px)';  // parts.css hides the curves at max-width 819px; keep the two in step

  /** Every link, from the right items' `from` lists: [{ t: leftId, p: rightId, later }]. */
  function links(right) {
    return right.flatMap(g => g.items.flatMap(p => (p.from || []).map(t => ({ t, p: p.id, later: !!p.later }))));
  }

  /** Curve from the middle of rect a's right edge to the middle of rect b's left edge, relative to box. */
  function path(a, b, box) {
    const x1 = a.right - box.left, y1 = a.top + a.height / 2 - box.top;
    const x2 = b.left - box.left, y2 = b.top + b.height / 2 - box.top, dx = (x2 - x1) / 2, f = n => n.toFixed(1);
    return `M${f(x1)},${f(y1)} C${f(x1 + dx)},${f(y1)} ${f(x2 - dx)},${f(y2)} ${f(x2)},${f(y2)}`;
  }

  function mount(map, left, right) {
    const all = links(right), box = {}, name = {};
    const el = (cls, html) => { const e = document.createElement('div'); e.className = cls; e.innerHTML = html; return e; };
    const node = (it, cls, extra) => {
      const n = el('node' + cls, `<div class="n">${it.name}</div><div class="d">${it.desc || ''}</div>${extra}`);
      n.tabIndex = 0; n.dataset.id = it.id; box[it.id] = n;
      return n;
    };
    const column = (groups, headCls, make) => {
      const col = el('col', '');
      for (const g of groups) {
        const grp = el('group', '');
        grp.appendChild(el(headCls, `<b>${g.head}</b><span>${g.note || ''}</span>`));
        g.items.forEach(it => grp.appendChild(make(it)));
        col.appendChild(grp);
      }
      map.appendChild(col);
    };

    map.innerHTML = '<svg class="links" aria-hidden="true"></svg>';
    const svg = map.firstChild;
    left.forEach(g => g.items.forEach(it => { name[it.id] = it.name; }));
    column(left, 'ghead', it => {
      const used = all.filter(l => l.t === it.id);
      return node(it, it.off ? ' off' : used.length && used.every(l => l.later) ? ' later' : '', '');
    });
    column(right, 'dhead', it => node(it, it.later ? ' later' : '',
      `<div class="chips">${(it.from || []).map(t => `<span class="chip">${name[t]}</span>`).join('')}</div>`));

    const wide = window.matchMedia(WIDE);
    const draw = () => {
      if (!wide.matches) { svg.innerHTML = ''; return; }
      const b = map.getBoundingClientRect();
      svg.setAttribute('width', b.width); svg.setAttribute('height', b.height);
      svg.setAttribute('viewBox', `0 0 ${b.width} ${b.height}`);
      svg.innerHTML = all.map(l => `<path data-t="${l.t}" data-p="${l.p}"${l.later ? ' class="later"' : ''} d="${
        path(box[l.t].getBoundingClientRect(), box[l.p].getBoundingClientRect(), b)}"/>`).join('');
    };
    const clear = () => {
      map.classList.remove('focus');
      map.querySelectorAll('.on').forEach(e => e.classList.remove('on'));
    };
    const focus = n => {
      clear();
      const id = n.dataset.id, hit = all.filter(l => l.t === id || l.p === id);
      if (!hit.length) return;
      map.classList.add('focus'); n.classList.add('on');
      for (const l of hit) {
        box[l.t].classList.add('on'); box[l.p].classList.add('on');
        svg.querySelectorAll(`path[data-t="${l.t}"][data-p="${l.p}"]`).forEach(p => p.classList.add('on'));
      }
    };
    map.querySelectorAll('.node').forEach(n => {
      n.addEventListener('mouseenter', () => focus(n)); n.addEventListener('focus', () => focus(n));
      n.addEventListener('mouseleave', clear); n.addEventListener('blur', clear);
    });
    draw();
    if (window.ResizeObserver) new ResizeObserver(draw).observe(map); else window.addEventListener('resize', draw);
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(draw);
    wide.addEventListener('change', draw);
  }

  return { links, path, mount };
})();
