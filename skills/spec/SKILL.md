---
name: spec
description: Use when a request will change files and no approved specs/current.md exists yet, such as a bug fix, a feature, a refactor or a config change. Writes the spec, asks what is unclear, stops for approval.
---

# Spec

Write the contract before you touch any project file. The spec gate blocks edits until the user approves.

## Steps

1. Read the code the request touches. Trace the real flow. Do not ask what the repo can answer.
2. Clarify. Ask before you write the spec when the request leaves open what to build, for whom, or what done means, or when two reasonable readings give the user different results. A subjective goal (better, nicer, faster) is unclear unless the request or the code defines it. Decide internal details yourself. Use the `AskUserQuestion` tool: at most 4 questions per round, each with 2 to 4 concrete options, your recommended option first. If the tool is not available, ask the same way in your message, then stop and wait. Ask again only about what the answers left open. Stop when you know every answer that would change what you build or how you check it. After 3 rounds, write the spec and put the rest under Assumptions.
3. Write `specs/current.md` in the project root with the sections below.
4. Writing the spec is your last action. Copy the Decisions lines into your message, then stop and tell the user to reply with exactly: `approve spec`.

## Sections

- **Goal**: one line.
- **Decisions**: at most 3 lines. Each line: the choice, the rejected alternative, and hard to undo yes or no. Write "none" when the change has one obvious shape.
- **Acceptance criteria**: each one is a check that can run, with its command. "Works well" is not a check.
- **Non-goals**: what you will not do.
- **Blast radius**: search for every caller and every file the change touches. List them.
- **Assumptions**: what you decided without the user, each with the default you took. Skip the section if there are none.

Start the file with `# Spec: <title>`. Put the goal line under `## Goal`.

## Rules

- Scale the size to the change: a typo gets 3 lines, a feature one page.
- A clear request gets no questions.
- The user can reply `ask me` at any point before approval. Then run step 2 on every Decision and Assumption, and rewrite the spec with the answers.
- Bug fix: criterion 1 reproduces the bug. Run it before any fix and record that it fails. A check that passes before the fix proves nothing.
- Structural change means a new module or service, a new data store or data flow, a changed interface between components, or anything hard to undo. For these, load `architecture` or `distributed-architecture`. Add a **Trade-offs** section: the options, the cost of each, your pick and why. Where it helps, add a fitness function as a criterion, for example "module A does not import B", checked with grep.
- Risky change means auth, secrets, permissions, deletes of data, or production. For these, load `security-check` before you write the spec. Add a **Security** section with the risks and the checks for them.
- A new request in the middle of a task updates `specs/current.md`. That breaks the approval. Stop again for `approve spec`.
- The user can reply `skip spec` for a trivial change. Then the gate lets edits through until the next prompt.
- Do not write project files with Bash or PowerShell to get around the gate.
