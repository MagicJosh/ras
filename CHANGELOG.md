# Changelog

## 6.0.0

Breaking. The default is now to work normally. A spec is for risky paths and for the times you ask. Local A/B runs showed no quality gain on clear bugs and a cost of 1.6x to 3.9x, because every change went through spec, approval and finalize.

- No default gate. The `spec-gate` hook allows `Edit`, `Write` and `NotebookEdit` unless the path is risky and no spec is approved. `specs/` is always allowed.
- Risky paths: `.github/workflows/`, `.gitlab-ci.yml`, `.env*` (not `.env.example` or `.env.sample`), `.husky/`, `.devcontainer/`, `.mcp.json`, `migrations/`, `*.sql`, `Dockerfile*`, `docker-compose*`, `*.tf`, `prisma/schema.prisma`, `supabase/`, and `auth`, `permissions` folders or `auth.*`, `permissions.*`, `policies.*` files. A `.ras/risky-paths` file (one regex per line) replaces the defaults.
- The hook also covers `Bash`: a write-ish command (`>`, `tee`, `sed -i`, `cp`, `mv`, `rm`, `truncate`, `git apply`, `patch`, `dd`) that names a risky path is denied. A guard rail, not a sandbox.
- `approve spec` is scoped to the session that got it. An approval from another session does not count. Archiving the spec ends it.
- The deny message names the matched pattern and tells the agent to ask its questions, write `specs/current.md` and get `approve spec`.
- Session-start context is 5 lines: work normally, `/spec` on request, risky paths need a spec, end code changes with a `Decisions` section.
- `Stop`: when a turn changed files (via `git`) and the reply has no `Decisions` heading, the hook asks once, with "touched N files, M lines". It never loops and skips non-git folders.
- `spec`: only on `/spec`, a plan request, or a denied risky edit. New "Goals first" step: ask only what is unknown, one round, then write the spec, then ask for approval once. New "Proposed additions" section (Detail, Proposal, Why it matters).
- `build` and `finalize` are for the gate lane. `finalize` verifies once per code state, keeps one failure-path check, puts throwaway repro scripts in `specs/`, keeps one regression test for a bug fix, and reports Decisions.
- `diagnose` is for an unknown cause only, and no longer routes every fix into `spec`.
- `security-check` triggers on risky behavior in any lane: auth, permissions, secrets, payments, personal data, data deletion.
- `which` shows the new lanes.
- Evals: 14 cases. New `default-lane`. `hook-blocks-edit` now targets a CI workflow. `spec-first`, `spec-asks` and `spec-asks-mid` use an explicit `/spec`. `security-check` checks the admin guard in the code, not a spec section.
- `tests/test_spec_gate.sh` covers the new gate, 127 checks.

## 5.0.0

- First public release, in a new repository with a fresh history.
- `architecture` and `distributed-architecture` are rewritten as original skills: a decision workflow and trade-off checklists in our own words, with the books as further reading.
- The marketplace is now `magicjosh`. Install with `claude plugin install ras@magicjosh`.

## 4.2.0

Generic engineering practices, written fresh from a review of a well-kept company engineering skill.

- `build`: design for real conditions (empty, duplicate, malformed, late input, partial failure, retries, idempotent external writes). Test rules: regression test from the real failing input, both sides of each condition, mock only system boundaries. Match the local style. Comments only for contracts, units, invariants and limits. Machine-checkable rules go into a type, schema, constraint, linter or test. Never weaken, skip or delete a test, assertion or guard, and never bypass hooks or CI.
- `finalize`: a weakened test or guard is a defect. Verification runs one failure or recovery path.
- `deep-review`: goal in one sentence, correctness before structure, findings with severity, `file:line` and a checked fix, verdict `MERGE | MERGE AFTER FIXES | NEEDS WORK`.
- `security-check`: each environment owns its configuration, no `test|live` switch, settings are not secrets, a credential and its endpoint stay in one secret.
- New eval `test-conflict`: a test contradicts the approved spec. The agent must report the conflict and keep the test. It passes with and without the plugin (3/3 each), so it is a regression guard, not a measured gain.

## 4.1.0

- `specs/` stays out of git. The hook writes `specs/.gitignore` with `*` when the agent writes the spec, and at session start when `specs/` exists. 3 new hook tests (40).
- `finalize` keeps the 5 newest archived specs and deletes older ones.

## 4.0.0

Breaking. The plugin and two skills have new names. Reinstall the plugin, see README.

- The plugin is now `ras`, so the `/` menu shows `/ras:spec` instead of `/refined-agent-skills:spec`. Short names such as `/spec` also work.
- `debug` is now `diagnose`, and `security-review` is now `security-check`. Claude Code has built-in `/debug` and `/security-review` commands, which win over the short name of a plugin skill.
- `/rules` installs original lazy senior dev rules as `~/.claude/rules/lazy.md` (1,387 characters, was 2,628).

## 3.1.0

- The `spec-gate` hook gives the agent a 4-line reminder of the spec flow at every session start, resume and compaction. Only startup and `/clear` end an approval, as before.
- New user-only skill `rules`: `/rules` installs the ponytail coding rules as `~/.claude/rules/ponytail.md`. It never overwrites without asking.
- README: put always-on personal rules in `~/.claude/rules/`, not `~/AGENTS.md`, which Claude Code skips when a `CLAUDE.md` exists.

## 3.0.0

Breaking. Skill names change. Reinstall the plugin.

- Cut the plugin from 16 skills to 9: `spec`, `build`, `finalize`, `debug`, `architecture`, `distributed-architecture`, `deep-review`, `security-review`, `which`.
- Added the `spec-gate` hook. It denies `Edit`, `Write` and `NotebookEdit` until the user replies `approve spec`.
- Added `tests/test_spec_gate.sh` and `tests/check_skills.sh`. CI runs both.
- Removed the Python validators, eval runners, schemas, adapters, profiles, docs and graph output.
- Removed the RAS 2.1 skills. Git history keeps them.
- Added `evals/`, a suite of 11 cases for `claude plugin eval`. It replaces the manual trigger check. First full run, 3 runs per case with and without the plugin: 10 of 11 cases pass. `security-review` loaded in 1 of 3 runs. `build` and `debug` showed no gain over plain Claude on their cases.
- `spec` asks clarifying questions before it writes the spec when the request is unclear or has two readings with different results. It uses `AskUserQuestion`, up to 4 questions per round and 3 rounds, and puts the rest under Assumptions. Reply `ask me` to get questions on a spec that guessed.
- `spec` adds a Decisions section (at most 3 lines). A `Stop` hook shows it to the user when the agent asks for approval, because agents copied it into the approval request in only 2 of 9 cloud runs.
- `debug` asks the user for state it cannot see (production data, another user's screen, a setting) when the code alone does not explain the symptom.
- `debug` builds the failing case from the broken invariant when a report gives no reproduction, and fixes every writer of the broken state.
- `security-review` requires identity checks to fail closed, and adds `references/database-functions.md`.
- `finalize` names every changed file outside the spec's blast radius.
- Evals: 13 cases. New cases `spec-asks` and `spec-asks-mid`. `spec-first` now also requires zero questions on a clear request.

## 2.1.0 and earlier

Entries below describe RAS 2.x, which 3.0.0 replaces.

### 2.1.0

- Moved the canonical skill tree to the repository root.
- Added Claude Code, Hermes, and Codex host adapters around one portable core.
- Made `planning-work`, `tracking-evidence`, and `finalizing-and-handoff` independently installable with local support files and pinned requirements.
- Moved OpenAI policy from the portable core into the Codex adapter.
- Added a conflict-safe direct installer with backups and dry-run support.
- Added a clean-profile Claude plugin smoke test and a Hermes registration test.
- Added package-boundary, copied-file parity, host-policy, and Semantic Versioning fitness functions.
- Added architecture documentation and ADR-0001 with the decision trade-offs.
- Replaced `avoiding-ai-slop` with the explicit-only `thermo-nuclear-code-quality-review` workflow.
- Repaired invalid YAML frontmatter in `reviewing-your-work`.
- Removed tracked Python bytecode so clean checkouts pass repository validation.
- Replaced handwritten artifact checks with pinned Draft 2020-12 schema validation and structured diagnostics.
- Added plan dependency and append-only task-state checks.
- Added a bounded behavioral-eval runner with Claude Code and Hermes OpenAI Codex adapters.
- Added fresh-attempt isolation, redacted evidence, and deterministic adapter tests.
- Required explicit adapter selection to prevent accidental live evaluations.
- Made `executing-work` stop after verification and require fresh push authorization.

### 2.0.0

- Reconciled the repository around 16 unique skills.
- Canonicalized plan units as `{id, action, files, verify, executor, risk}`.
- Replaced the one-axis confirmation tier with reversibility and exposure.
- Made app-overhaul explicit, audit-first, dirty-tree safe, and separately gated for implementation, commit, push, publish, and deploy.
- Reduced orchestrator fan-out to targeted specialist activation.
- Consolidated durable state into optional append-only JSONL.
- Expanded evidence beyond quote-only proof and verification beyond mandatory reproduction.
- Added emergency containment, non-reproducible incident handling, schemas, validators, trigger evals, fixtures, adapters, and profiles.
- Corrected SQL-identifier and path-containment security guidance.
