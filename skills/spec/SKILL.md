---
name: spec
description: Use when the user runs /spec or asks for a plan, or when the ras hook denied an edit to a risky path. Asks what is unknown, writes specs/current.md, stops for approval.
---

# Spec

Write the contract before you touch the files. Ordinary changes do not need one. Use it on request, or when the hook denied an edit to a risky path.

## Steps

1. Read the code the request touches. Trace the real flow. Do not ask what the repo can answer.
2. **Goals first.** If the request names the change and how it should behave, ask nothing: go to step 4 and list your choices under Assumptions. Otherwise find what is still unknown about: the goal, who uses it, must-have versus nice-to-have, what is out of scope, constraints, and what done looks like. Skip what the request or the code already answers.
   - Ask it all in one plain-text round. Never use `AskUserQuestion`.
   - Number the questions. Under each, give your recommended answer after `Recommended:`.
   - End the round with: "Reply `yes` to accept all, or answer by number. Type `/spar` for a deeper round." Then stop.
3. Write the spec only after every question is answered. Put what the answers left open under Assumptions. Never ask for approval while a question is open.
4. Write `specs/current.md` in the project root with these sections.
5. Writing the spec is your last action, apart from its page (below). Then show the **brief**, which the user decides from: the file retold in plain words, every line taken from the file, a missing section skipped.
   - **Approving**: the Goal.
   - **Decisions**: each choice and what it rejects. Flag what is hard to undo.
   - **Added**: each Proposed addition.
   - **Assumed**: each Assumption.
   - **Changes**: the Blast radius files. **Stays**: the Non-goals.
   - **Done when**: each criterion in a few words.

   Ask once, and stop: reply with exactly `approve spec`.

## Sections

- **Goal**: one line.
- **Decisions**: at most 3 lines, each `- <choice>. Rejected: <alternative>. Hard to undo: yes|no.` Write "none" when the change has one obvious shape.
- **Proposed additions**: details the user did not ask for. A table: Detail | Proposal | Why it matters. Keep each row short. Skip the section if there are none.
- **Acceptance criteria**: each one is a check that can run, with its command. "Works well" is not a check.
- **Non-goals**: what you will not do.
- **Blast radius**: search for every caller and every file the change touches. One line per file: `` - `path`: what changes. Callers: `a`, `b`. ``
- **Work packages**: only when the work runs in waves. `- Wave 0: <package>. <detail>.`
- **Assumptions**: what you decided without the user, each with the default you took. Skip the section if there are none.

Start the file with `# Spec: <title>`. Put the goal line under `## Goal`.

## Spec page

A spec is **small** when it has no Trade-offs and no Security section, Blast radius lists at most 2 files, and it has at most 3 acceptance criteria. Other specs are medium or large.

- Medium or large: load `artifacts` and publish the page as its "Spec pages" section says, before you ask for approval. Link it in your message.
- Small: end the approval message with: "Want a page for this spec? Reply `page`, or `approve spec` to approve it as it is." Build the page only on `page`.
- **Edit loop.** When a notice says the page changed, and before each republish, read the live page and merge its edits ("Spec pages" section). If edits were merged, list them, republish, and ask again for `approve spec`: the spec changed, so the old approval is gone.
- A page comment is a question, never an edit or an approval. Only `approve spec` typed in the terminal approves.

## Rules

- Scale the size to the change: a typo gets 3 lines.
- The user can reply `ask me` at any point before approval. Then ask about every Decision and Assumption, and rewrite the spec with the answers.
- Bug fix: criterion 1 reproduces the bug. Run it before any fix and record that it fails. A check that passes before the fix proves nothing.
- Structural change means a new module or service, a new data store or data flow, a changed interface between components, or anything hard to undo. For these, load `architecture` or `distributed-architecture`. Add a **Trade-offs** section: the options, the cost of each, your pick and why.
- Risky change means auth, secrets, permissions, payments, personal data, deletes of data, or production. For these, load `security-check` before you write the spec. Add a **Security** section with the risks and the checks for them.
- A new request in the middle of a task updates `specs/current.md`. That breaks the approval. Stop again for `approve spec`.
- The user can reply `skip spec` to let edits through until the next prompt.
- Do not write project files with Bash or PowerShell to get around the gate.
