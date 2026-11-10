/* artifacts skill "your call": turns the reader's ticked answers into one reply line and copies it.
   Markup: parts.css "your call". Each <fieldset> is one question, numbered in page order. Its radio inputs hold the
   words for the reply in value="", and the recommended one carries data-rec (and checked, so "yes" is one click).
   Call:  CrispAsk.mount(form)
          CrispAsk.mount(form, { save })    save(text, answers) also stores the reply, such as in the page's db. It
                                            returns true (saved), false (failed) or null (no storage in this view).
          CrispAsk.mount(form, { build })   build(form) returns your own reply text, '' for nothing to send.
   The reply is "yes" when every question keeps its recommended answer, else "1: words; 2: words". A note is added
   as ". Note: words". The line shows under the button and goes to the clipboard. When the copy is refused, the line
   is selected instead, so the reader can copy it by hand. */
const CrispAsk = (() => {
  /** The reply line. answers: one { value, rec } per question, null for a question left open. */
  function reply(answers, note = '') {
    const n = note.trim();
    const body = !answers.some(Boolean) ? '' : answers.every(a => a && a.rec) ? 'yes'
      : answers.map((a, i) => `${i + 1}: ${a ? a.value : 'no answer'}`).join('; ');
    return body && n ? `${body}. Note: ${n}` : body || (n ? `Note: ${n}` : '');
  }

  /** What the status line says after a press. saved: true, false, or null when there was nothing to save to. */
  const status = (copied, saved) =>
    (saved ? 'Saved on this page. ' : saved === false ? 'Not saved on this page, so paste the line. ' : '') +
    (copied ? 'Copied: paste it in the terminal.' : 'The line below is selected: copy it by hand.');

  function mount(form, { build, save } = {}) {
    const out = form.querySelector('.out'), say = form.querySelector('.say'), note = form.querySelector('textarea');
    const answers = () => [...form.querySelectorAll('fieldset')].map(f => {
      const pick = f.querySelector('input:checked');
      return pick ? { value: pick.value, rec: pick.hasAttribute('data-rec') } : null;
    });
    let busy = false;
    // the button's click, not the form's submit event: Enter in an answer clicks the button too, and the form never submits
    form.querySelector('[type=submit]').addEventListener('click', async e => {
      e.preventDefault();
      if (busy) return;
      const given = answers(), text = build ? build(form) : reply(given, note ? note.value : '');
      if (!text) { say.textContent = 'Tick an answer or write a note first.'; return; }
      busy = true;
      out.textContent = text; out.hidden = false;
      let copied = true, saved = null;
      try { await navigator.clipboard.writeText(text); }
      catch (err) {
        copied = false;
        const r = document.createRange(), sel = getSelection();
        r.selectNodeContents(out); sel.removeAllRanges(); sel.addRange(r);
      }
      if (save) try { saved = await save(text, given); } catch (err) { saved = false; }
      say.textContent = status(copied, saved);
      busy = false;
    });
  }

  return { reply, status, mount };
})();
