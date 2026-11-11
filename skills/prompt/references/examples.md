# Worked examples

Five rough asks and the output of step 6 for each. They differ in receiver, task kind and size on purpose. Take the size and the shape from the nearest one. The words come from the user's own ask and evidence, so write those fresh every time. The assumptions in an example belong to its ask: carry none of them over.

<example>
Rough ask: "rename getUser to fetchUser"
Receiver: this session. Kind: refactor. Size: small. User away: no.
Looked: `getUser` is defined in `src/api/users.ts`; 14 call sites; `package.json` has a `test` script.
Gaps: none. Asked nothing. Fast path: small, this session, nothing guessed, nothing waiting for a go-ahead.

Output:

**Prompt**
```
Rename the function `getUser` in `src/api/users.ts` to `fetchUser`, and update all 14 call sites and any imports, tests and docs that mention it. Behaviour stays identical: this is a rename only. Before you finish, run `npm test` and confirm it passes, and search the repo once more for `getUser` to confirm nothing is left.
```

**Effort**: low, a mechanical and fully specified change.

Nothing was guessed, so I'm starting on this now.
</example>

<example>
Rough ask: "the csv export is broken sometimes, fix it"
Receiver: this session. Kind: bug fix. Size: normal. User away: no.
Looked: one export, `export/csv_writer.py`, called from `orders/views.py`; tests in `tests/test_export.py`; the README runs them with `pytest`.
Asked: "What does broken look like?" (recommendation: with no details, the receiver reproduces it first). Answer: "customers say the columns shift in Excel for some orders".
Delegated: which orders break, and why.

Output:

**Assumptions** (tell me which are wrong)
- You want the smallest fix, with no restructuring of the export code.

**Prompt**
```
The CSV order export sometimes produces files where the columns shift when customers open them in Excel. It happens for some orders and not others, and nobody has found which ones yet. Find the cause and fix it, so that every export opens with each value in its own column.

The export is written by `export/csv_writer.py` and called from `orders/views.py`. Start by reproducing the problem in a failing test in `tests/test_export.py`. Because only some orders break, the cause is probably in the data: try values with commas, quotes, line breaks and non-ASCII characters.

Tell me the root cause before you change code, and fix it where it lives, so every caller of the writer is fixed at once. Change only what this fix needs and keep the existing structure. If you cannot reproduce it, change no code and report what you tried and ruled out.

Before you finish, run `pytest` and confirm the new test and the existing ones pass. Report the cause with its file and line, why the fix works, and anything you did not check.
```

**Effort**: high, the cause is unknown.

Run it here, or change something?
</example>

<example>
Rough ask: "add retries to the sensor polling, one glitch on the serial line kills a whole overnight run. im going to bed so just get it done"
Receiver: this session. Kind: feature. Size: long. User away: yes.
Looked: polling lives in `bench/poller.py` (`Poller.read_once`); a read that times out raises `SensorTimeout` and `bench/runner.py` ends the test run; settings are in `bench/config.toml`; tests in `tests/test_poller.py`, run with `pytest` per the README.
Asked nothing: the user is away. Every gap is assumed.

Output:

**Assumptions** (tell me which are wrong)
- 3 tries in total, 0.5 s apart, both adjustable in `bench/config.toml`.
- When the last try also fails, the run stops and records the failure, as it does today.
- Only timeouts are retried. Any other sensor error still stops the run at once.
- Each retry leaves a line in the run log, so you can spot a flaky sensor later.

**Prompt**
```
## Goal
Make sensor polling survive a short dropout. Today one timed-out read raises `SensorTimeout` in `Poller.read_once` (`bench/poller.py`) and `bench/runner.py` ends the whole test run. One glitch on the serial line kills an overnight run, and that is what this change removes.

## Behaviour
- A read that times out is tried again, up to 3 tries in total, 0.5 s apart.
- Both numbers come from `bench/config.toml`, with those values as the defaults.
- Each retry writes one line to the run log with the sensor name and the try number.
- When the last try also times out, the run stops and records the failure exactly as it does today.
- Only `SensorTimeout` is retried. Every other error stops the run at once, as today.

## Scope
Change only what this needs and keep the existing structure. The public interface of `Poller` stays as it is. No new dependencies.

## Done
Add tests in `tests/test_poller.py` for: success on the first try, success on a retry, failure after the last try, and a non-timeout error that is not retried. Use a fake sensor so the tests need no hardware and no real waiting. `pytest` passes in full.

## Working unattended
I'm away, so finish the whole task. Work through ordinary obstacles such as errors and failing tools. When something is ambiguous, pick the option closest to how the existing code behaves and list the choice in your report.

## Report
Write it for someone who has seen none of the work: what changed, what you verified and how, what you could not verify without the hardware, and every decision this prompt did not specify.
```

**Effort**: high, a long task with nobody watching.

You're away, so I'm starting on this now.
</example>

<example>
Rough ask: "should i use sqlite or postgres for this? want a second opinion from chatgpt"
Receiver: elsewhere, another LLM in a chat that cannot see the repo. Kind: architecture decision. Size: normal. User away: no.
Looked: the repo is a FastAPI app with SQLAlchemy; `docker-compose.yml` has a single app container; the README says an internal tool for about 20 colleagues.
Asked: "How much data, and how many people writing at once?" (recommendation: a placeholder, since nothing in the repo says). Answer: "maybe 50k rows a year, 2-3 people at the same time max". "What matters most?" (recommendation: not losing data, then low upkeep, then room to grow, because you maintain it alone). Answer: "yes".

Output:

**Assumptions** (tell me which are wrong)
- Backups belong in the answer, because the data matters to you.
- An answer under 400 words is enough.

**Prompt**
```
I need to choose between SQLite and PostgreSQL for a small internal web tool, and I want a recommendation I can act on. Advise only: I don't need code.

<facts>
- A FastAPI app with SQLAlchemy, deployed as one container with docker-compose on one server.
- About 20 colleagues use it. At most 2 or 3 write at the same time.
- Roughly 50,000 new rows a year. Simple relational data.
- I maintain it alone.
</facts>

What matters to me, in this order: not losing data, low maintenance effort, then room to grow.

Give me one recommendation and the reasons for it, the trade-offs I accept by taking it, and the strongest argument for the other option. Then tell me which change in the facts above would flip your recommendation, and what the backup routine looks like for the option you chose. Keep it under 400 words.
```

Ready to copy. Want anything changed?
</example>

<example>
Rough ask: "write an email to the supplier, the valves are late again and i need a real date"
Receiver: elsewhere, another Claude chat. Kind: writing. Size: small. User away: no.
Looked: nothing to read outside this conversation.
Asked: "Which order, and how late?" (recommendation: placeholders, which you fill in). Answer: "just leave placeholders".

Output:

**Assumptions** (tell me which are wrong)
- The tone is firm and polite, because you keep working with this supplier.
- You want a reply within two working days, and the cause of the delay.
- English, under 120 words.

**Fill in before sending**: supplier contact, order number, quantity, promised date, your name.

**Prompt**
```
Write an email from me to a supplier about a late delivery. I want one thing from it: a confirmed delivery date in writing. The delivery is late again, and I need a real date.

<facts>
Supplier contact: [name]
Order: [order number], [quantity] valves
Promised delivery date: [date]
Status: not delivered, and no new date given
From: [your name]
</facts>

Use only these facts and add none of your own. Keep the tone firm and polite: we keep working with this supplier. Ask for a confirmed date by reply within two working days, and ask what caused the delay. Write it in English, under 120 words, as plain text with a subject line, ready to send.
```

**Effort**: low, a short and fully specified text.

Ready to copy. Want anything changed?
</example>
