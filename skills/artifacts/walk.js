/* artifacts skill walkthrough: one case followed step by step along a stage strip.
   Markup: parts.css "walkthrough". Every step is in the page, so it reads in full without this script.
   Call:  CrispWalk.mount(document.getElementById('walk'))
   It opens one step at a time, marks the stage that step happens in (the .stage with the same data-s gets .hl) and
   adds the "← Step 1 of 5 →" controls above the steps. ← and → also move while a button of the part has focus. */
const CrispWalk = (() => {
  /** The step a key leads to from step `at` of n, kept inside 0..n-1. null: the key is not ours. */
  const step = (at, key, n) => key === 'ArrowRight' ? Math.min(n - 1, at + 1) : key === 'ArrowLeft' ? Math.max(0, at - 1) : null;

  function mount(w) {
    const steps = [...w.querySelectorAll('.steps > li')], stages = [...w.querySelectorAll('.stage')], n = steps.length;
    if (!n) return;
    const ctl = document.createElement('div');
    ctl.className = 'ctl';
    ctl.innerHTML = '<button type="button" class="btn" aria-label="Previous step">←</button><span class="pos" role="status"></span>' +
      '<button type="button" class="btn" aria-label="Next step">→</button>';
    const [prev, pos, next] = ctl.children;
    let at = 0;
    const show = i => {
      at = i;
      steps.forEach((s, k) => { s.classList.toggle('on', k === at); s.querySelector('.sb').setAttribute('aria-expanded', k === at); });
      stages.forEach(s => s.classList.toggle('hl', s.dataset.s === steps[at].dataset.s));
      pos.textContent = `Step ${at + 1} of ${n}`;
      prev.setAttribute('aria-disabled', at === 0); next.setAttribute('aria-disabled', at === n - 1);
    };
    prev.onclick = () => show(step(at, 'ArrowLeft', n));
    next.onclick = () => show(step(at, 'ArrowRight', n));
    steps.forEach((s, k) => { s.querySelector('.sb').onclick = () => show(k); });
    w.addEventListener('keydown', e => {
      const to = e.target.closest('button') ? step(at, e.key, n) : null;  // the arrows stay free for a listing that scrolls
      if (to === null) return;
      e.preventDefault(); show(to);
      if (e.target.classList.contains('sb')) steps[to].querySelector('.sb').focus();  // focus follows the open step
    });
    w.querySelector('.steps').before(ctl);
    w.classList.add('js');
    show(0);
  }

  return { step, mount };
})();
