# ras: Refined Agent Skills

A small Claude Code plugin for plan-first coding. The agent writes a spec, you approve it, the agent builds the simplest code that works, then it checks its result against the spec.

## Install

```
claude plugin marketplace add MagicJosh/ras
claude plugin install ras@magicjosh
```

Restart Claude Code. On Windows, install Git for Windows, so that `sh` is on the path. The hook needs only `sh`, `grep`, `sed`, `tr` and `cksum`.

Commands are namespaced by the plugin, so the `/` menu shows `/ras:spec`. Typing the short name, such as `/spec` or `/which`, also works, as long as no other command uses it.

Update:

```
claude plugin marketplace update magicjosh
claude plugin update ras@magicjosh
```

## The flow

1. You ask for a change.
2. The agent loads `spec`. If the request is unclear, it asks multiple-choice questions first (`AskUserQuestion`, or in its message when the tool is missing), and asks again until every answer that changes the build is known, for at most 3 rounds. Then it writes `specs/current.md` with a short Decisions list, shows you those decisions, and stops. Reply `ask me` to get questions on a spec that guessed.
3. You read the spec. Reply with exactly `approve spec`.
4. The agent loads `build` and implements the spec.
5. The agent loads `finalize`: defects, cuts, fresh checks, report. Then it archives the spec to `specs/<date>-<slug>.md`, which ends the approval, and keeps only the 5 newest archived specs. The hook puts a `.gitignore` with `*` in `specs/`, so git never tracks specs. To keep one spec in git, use `git add -f`. If a repo already tracks `specs/`, run `git rm -r --cached specs` once.

Until you approve, a hook denies `Edit`, `Write` and `NotebookEdit` on project files. It always allows `specs/current.md` and any path outside the project. If the spec changes after approval, the approval ends. When the agent asks for approval, the hook also shows you the Decisions section of the spec, or says that it has none. Reply `skip spec` to skip the gate until your next prompt. Approval state lives in `.claude/` and is git-ignored. The hook also puts a `.gitignore` with `*` in `specs/`, so git never tracks specs. The spec is not in `.claude/` because Claude Code asks before every write there.

The gate keeps the agent on track. It is not a sandbox. The agent can still write files through Bash.

At each session start, resume and compaction, the hook also gives the agent a 4-line reminder of this flow. A plugin cannot ship a `CLAUDE.md`: Claude Code does not load one from a plugin.

## Your own rules

Put rules you want in every session in `~/.claude/rules/`. Claude Code loads those files in every project, and they survive `/compact`. Do not rely on `~/AGENTS.md`: Claude Code reads an `AGENTS.md` only when no `CLAUDE.md` is in the working directory or above it, so most repositories hide it. Type `/rules` to install the lazy senior dev coding rules as `~/.claude/rules/lazy.md`. Keep always-on rules short: a study of repository context files found no general gain in task success and over 20% more cost ([Gloaguen et al., 2026](https://arxiv.org/abs/2602.11988)).

## The 10 skills

| Skill | Job |
|---|---|
| `spec` | Before any file change: ask what is unclear, write `specs/current.md` with its decisions, stop for approval |
| `build` | Implement the approved spec with the least code that works |
| `finalize` | The done step: defects, cuts, fresh checks, honest report |
| `diagnose` | Root cause, not symptom |
| `architecture` | Styles, characteristics, trade-offs, fitness functions, ADRs |
| `distributed-architecture` | Service size, data ownership, distributed transactions, contracts |
| `deep-review` | Strict maintainability review of messy code. Explicit request only |
| `security-check` | Auth, secrets, permissions, destructive operations, production |
| `which` | `/which <task>` names the 1-2 skills to use. User call only |
| `rules` | `/rules` installs the lazy senior dev rules in `~/.claude/rules/`. User call only |

## Plan mode

Claude Code has its own plan mode. It overlaps with `spec`. Use one of them for a task, not both.

## Off switch

In a repo's `.claude/settings.local.json`:

```json
{ "enabledPlugins": { "ras@magicjosh": false } }
```

## Tests

```
sh tests/test_spec_gate.sh
sh tests/check_skills.sh
claude plugin validate .
```

## Evals

`evals/` holds a suite for `claude plugin eval`: 13 cases, each a prompt in a small test repo. It checks that each skill loads on the right request and does its job. It also runs each case without the plugin, so the Δ column shows what the plugin adds.

```
claude plugin eval . --scaffold --trust-plugin --threshold 0.66 -j 4 --no-publish --max-cost-usd 60 --allow-tools Write Edit Bash
```

- You need Claude Code 2.1.269 or later and git 2.31 or later.
- A Bash grant needs the Claude Code sandbox: `bubblewrap` and `socat` on Linux and WSL2. Native Windows has no sandbox, so use WSL2.
- `--no-publish` keeps the report on your machine. Without it, a claude.ai account uploads the report, with the prompts and the grader results, as a private artifact.
- `--scaffold` runs `evals/fixture.sh` to build each test repo. Put `--allow-tools` last, because it takes a list.
- A full run is 78 agent runs. The first full run cost $4.31 at list price and took 3 minutes. On a subscription, this uses your plan limits. To try one case: `claude plugin eval . --case spec-first --runs 1 --ablation none --scaffold --trust-plugin --no-publish --allow-tools Write Edit`.
- The graders are free checks: regex, tool calls and files. They show if a skill loads and does its job, not if its advice is good.
- Read Δ only for cases with a result check. `architecture`, `distributed-architecture`, `deep-review` and `which` check only that the skill runs, so their Δ is always 1.00.
- Results go to `evals/results/`, which git ignores.

## Credits

- `build` is inspired by [ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT). The text is original.
- `skills/rules/references/lazy.md` is inspired by ponytail as well. The text is original.
- `architecture` and `distributed-architecture` are original text. They draw on ideas from *Fundamentals of Software Architecture* by Mark Richards and Neal Ford, and *Software Architecture: The Hard Parts* by Neal Ford, Mark Richards, Pramod Sadalage and Zhamak Dehghani. Read the books for the full picture.

## License

MIT, see `LICENSE`.
