---
name: rules
description: Use when the user types /rules to install the lazy senior dev coding rules for every session. Copies them to ~/.claude/rules/lazy.md and never overwrites without asking.
disable-model-invocation: true
---

# Rules

Install [the lazy senior dev rules](references/lazy.md) as a user rule file. Claude Code loads every file in `~/.claude/rules/` at the start of each session, in every project.

## Steps

1. Read `references/lazy.md` from this skill.
2. If `~/.claude/rules/lazy.md` does not exist, write the file with that exact text. Create the folder if needed.
3. If the file exists and differs, show the difference. Replace it only if the user says yes.
4. If `~/AGENTS.md`, `~/CLAUDE.md` or another file in `~/.claude/rules/` holds similar rules, tell the user. Claude Code reads an `AGENTS.md` only when no `CLAUDE.md` is in the working directory or above it, so the rule file is the reliable place. Two copies load the rules twice. Offer to remove the old copy, and do not remove it yourself.
5. Tell the user that the rules load from the next session.

## Rules

- Change nothing else in `~/.claude/`.
