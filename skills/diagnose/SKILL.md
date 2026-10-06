---
name: diagnose
description: Use when something fails or behaves wrongly and the cause is unknown, such as an error, a failing test, wrong output, flaky behavior, or a fix that did not work. Finds the root cause instead of patching the symptom.
---

# Diagnose

Find the root cause. Do not patch before you understand.

## Steps

1. **Keep the evidence.** Before any restart, cache clear, delete or config change, record the time, revision, environment, inputs, logs and state. If something is still doing harm, make the smallest reversible containment first. Containment is not a fix.
2. **Reproduce.** Read the whole error, trace or output. Make a command that fails, and run it. If it does not fail every time, measure the rate and the conditions. If you cannot reproduce it, add instrumentation and say so.
   - If the report gives no failing case, write the invariant the symptom breaks in one sentence, for example "a paid order always has an invoice". Build the failing case from what the report leaves out: who acts (no user, another role), when (two actions at once, a retry, a timeout, a different order), and what state or input (empty, stale, duplicate). If you cannot run a case, name it in the report, for example "concurrency: not tested".
   - If the symptom depends on state you cannot see, such as production data, another user's screen or a setting, and the code alone does not explain it, ask the user for that state before you change code. Ask for observations, not guesses: what they see, what changed and when, the exact records.
3. **Isolate.** Cut the case down to the smallest one that still fails. Follow the data flow to the place where an invariant breaks.
4. **Test one hypothesis.** State it with a prediction and what would disprove it. Run a check that tells it apart from the other causes.
5. **Fix once.** Find every caller of the broken code, and every writer of the broken state, not only the path in the report. Fix it where all of them pass through, with the smallest change that removes the cause.
6. **Prove it.** Run the same reproduction. It must now pass. Explain why the cause is gone, not just the symptom.

## Rules

- A spec is needed before the fix, as for any change. Criterion 1 is the reproduction, and it fails before the fix.
- If a restart makes the symptom go away, you have contained it. You have not fixed it.
- If the live system is risky to test on, use a copy, staging, read-only access, or old logs.
- After three different failed approaches, stop. Report what you tried, what the evidence shows, and the structural options. Do not try a fourth guess.
- Report: the cause, the evidence, the fix, the proof, and what is still uncertain.
