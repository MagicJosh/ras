---
name: which
description: Use when the user types /which to ask which ras skill fits a task. Answers with one or two skills, their order, and one line of reason each.
disable-model-invocation: true
---

# Which

| Skill | Use when | Example request |
|---|---|---|
| `spec` | A plan first, or a risky path was denied | "/spec add a retry" |
| `spar` | Stress-test a plan or a decision by interview. User call only | "/spar my cache plan" |
| `build` | Gate lane: implement an approved spec | "Spec approved, go ahead" |
| `finalize` | Gate lane: defects, cuts, fresh checks, report | "Wrap it up" |
| `diagnose` | The cause of a failure is unknown | "The export crashes, I do not know why" |
| `architecture` | Choose a style, weigh trade-offs, write an ADR | "Monolith or modules for this app?" |
| `distributed-architecture` | Split a system: service size, data ownership, transactions | "Should billing become its own service?" |
| `deep-review` | Strict maintainability review of existing messy code | "Run a deep review of this module" |
| `security-check` | A change touches auth, secrets, permissions, deletes or production | "Add an admin delete endpoint" |
| `rules` | Install the coding rules. User call only | "/rules" |

A normal change needs no skill. The gate lane (risky path or `/spec`) runs `spec`, `build`, `finalize`.

Rule: answer with one or two skills and their order. Give one line of reason for each. Then stop. Make no edits.
