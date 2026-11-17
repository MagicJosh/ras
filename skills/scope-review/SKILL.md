---
name: scope-review
description: Use when the user types /scope-review to check a finished change against its spec. A fresh read-only agent sorts every hunk as in scope, supporting, out of scope or unclear, and the user decides what happens to each finding.
disable-model-invocation: true
---

# Scope review

The agent that built a change is a poor judge of whether it stayed in scope. This skill starts a fresh agent that saw none of the work. The agent builds its own view of the scope and the change with a script, and this skill shows you what it found. It changes no project file.

It needs a spec: `specs/current.md`, or the newest archived spec when `finalize` has already run. A change without a spec has no scope that was fixed before the build, so there is nothing to review it against.

## Steps

1. **Save a record.** Run `sh <this skill's folder>/review-file.sh` in the project root. Pass a commit as its argument when the user named one, such as `/scope-review abc1234`. It writes two files under `specs/` for the user to read later: the scope, copied word for word from the spec, and the change against the base (`HEAD` by default).
   - `no change against` means the change is empty, which happens when the work is already committed. Ask the user for the commit the work started from, then run it again with that commit. Never report an empty change as "nothing out of scope".
   - `cannot write` is not a stop. A sandbox can make every folder read-only for shell commands. Do not look into it: go to step 2.
   - Do not write or edit either file yourself.
2. **Start the reviewer.** Start the `scope-reviewer` agent in the foreground, with this message and nothing more: `Script: <absolute path of review-file.sh>. Base: <the commit, or HEAD>.` Give it no file from step 1, no summary of the work, no reasons and no opinion on what is in scope. The reviewer runs the script itself, so it reads the scope and the change as the script made them and not as you passed them on. Wait for its report.
3. **Show the report as it came back.** Save it under the path its `Report file:` line names, and show it unchanged. Do not drop, reword or argue with a finding.
4. **Mark what was declared.** Under the report, add one line per out-of-scope or unclear finding: `declared`, when your own Decisions section or the spec's Assumptions already told the user about it, with the words you used, or `not declared`.
5. **Stop.** The user decides per finding: keep it, revert it, or move it to a new spec. Do none of these before the user says which.

## Rules

- A finding is information, not an order. Revert nothing on your own.
- When the user keeps a finding, the spec is now behind the code. Offer to add its Blast radius line to the spec.
- The reviewer judges scope, not quality. For quality, use `/code-review` or `deep-review`.
- The reviewer has a shell, and its instructions limit it to the script and to commands that only read. It is told not to run the project's code.
- The report names the limits of this check. One of them: files that were already changed before the work started may show up in the diff.
