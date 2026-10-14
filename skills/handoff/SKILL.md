---
name: handoff
description: Use when the user types /handoff to pass the current work to a fresh session, a colleague or another agent. Writes one handoff file under .ras/handoffs/ and changes no other project file.
disable-model-invocation: true
---

# Handoff

Write one file that lets a reader who never saw this conversation continue the work.

## Steps

1. If the user named the next goal, such as `/handoff review the plan`, shape the file around that goal.
2. Write these sections. Keep each one short and concrete.
   - **Goal**: what the work is for, in one or two sentences.
   - **State**: what is done, what is in progress and what has not started. Name the branch and the last commit.
   - **Decisions**: each settled choice and its reason, one line each.
   - **Open questions**: each open choice, with your recommended answer.
   - **Next steps**: a numbered list. The reader can do step 1 without asking anything.
   - **Pointers**: the files, specs, commits, issues and commands that matter, by path or link.
3. Save the file as `.ras/handoffs/<date>-<topic>.md` in the project root. Use the Write tool, which creates the folder. If `.ras/handoffs/.gitignore` does not exist, create it with one line: `*`. That keeps every handoff out of git. Never edit the project's own `.gitignore`. Give the full path of the handoff file. If you cannot write there, print the file in your reply.

## Rules

- Point to a file, a spec or a commit by its path. Do not copy its content.
- Leave out secrets, tokens, passwords and personal data.
- Write for a reader who knows the tools but not this project.
- Mark what you did not check. Do not state a guess as a fact.
