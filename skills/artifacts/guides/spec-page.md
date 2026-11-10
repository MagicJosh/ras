# Spec page

The page of a ras spec. The `spec` skill uses this guide. `specs/current.md` stays the single source of truth; the page is a view built from it by `spec-page.mjs`, so there is no markup to write.

[`../example.html`](../example.html) is a sample page built from [`../example-spec.md`](../example-spec.md).

## Build it

Run `node <this skill's folder>/spec-page.mjs build specs/current.md specs/current.html`. It reads the sections, the spec's date and its `cksum` (the checksum the ras gate uses), and writes one page with everything inlined. The header shows the date and the cksum, so a stale page is visible. Then lint it: `node <this skill's folder>/lint.mjs specs/current.html`.

## What it shows

| Spec section | On the page |
|---|---|
| Goal | The goal, as text. |
| Decisions | A card per decision, beside its rejected alternative and "hard to undo". |
| Blast radius | A link map, from lines written as `` - `path`: what changes. Callers: `a`, `b`. `` |
| Work packages (optional) | Waves, from lines written as `- Wave 0: Package. Detail.` |
| Acceptance criteria | A checklist. |
| Non-goals | A list. |
| Assumptions | A list, marked as not confirmed. |
| Every other section | Read-only text. |

## Publish it

- **Capabilities:** publish with `capabilities: { artifact: {}, comments: { composer_only: true } }`. A viewer who can edit changes the goal, decisions, criteria, non-goals and assumptions in place, and saving publishes a new version marked "edited here, not merged yet". The diagrams are rebuilt from the spec, never edited on the page.
- **One page per spec.** Keep its link in `specs/current.url`, one line (git ignores all of `specs/`, and the gate always allows it). The first publish writes it. Every change to the spec rebuilds the page and publishes it to that link (`url`), also in a later session. When no `specs/current.md` exists yet, delete a leftover `specs/current.url`; `finalize` deletes it with the spec's archive step.
- **Merge first.** When a notice says the page changed, and before each republish, read the live page with the Artifact tool's `read` action, then run `node <this skill's folder>/spec-page.mjs merge specs/current.md <the saved file it names>`. It writes the page's edits into the spec and prints each one, or prints `no edits on the page`. It refuses when an edited page was built from another version of the spec; then merge the text by hand. A merge changes the spec, so its approval is gone.
- **Never approval.** The page has no approve button and says that approval is the reply typed in the terminal. Do not add one: the gate trusts only the typed phrase.

## Done when

The page is built from the current spec (the cksum in its header matches `cksum < specs/current.md`), the lint prints PASS, and `specs/current.url` holds the link it was published to.
