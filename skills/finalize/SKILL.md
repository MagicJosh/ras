---
name: finalize
description: Use when the implementation of an approved spec is done and you are about to report the result, in the gate lane only. Runs the done step. Find defects, cut excess code, run fresh checks, write an honest report, archive the spec.
---

# Finalize

Do these five steps in order. Do not skip one. Ordinary changes without a spec do not use this skill: run the project's own check once and report.

## 1. Defects

Read your own diff.

- Spec compliance first: does each criterion and non-goal hold?
- Then quality, and the risk to every caller in the blast radius.
- Run `git status --short`. Name every changed file that the blast radius did not list. Say why it changed, or revert it.
- A weakened, skipped or deleted test, assertion or guard is a defect. Restore it, unless the spec asked for the change.

Fix what you find.

## 2. Cuts

Delete from this change's own diff:

- dead code
- flexibility nobody asked for
- hand-written code that the standard library already provides

A cut outside the diff is not an edit. Offer it as a suggestion for a new spec.

## 3. Verify, once per code state

Run every acceptance check after the last change. A result from before the last change does not count. Do not re-run a check when the code has not changed since it passed. Keep one failure or recovery path in the run, not only the happy path.

Throwaway repro scripts go in `specs/`, not in the repo. A bug fix keeps one regression test in the repo.

For each check, report pass or fail, the command, and what it printed. Say "checks pass". Never say "correct" or "works".

## 4. Report

Keep it short:

- Result: what changed, in a few lines.
- Evidence: the commands and results from step 3.
- Unrun checks: what you did not run, and why.
- Decisions: the choices you made that the spec did not settle, or none.
- Limits: what the change does not cover.

Put no secrets in the report. Do not commit, push, deploy or delete unless the user said so.

## 5. Archive and release

Run this Bash command, with today's date and a short slug. Moving the spec ends the approval.

```
mv specs/current.md specs/<date>-<slug>.md
ls -t specs/2*.md | tail -n +6 | xargs rm -f
```

The second line keeps the 5 newest archived specs. Git is the rollback, not the specs. The next change needs a new spec and a new approval.
