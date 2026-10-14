---
name: diagnose
description: Use when the cause of a failure is unknown, such as a failing test, wrong output, flaky behavior or a fix that did not work. Not when the cause is known. Finds the root cause instead of patching the symptom.
---

# Diagnose

Find the root cause. Do not patch before you understand.

## Steps

1. **Keep the evidence.** Before any restart, cache clear, delete or config change, record the time, revision, environment, inputs, logs and state. If something is still doing harm, make the smallest reversible containment first. Containment is not a fix.
2. **Build the loop first.** Read the whole error. Make one command that fails on this bug, and run it. The loop is ready when it shows the user's exact symptom, gives the same verdict every run, and takes seconds. Form no theory before it exists. Raise the rate of a flaky failure (repeat, add load, narrow the timing) until it is workable. If you cannot build one, stop. Say what you tried, and ask for access or a redacted log.
   - If the report gives no failing case, write the invariant the symptom breaks in one sentence, for example "a paid order always has an invoice". Build the failing case from what the report leaves out: who acts (no user, another role), when (two actions at once, a retry, a timeout, a different order), and what state or input (empty, stale, duplicate). If you cannot run a case, name it in the report, for example "concurrency: not tested".
   - If the symptom depends on state you cannot see, such as production data, another user's screen or a setting, and the code alone does not explain it, ask the user for that state before you change code. Ask for observations, not guesses: what they see, what changed and when, the exact records.
3. **Isolate.** Cut the case down to the smallest one that still fails. Follow the data flow to the place where an invariant breaks.
4. **Rank the causes.** List 2 to 4 causes, most likely first, each with a prediction: if it is the cause, changing X removes the failure. Show the list, but do not wait for an answer. Test the top cause first, one change at a time.
5. **Fix once.** Find every caller of the broken code, and every writer of the broken state, not only the path in the report. Fix it where all of them pass through, with the smallest change that removes the cause.
6. **Prove it.** Run the loop again. It must now pass. Make the reduced case a regression test where the bug really happens. Undo the fix, see the test fail, then restore the fix. If no test can reach that place, report it as a design finding. Explain why the cause is gone.

## Rules

- Once the cause is known, fix it like any other change. If the fix touches a risky path, the hook asks for a spec first. Then criterion 1 is the reproduction, and it fails before the fix.
- Tag every temporary debug line with one prefix, such as `[DEBUG-a4f2]`, and remove them all before you report.
- Redact secrets in all output that you show.
- If testing live is risky, use a copy, staging, read-only access, or old logs.
- After three different failed approaches, stop. Report what you tried, what the evidence shows, and the structural options. Do not try a fourth guess.
- Report: the cause, the evidence, the fix, the proof, and what is still uncertain.
