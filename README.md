# ras: Refined Agent Skills

A small Claude Code plugin. The agent works normally and keeps diffs small. Risky changes need a spec you approve first. Every reply that changes code ends with a short list of the choices the agent made.

## Install

```
claude plugin marketplace add MagicJosh/ras
claude plugin install ras@magicjosh
```

Restart Claude Code. On Windows, install Git for Windows, so that `sh` is on the path. The risky-path check (`PreToolUse`) needs only `sh`, `awk` and `cksum`. The other hook events also use `git`, `grep`, `sed` and `tr`.

Commands are namespaced by the plugin, so the `/` menu shows `/ras:spec`. Typing the short name, such as `/spec` or `/which`, also works, as long as no other command uses it.

Update:

```
claude plugin marketplace update magicjosh
claude plugin update ras@magicjosh
```

## Two lanes

**Default lane.** You ask for a change. The agent does it, runs the project's own check, and ends the reply with a `Decisions` section. No spec. No approval. Use this for most work.

**Gate lane.** The agent writes a spec first and waits for your approval. You get here in two ways:

- You run `/spec` (or `/ras:spec`) or ask for a plan.
- The agent tries to edit a risky path, and the hook denies the edit.

In the gate lane:

1. The agent loads `spec`. It asks only what is still unknown: the goal, who uses it, must-have versus nice-to-have, what is out of scope, constraints, and what done looks like. It asks in one round of multiple-choice questions (`AskUserQuestion`), or in its message when the tool is missing.
2. When every question has an answer, it writes `specs/current.md`: Goal, Decisions, Proposed additions (details you did not ask for), criteria, non-goals, blast radius. It asks for approval once.
3. You read the spec and reply with exactly `approve spec`. Reply `ask me` first to get questions on a spec that guessed.
4. The agent loads `build`, implements the spec, then loads `finalize`: defects, cuts, fresh checks, report. `finalize` archives the spec to `specs/<date>-<slug>.md`, which ends the approval. It keeps the 5 newest archived specs.

The hook puts a `.gitignore` with `*` in `specs/`, so git never tracks specs. To keep one spec in git, use `git add -f`. If a repo already tracks `specs/`, run `git rm -r --cached specs` once.

## Risky paths

The hook denies `Edit`, `Write`, `NotebookEdit`, `Bash` and `PowerShell` writes on these paths until you approve a spec in this session. It always allows `specs/` and any path outside the project. It resolves `.` and `..` first, so `specs/../.env` is `.env`.

- `.github/workflows/`, `.github/actions/`, `.gitlab-ci.yml`
- `.env` and `.env.*`, `.envrc`, but not `.env.example`, `.env.sample`, `.env.template`, `.env.dist`
- `.husky/`, `.devcontainer/`, `.mcp.json`
- any `migrations/` folder, `db/migrate/`, any `*.sql`
- `Dockerfile*`, `docker-compose*`, `compose.yaml` and `compose.*.yml`, `*.tf`
- `prisma/schema.prisma`, `supabase/config.toml`
- an `auth` or `permissions` folder, and files named `auth.*`, `permissions.*`, `policies.*`

The hook protects itself. `.ras/` is always risky, except `.ras/handoffs/`, and so is `.claude/spec.*` (the approval and skip state). The agent cannot loosen the list or forge an approval on its own.

To use your own list, create `.ras/risky-paths` in the repo. One extended regular expression per line. Blank lines and lines that start with `#` are ignored, and CRLF line ends are fine. The file replaces the defaults. It matches the path relative to the repo root, in lower case. A pattern that is not a valid regex, or a file the hook cannot read, makes the hook deny every edit until you fix the file.

```
# .ras/risky-paths
^infra/
^src/billing/
(^|/)\.env(\.[^/]*)?$
```

The hook also checks `Bash` and `PowerShell`. It denies a command that writes to a risky path: a redirect target (`>`, `>>`, `&>`, `2>`), or an argument of `rm`, `mv`, `touch`, `tee`, `truncate`, `patch`, `sed -i`, `perl -i`, `dd of=`, `git apply`, `git rm`, `git mv`, `git restore`, `cp`, `ln` and `install` (the destination only), and the PowerShell cmdlets such as `Set-Content`, `Out-File` and `Remove-Item`. It also reads inside `sh -c`, `eval` and shell heredocs. Reading a risky file is fine, also into another file: `cat .env > x` passes, `cp x .env` does not. A command over 64 KB or 2,000 lines is denied: write the file with the Write tool. This is a guard rail, not a sandbox. It misses variables, globs, scripts and anything built at run time. It does not catch deleting a parent folder such as `rm -rf .github`.

An approval lasts for the session that got it, and only while the spec is unchanged. Archiving the spec ends it. A new session, `/clear`, or a change to the spec ends it too. Approval state lives in `.claude/` and is git-ignored. Reply `skip spec` to skip the gate for this session until your next prompt.

Security review is not tied to paths. `security-check` should load in either lane when a change touches auth, permissions, secrets, payments, personal data or data deletion.

## The Decisions habit

Every reply that changed code ends with a short `Decisions` section: the choices the agent made that you did not specify, or `none`. The session-start hint asks for it. As a fallback, the `Stop` hook checks whether the turn changed files (`git status`, so it needs a git repo) and the reply has no `Decisions` heading. If so, it asks once, with "touched N files". Binary files do not count. It never asks twice.

When the agent asks you to approve a spec, the hook also shows you the spec's Decisions section.

At each session start, resume and compaction, the hook gives the agent a 5-line reminder of all this. A plugin cannot ship a `CLAUDE.md`: Claude Code does not load one from a plugin.

## Your own rules

Put rules you want in every session in `~/.claude/rules/`. Claude Code loads those files in every project, and they survive `/compact`. Do not rely on `~/AGENTS.md`: Claude Code reads an `AGENTS.md` only when no `CLAUDE.md` is in the working directory or above it, so most repositories hide it. Type `/rules` to install the lazy senior dev coding rules as `~/.claude/rules/lazy.md`. Keep always-on rules short: a study of repository context files found no general gain in task success and over 20% more cost ([Gloaguen et al., 2026](https://arxiv.org/abs/2602.11988)).

## The 10 skills

| Skill | Job |
|---|---|
| `spec` | On `/spec` or a denied risky edit: goals first, then `specs/current.md`, then one approval |
| `build` | Gate lane: implement the approved spec with the least code that works |
| `finalize` | Gate lane: defects, cuts, fresh checks (once per code state), honest report |
| `diagnose` | Only when the cause is unknown: root cause, not symptom |
| `architecture` | Styles, characteristics, trade-offs, fitness functions, ADRs |
| `distributed-architecture` | Service size, data ownership, distributed transactions, contracts |
| `deep-review` | Strict maintainability review of messy code. Explicit request only |
| `security-check` | Risky behavior in any lane: auth, permissions, secrets, payments, personal data, deletes |
| `which` | `/which <task>` names the 1-2 skills to use. User call only |
| `rules` | `/rules` installs the lazy senior dev rules in `~/.claude/rules/`. User call only |

## Plan mode

Claude Code has its own plan mode. It overlaps with `/spec`. Use one of them for a task, not both.

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

`evals/` holds a suite for `claude plugin eval`: 15 cases, each a prompt in a small test repo. It checks that each skill loads on the right request and does its job. It also runs each case without the plugin, so the Δ column shows what the plugin adds.

```
claude plugin eval . --scaffold --trust-plugin --threshold 0.66 -j 4 --no-publish --max-cost-usd 60 --allow-tools Write Edit Bash
```

- You need Claude Code 2.1.269 or later and git 2.31 or later.
- A Bash grant needs the Claude Code sandbox: `bubblewrap` and `socat` on Linux and WSL2. Native Windows has no sandbox, so use WSL2.
- `--no-publish` keeps the report on your machine. Without it, a claude.ai account uploads the report, with the prompts and the grader results, as a private artifact.
- `--scaffold` runs `evals/fixture.sh` to build each test repo. Put `--allow-tools` last, because it takes a list.
- A full run is 90 agent runs. On a subscription, this uses your plan limits. To try one case: `claude plugin eval . --case spec-first --runs 1 --ablation none --scaffold --trust-plugin --no-publish --allow-tools Write Edit`.
- The graders are free checks: regex, tool calls and files. They show if a skill loads and does its job, not if its advice is good.
- Read Δ only for cases with a result check. `architecture`, `distributed-architecture`, `deep-review` and `which` check only that the skill runs, so their Δ is always 1.00.
- Results go to `evals/results/`, which git ignores.

## Credits

- `build` is inspired by [ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert (MIT). The text is original.
- `skills/rules/references/lazy.md` is inspired by ponytail as well. The text is original.
- `architecture` and `distributed-architecture` are original text. They draw on ideas from *Fundamentals of Software Architecture* by Mark Richards and Neal Ford, and *Software Architecture: The Hard Parts* by Neal Ford, Mark Richards, Pramod Sadalage and Zhamak Dehghani. Read the books for the full picture.

## License

MIT, see `LICENSE`.
