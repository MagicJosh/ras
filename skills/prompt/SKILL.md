---
name: prompt
description: Use when the user runs /prompt, or asks to write, improve or sharpen a prompt for Claude or another LLM. Turns a rough ask into a clear prompt.
---

Turn the user's **rough ask** into the prompt a senior engineer would write. It passes the **colleague test**: a smart colleague who has seen none of this conversation could start the work from the prompt alone, and would never have to ask what the user meant.

A prompt has six **slots**. The rough ask usually fills one or two of them:

- **Goal**: the outcome the user wants, and whether the receiver should act (change, build, fix) or advise (explain, review, recommend).
- **Why**: the reason behind the goal. A receiver generalizes from a reason and only obeys a rule.
- **Context**: what the receiver cannot see: files, the current behaviour, what was already tried, who reads the result.
- **Scope**: what to touch, what to leave as it is, and what waits for the user's go-ahead.
- **Done**: the condition that says the work is finished, and how to check it. For advice, what the answer must contain.
- **Output**: what comes back, and in what form.

The prompt is **traceable**: every sentence in it comes from the rough ask, from evidence you found, from an answer the user gave, or from an assumption you list. Traceability is what keeps the prompt the user's own and keeps it short.

## Steps

1. **Read the rough ask.** It is the text after `/prompt`, or the user's last message. Name four things:
   - the **receiver**: this Claude Code session (the default), a subagent this session will spawn, or a receiver elsewhere (another chat, another LLM, a system prompt for an app). The model is Claude unless the user names another;
   - the **task kind**, from the headings of [`tasks.md`](references/tasks.md). When no heading fits, the six slots carry the prompt on their own;
   - the **size**: small (one clear change or one short answer), normal, or long (many parts, or hours of work);
   - whether the user is **away**: the ask says they are leaving, or says to ask nothing. Away changes who answers questions. It leaves the size as it is.

   Done when you can say all four in one sentence.

2. **Look first.** Fill the slots from what you can read: this conversation, the files the ask names and the ones that call or test them, the repo's `AGENTS.md` or `CLAUDE.md`, the README, specs, and read-only commands such as `git status` or a directory listing. Running the project's code or tests, measuring and reproducing belong to the receiver. An ask that is not about the repo needs no look at the repo.
   - Collect real names for the prompt: the file path, the function, the exact error text, the command that runs the tests. Take a command from the repo itself (the README, `package.json`, a spec) and name that source in the prompt ("the test command from the spec"). When the repo documents none, infer one from the files and call it inferred in the prompt.
   - Something you find that the ask does not mention, such as a nearby bug or a test that already fails, is a **side finding**. It is a fact, so it goes on the Noticed line in step 6 and stays off the assumptions list. Word it as read, not as run ("reads as inverted, so the test should fail"). The task leaves it alone, and the prompt mentions it only where the receiver would otherwise trip over it, such as a check that is already red.
   - The ask outranks older documents. When a spec or a note contradicts the ask, follow the ask and list the override as an assumption. A documented constraint the ask leaves alone is carried into the prompt with its source.
   - When the ask reports an error or odd behaviour and the instruction files name a folder of past lessons, search that folder as it is on disk for the exact error text and the tool or library name. A lesson about the same symptom goes into Context with its path, as the first thing for the receiver to check.
   - Read `~/.claude/prompt-defaults.md` when it exists: the user's standing answers, one per line. A default fills a gap the ask leaves open. Everything it states counts as confirmed and stays off the assumptions list. The ask outranks a default.
   - Look at the skills and rules this session lists. When a skill's description covers the task, the prompt opens by naming it ("Load the `diagnose` skill first") and keeps the facts (symptom, files, Done), since the skill carries the method. When several skills cover it, name the most specific one, and let the user's instruction files break a tie. When a rule gates what the task touches, such as paths locked until a spec is approved, the prompt starts at that gate. This holds for a receiver in this session or a subagent of it: a receiver elsewhere has neither.
   - A receiver in this session already loads the instruction files, so the prompt leaves their content out. A subagent, or a receiver elsewhere, gets the conventions the task depends on.
   - A receiver that cannot see the repo gets the structure it needs pasted in or summarized, inside a tag.

   Done when every slot is either filled from evidence or marked as a gap.

3. **Settle each gap** with the treatment that fits it:
   - **Delegate**, when the receiver can find it by looking, running or testing. Finding it becomes part of the task, with a report of what it found.
   - **Ask**, when only the user knows it and a wrong guess would send the work the wrong way. One round, three questions at most, the gap with the most effect first. Each question carries your recommended answer, drawn from the evidence. With nothing to base a recommendation on, recommend the fallback: delegate it, or leave a placeholder.
   - **Assume**, for everything the user can veto at a glance: a default, a choice between small options, a length, a matter of taste. Your best guess goes into the prompt and is listed for the user in step 6.
   - **Placeholder**, for a fact only the user has, with no answer yet, in a prompt that leaves this session: `[shop name]`.

   When Ask and Assume both fit, assume: a listed assumption costs the user a glance, and a question costs a round trip. Ask only when a wrong guess would mean redoing the work.

   A missing **Why** is asked for when it would change the work, and is otherwise left out. A reason nobody gave stays out of the prompt.

   Ask with the question tool when there is one, and as a numbered list otherwise. Then end the turn and wait. Ask nothing when no gap needs it, and nothing when the user is away: every gap is then delegated or assumed.

4. **Write the prompt.** Follow [`guidelines.md`](references/guidelines.md) and the matching section of `tasks.md`. Read [`examples.md`](references/examples.md) for the size and shape that fit this receiver and this size of task.
   - Write in the user's voice, to the receiver, in the language of the rough ask.
   - "I" states only what the user said, confirmed, or wrote in their own instruction files. Evidence from a document keeps its source ("the spec ranks correctness first"), and what you found yourself is stated without "I" ("nothing else in the repo refers to it"). A gap is stated as a gap ("nobody has measured this yet").
   - The user's secrets, tokens and contact details stay out. A prompt that leaves this machine also leaves out home-directory paths and the names of the user's private files outside the repo. A fact the task needs goes in as a placeholder.

5. **Review it** against "Before showing" in `guidelines.md`, and fix what fails. Done when every check that applies to this receiver passes.

6. **Show it**, in this layout. Leave out a part that is empty.

   ````
   **Assumptions** (tell me which are wrong)
   - one line for each guess the user has not confirmed

   **Noticed** (outside this task, left alone): one line for each side finding

   **Fill in before sending**: the placeholders, in one line

   **Prompt**
   ```
   the prompt, alone in this block
   ```

   **Effort**: the level I'd set for this, and the reason in a few words (Claude receivers only)
   ````

   Close with one line that fits the receiver:
   - this session: "Run it here, or change something?"
   - a subagent: "Spawn it, or change something?"
   - elsewhere: "Ready to copy. Want anything changed?"
   - the user is away and the receiver is this session or a subagent: "You're away, so I'm starting on this now."
   - the fast path: "Nothing was guessed, so I'm starting on this now."

   The **fast path** applies when the receiver is this session, the size is small, the layout has no Assumptions part and no Fill-in part, and the task holds no destructive or irreversible action and nothing a session rule gates. An action like that waits for the user even when the ask names it. On the fast path the user has nothing to veto, so showing the prompt is enough.

   Then end the turn and wait for the answer, except on the fast path and when the user is away.

7. **Act on the answer.**
   - On "run it", the prompt becomes the user's request: do the work in this session. On "spawn it", start the subagent with the prompt as its brief. On the fast path, and when the user is away, start in the same turn, after the step-6 output.
   - For a receiver elsewhere, the copy block is the deliverable and the work stays with the user.
   - On a change, edit the prompt and show it again. A correction the user words as standing ("always", "never", "from now on") also goes into `~/.claude/prompt-defaults.md` as one dated line, creating the file when it is missing, and the reply says so. After any other corrected assumption, add once per conversation: "Say 'make it a default' to keep that for future prompts."
