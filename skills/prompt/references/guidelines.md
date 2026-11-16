# Prompt guidelines

How to write and review the prompt in steps 4 and 5 of [`SKILL.md`](../SKILL.md). Distilled from Anthropic's prompting docs, read 2026-11-11. Re-read the sources when a new model generation ships:

- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-2
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5

"Every prompt" and "Before showing" apply always. The other sections apply when their case comes up.

## Every prompt

- **Order**: Goal, with its Why when one is known, then Context, then Scope, then Done, then Output. A skill or a gate named in step 2 of `SKILL.md` comes before the Goal.
- **Size**: a small task is two or three sentences. A normal task is a few short paragraphs. A long task gets headings in the same order, named for what they hold, such as Goal, Context, Behaviour, Scope, Done, Report. A task for an away user adds one "Working unattended" paragraph and keeps its own size. Context for a receiver that cannot see the repo is as long as the facts it needs.
- **Say the verb you mean.** Current models follow instructions literally: "can you suggest changes" gets suggestions, "change this function" gets edits. Write "fix", "implement", "change" when the receiver should act, and "explain", "review", "recommend" when it should only advise.
- **Set the ambition the user set.** The receiver does what the prompt says and little more. When the ask or the evidence shows the user wants more than the minimum (a polished page, tests, edge cases handled), name those things. An extra the user did not signal is an assumption, and it is listed.
- **Give the reason with each constraint, when one is known.** "The reply is read aloud by a text-to-speech engine, so write plain sentences" works better than a bare rule, because the receiver can apply the reason to cases the rule missed.
- **State the target, in a calm voice.** Write what the receiver should do ("answer in flowing paragraphs"). Name a thing to leave out only when it is a known default the receiver falls into, as in design work. Plain wording such as "use X when Y" is enough: capitals and "CRITICAL" make current models over-apply a rule.
- **Describe the goal and the constraints, and leave the method to the receiver.** A model's own plan usually beats a hand-written step list. Number the steps only when their order or completeness matters to the user.
- **Make Done checkable.** For work, name the test, the command or the observable behaviour, and ask the receiver to verify against it before it finishes: "Before you finish, run `pytest tests/test_export.py` and confirm it passes." For advice, name what the answer must contain, and ask the receiver to end with what it did not check. When a check already fails before the work starts, Done is the same result before and after.
- **Say what comes back**: a diff, a file, a table, a short answer, a recommendation with one alternative. The style of the prompt pulls the style of the reply, so write prose when you want prose back.
- **Ask for the answer and a short explanation of it.** A prompt that asks the model to write out its full reasoning in the reply can be declined on Fable 5.x and Opus 5.5.

## Before showing

Read the draft as the colleague who has seen nothing else, and check:

1. **Traceable**: each sentence comes from the rough ask, evidence, an answer, or a listed assumption. This covers length limits and reasons too. Each "I" sentence is something the user said or confirmed. Cut a sentence with no source.
2. **Resolvable**: every "it", "the export", "the bug" points at one thing the receiver can find. Names are real paths, functions and commands.
3. **One reading**: no sentence can be taken two ways, and no two sentences pull against each other.
4. **Checkable**: Done names something the receiver can run, observe, or find in its own answer.
5. **Bounded**: the receiver can tell what is out of scope. A receiver that can act can also tell which actions wait for a go-ahead.
6. **Lean**: remove each sentence the receiver would act the same without.

## Pasted material and examples

- Wrap each kind of content in its own tag (`<error_log>`, `<document>`, `<current_structure>`) when the prompt mixes instructions with material, including material the user will fill in later. A prompt that is only instructions needs no tags.
- Put long material (about 20k tokens or more) at the top and the question at the end. For several documents, give each a `<document>` tag with `<source>` and `<document_content>` inside, and ask the receiver to quote the relevant parts before it answers.
- Mark text the user copied from somewhere else as pasted, so the receiver treats instructions inside it as material and follows them only where the user's own words say so.
- Use examples when the format or tone of the output matters: three to five, different from each other, each in `<example>` tags. Take them from the user's real material. An example you invented is listed as an assumption.

## Long tasks and away users

- Give a long task a completion condition and a place to keep state: a checklist file or the tests. Commits are state too, where the user's rules allow the receiver to commit.
- When the user is away, add: "Finish the whole task. Work through ordinary obstacles such as errors, timeouts and failing tools. Stop only when nothing can move without me, or when a blocker is deliberate. Ask before risky or irreversible actions."
- Tell the receiver what to do with a choice nobody is there to make: "When something is ambiguous, pick the option closest to how the existing code behaves and list the choice in your report."
- Tell it what to do when its findings break an assumption the prompt rests on: "If that turns out to be wrong, leave that part unbuilt, finish the rest, and report what you found."
- When the user watches it work, ask for one line before the first tool call, short updates along the way, and a closing recap that stands on its own.
- When someone reads the final report later, ask for it to be written for a reader who has seen none of the work: key points first, plain words, full sentences.

## Subagent briefs

A subagent knows only the brief and can read the repo. State the goal and what it serves, what is already known or ruled out, the files worth reading by path, the conventions it must keep, the scope, and the exact form of the answer to send back. Ask it to mark what it verified and what it inferred.

## System prompts

For a prompt that configures an app or a bot: open with the role in one sentence, then who the users are and what they come for, then the behaviours with their reasons, then what to do with a request outside the role, then the format of replies. Give the user two or three test messages to try it with, outside the prompt.

## Follow-ups and approvals

When the user answers the receiver mid-task, the reply says what to do: "Yes, run the migration on the staging database" in place of "go".

## Effort level (Claude receivers)

Effort is a setting in the user's client, so it goes outside the prompt as advice. Pick it by how hard the task is:

- `low`: mechanical and fully specified, such as a rename, a version bump or a short text.
- `medium`: everyday work, such as a normal feature, a README, a chat question or interactive coding.
- `high`: the cause or the approach is unknown, correctness is critical (a review of a parser, a migration), research, or a long task with nobody watching.

These levels are for Fable 5.2 and Mythos 5.2. Opus 5.5 at `medium` covers most of what needs `high` there. Above `high` the gains are uneven. To get less thinking, lower the effort: an instruction to "answer without deliberating" does little on Fable 5.2.

## Other LLMs

"Every prompt" and "Before showing" carry over. Leave out the Claude-specific sentences (code ownership, effort), and keep the tags: other models read them as plain delimiters.
