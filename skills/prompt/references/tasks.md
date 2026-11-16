# Task playbooks

What a senior engineer specifies for each kind of task. Read the one section that matches the task kind from step 1 of [`SKILL.md`](../SKILL.md); a task that spans two kinds takes both. Each bullet is a thing the prompt states. Settle it with a treatment from step 3. Keep a bullet only when the receiver would act differently without it: a small task keeps few.

## Bug fix

- **Symptom**: expected behaviour against actual behaviour, the exact error text, how often it happens, and with which input or environment.
- **Reproduction**: the steps or the failing case. When nobody has one, the receiver's first job is to reproduce the bug in a failing test.
- **Root cause first**: ask the receiver to find and state the cause before it changes code, and to fix the cause where it lives, so every caller is fixed at once.
- **Regression check**: a test that fails before the fix and passes after it.
- **Scope**: the smallest diff that removes the cause.
- **No reproduction, no patch**: when the receiver cannot reproduce the bug, it reports what it tried and what it ruled out, and changes no code.

## Performance

- **Symptom in numbers**: which operation, on what input size, how long it takes now. When nobody has measured, measuring is the receiver's first job.
- **Where the time goes**: ask the receiver to profile and report the main cost before it changes code.
- **Target**: a number when the user has one. Otherwise timings before and after, on the same input.
- **Results stay identical**: the output is the same for the same input, and the receiver says how it checked.
- **Limits**: dependencies allowed, memory, and parts that are slow on purpose and stay as they are.

## Feature

- **Behaviour**: who uses it and what they can do afterwards, described from the outside.
- **Acceptance criteria**: observable results, with the edge cases and the error cases written out.
- **Fit**: the existing interface, data shape or sibling feature to follow as the pattern, by path.
- **Non-goals**: the nearby things this task leaves out.
- **Constraints**: dependencies allowed, performance or compatibility limits, the code style to match.
- **Verification**: the tests to add and the command that runs them; for UI, running the app and looking.

## Refactor or migration

- **Target and reason**: the structure wanted afterwards, and the problem it removes.
- **Behaviour stays identical**: name the safety net (the test suite, a snapshot, a diff of outputs) and ask for it to stay green at every step.
- **Public surface**: the interfaces that stay as they are, and the ones allowed to change.
- **Order**: steps small enough that each one builds and passes on its own.

## Review or audit

- **Advise only**: the receiver reports and changes nothing.
- **Judge against**: correctness, security, the spec, or a named standard, in rank order. Say what is out of bounds, such as style.
- **Finding format**: file and line, the defect in one sentence, the input or state that triggers it, and the severity. Most severe first.
- **Confidence bar**: only findings the receiver has checked against the code, with uncertain ones marked as uncertain.
- **Done**: a verdict first, then the findings, then what was not checked.

## Architecture or design decision

- **The decision**: one sentence, with the deadline or trigger that forces it when there is one.
- **Forces**: hard constraints, the quality attributes in rank order (for example: correctness, then simplicity, then speed), real numbers for scale, and who maintains the result.
- **Current structure**: the modules, interfaces and coupling points the decision touches, for a receiver that cannot see the code.
- **Options on the table**: the ones already considered, and why each is still open or already rejected.
- **Output**: one recommendation, the trade-offs it accepts, the strongest alternative, and what fact would change the choice. Advise only.

## Investigation or explanation

- **The question**, and the decision or task the answer feeds.
- **Depth**: a two-line answer, a walkthrough, or a full trace.
- **Evidence**: file and line references for claims about code, measurements for claims about speed.
- **Read-only**: the receiver changes nothing.

## Research

- **A good answer contains**: the question, the decision it feeds, and how sure the user needs to be.
- **Sources that count**: primary docs, a date range, the user's own files. Ask the receiver to check each claim across several sources.
- **Hard questions**: keep competing hypotheses, each with a confidence, and say what would settle them.
- **Output**: the answer first, then the evidence with links, then what stays unknown.

## Writing

- **Reader and purpose**: who reads it, what they know already, and what they should do or decide after reading.
- **Material**: the facts, numbers and names to use: pasted in for a receiver that cannot see them, by file path for one that can. The receiver adds no facts of its own.
- **Voice and length**: the tone, a word count or a page count, and two or three samples of the wanted voice when the user has them.
- **Form**: email, report section, post, README.

## Data or analysis

- **The question** in one sentence, and the decision it feeds.
- **The data**: where it is, its columns or schema, the time range, known quirks.
- **Definitions**: how each metric is calculated, so two people would get the same number.
- **Output**: a table, a chart or a single figure, with the sanity checks the receiver ran (row counts, totals, nulls).

## Frontend or design

- **Direction**: the audience, the mood, the palette, the fonts, and a reference the user likes. Taste is the user's: ask for it when a question is free, and otherwise assume one direction in a single sentence and list it.
- **Leave out**: specific patterns by name ("no cream background, no pill-shaped buttons"). "Avoid a generic AI look" only swaps one default for another.
- **Content**: the real sections, copy and images, or a note that placeholders are fine.
- **Behaviour**: the interactions, animations, states and screen sizes the user wants, by name.
- **Stack**: plain HTML and CSS, or the framework and component library already in the repo.

## Changes to a repo: add what applies

These join any section above when the receiver changes files in a repo, code or not. A small task usually needs none of them.

- **Ownership**: how much may change. For the smallest diff: "Change only what this task needs and keep the existing structure." To improve the structure along the way: "This codebase is yours: what it's for and how it's built are your call." Anthropic measured the second sentence on Fable 5.2: the receiver merges repeated code and also makes changes nobody asked for, so tell the user to read the diff.
- **General solution**: correct for every valid input, with the tests as the check and never as the target. The receiver says so when a test looks wrong or the task looks infeasible.
- **Grounding**: the receiver opens the files the prompt names before it makes claims about them.
- **Go-ahead list**: the exact actions that wait for the user: "ask before deleting files, force-pushing, or pushing to main". A vague rule such as "ask before anything risky" is applied as written and holds back routine work.
- **Open questions**, when the user is there to answer: "When something is ambiguous and the answer changes the design, ask before building. Otherwise choose, and list the choice in your report." For an away user, use the unattended sentences in `guidelines.md`.
- **Report**: what changed, what was verified and how, what was left unverified, and the decisions the prompt did not specify.
