---
name: spec
description: Use when the user runs /spec or asks for a plan, or when the ras hook denied an edit to a risky path. Asks what is unknown, writes specs/current.md, stops for approval.
---

# Spec

Write the contract before you touch the files. Ordinary changes do not need one. Use it on request, or when the hook denied an edit to a risky path.

## Steps

1. Read the code the request touches. Trace the real flow. Do not ask what the repo can answer.
2. **Goals first.** Find what is still unknown about: the goal, who uses it, must-have versus nice-to-have, what is out of scope, constraints, and what done looks like. Skip what the request or the code already answers. A clear request gets no questions. Decide internal details yourself.
   - Ask everything that is unknown in one round of plain text in your message. Never use `AskUserQuestion`.
   - Number the questions. Under each, give your recommended answer after `Recommended:`.
   - End the round with: "Reply `yes` to accept all, or answer by number. Type `/spar` for a deeper round." Then stop.
3. Write the spec only after every question is answered. Put what the answers left open under Assumptions. Never ask for approval while a question is open.
4. Write `specs/current.md` in the project root with the sections below.
5. Writing the spec is your last action. Copy the Decisions lines into your message, then ask once, and stop: reply with exactly `approve spec`.

## Sections

- **Goal**: one line.
- **Decisions**: at most 3 lines. Each line: the choice, the rejected alternative, and hard to undo yes or no. Write "none" when the change has one obvious shape.
- **Proposed additions**: details the user did not ask for. A table: Detail | Proposal | Why it matters. Keep each row short. Skip the section if there are none.
- **Acceptance criteria**: each one is a check that can run, with its command. "Works well" is not a check.
- **Non-goals**: what you will not do.
- **Blast radius**: search for every caller and every file the change touches. List them.
- **Assumptions**: what you decided without the user, each with the default you took. Skip the section if there are none.

Start the file with `# Spec: <title>`. Put the goal line under `## Goal`.

## Rules

- Scale the size to the change: a typo gets 3 lines.
- The user can reply `ask me` at any point before approval. Then ask about every Decision and Assumption, and rewrite the spec with the answers.
- Bug fix: criterion 1 reproduces the bug. Run it before any fix and record that it fails. A check that passes before the fix proves nothing.
- Structural change means a new module or service, a new data store or data flow, a changed interface between components, or anything hard to undo. For these, load `architecture` or `distributed-architecture`. Add a **Trade-offs** section: the options, the cost of each, your pick and why.
- Risky change means auth, secrets, permissions, payments, personal data, deletes of data, or production. For these, load `security-check` before you write the spec. Add a **Security** section with the risks and the checks for them.
- A new request in the middle of a task updates `specs/current.md`. That breaks the approval. Stop again for `approve spec`.
- The user can reply `skip spec` to let edits through until the next prompt.
- Do not write project files with Bash or PowerShell to get around the gate.
