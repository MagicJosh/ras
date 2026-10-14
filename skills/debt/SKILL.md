---
name: debt
description: Use when the user types /debt to list the deliberate shortcuts in the code. Collects every shortcut comment into one ledger and changes nothing.
disable-model-invocation: true
---

# Debt

A deliberate shortcut carries a comment like `shortcut: <limit>, upgrade when <trigger>`, for example `# shortcut: loads every row into memory, upgrade when a file passes 100 MB`. This skill collects those comments, so that no shortcut stays forever by accident.

## Steps

1. Search the project with the Grep tool, with line numbers, for this pattern: `(#|//|/\*|--|;)\s*shortcut:`. The Grep tool skips the files that git ignores.
2. Write one line per hit, grouped by file: `<file>:<line> <what is simplified>. Limit: <the limit>. Upgrade: <trigger>.`
3. Add `no-trigger` to a line when its comment names no upgrade trigger.
4. End with `<N> shortcuts, <M> with no trigger.` When there are no hits, say `No shortcuts found.`

## Rules

- Read only. Change no file. Write the ledger to a file only when the user asks.
- Skip a hit that is not a deferral, such as text about a keyboard shortcut.
- If the user names another marker, such as `/debt TODO`, search for that word instead.
