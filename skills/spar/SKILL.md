---
name: spar
description: Use when the user wants a plan, design or decision stress-tested, or asks to spar or to be grilled. Interviews in rounds until no decision is open.
disable-model-invocation: true
---

# Spar

Interview the user until you both agree on every decision that changes what gets built or how it is checked.

## Rounds

1. Read the request and the code it touches. List the open decisions. Some decisions depend on others. A decision is ready when every decision it depends on is settled.
2. Ask every ready decision in one round. Number the questions. Give your recommended answer for each, worded so that `yes` accepts it. Use this format:

   **Q1. <the question>?**
   <the context, and the options when there are options>
   Recommended: <your answer, with a one-line reason>

3. End the round with this line: "Reply `yes` to take every recommendation, or answer by number." Then stop and wait.
4. Read the answers and mark those decisions settled. Find the decisions that are ready now, and ask the next round. A question that depends on an answer from the current round waits for the next round.
5. When no decision is open, list the decisions, one line each. Ask the user to confirm the list, and do not act on it before the user confirms.
6. For a confirmed decision that is hard to reverse and beat a real alternative, offer to record it as an ADR in `docs/adr/`, in the format of `architecture` step 6. Write it only on yes. Say nothing about ADRs for other decisions.

## Rules

- Facts are your job. Look them up in the code, the docs or the tools. Give a slow search to a subagent when you can, and meanwhile ask the questions that do not depend on it. Never ask the user for a fact you can find.
- Decisions belong to the user: goals, users, scope, constraints and what done looks like. Decide internal details yourself.
- Each question must change the build or the check. Ask no filler.
- A clear request has no open decisions. Then say so and ask nothing.
- Ask in your message, not with `AskUserQuestion`. Fixed options push the user to pick instead of answer, and the tool is missing in headless runs.
- There is no limit on rounds. The user can reply `wrap up` at any time. Then stop asking, and list each open decision with your recommended answer as an assumption.
