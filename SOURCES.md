# Sources

The skills and docs in this repo rest on facts about Claude models, Claude Code and the Artifact platform. Those facts change. Each row names a claim, where it lives, where it came from and when it was last checked.

When a new model or a new Claude Code release ships:

1. Re-read each source. Fix the claim where it changed, and update the date.
2. Run the evals with `--model <new model>` (README, Evals) and read the Δ column. A skill that adds nothing on the new model is a candidate to cut.
3. Make the change like any other: the checks in README (Tests) pass, and the eval scores do not get worse.

A row with "not recorded" still needs its source found.

| Claim | Lives in | Source | Checked |
|---|---|---|---|
| How to write a prompt for current Claude models: instructions are followed literally, a reason goes with each constraint, calm wording, effort levels | `skills/prompt/references/guidelines.md` | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices and the two model pages linked at the top of that file | 2026-11-11 |
| What an eval grader can see, how runs are isolated, `--model` and `--judge-model`, WSL2 for a Bash grant, Claude Code 2.1.269 as the minimum | `README.md` (Evals), `evals/` | https://code.claude.com/docs/en/plugin-evals.md | 2026-11-11 |
| `"onFailure": "block"` makes a failing hook block the call, from Claude Code 2.1.295 | `hooks/hooks.json`, `CHANGELOG.md` | not recorded | not recorded |
| Claude Code reads an `AGENTS.md` only when no `CLAUDE.md` is in the working directory or above it, and loads `~/.claude/rules/` in every session | `README.md` (Your own rules), `skills/rules/SKILL.md` | not recorded | not recorded |
| Repository context files bring no general gain in task success and over 20% more cost | `README.md` (Your own rules) | https://arxiv.org/abs/2602.11988 | not recorded |
| `AskUserQuestion` is missing in headless runs | `skills/spar/SKILL.md`, `skills/spec/SKILL.md` | not recorded | not recorded |
| The word caps on skills | `tests/check_skills.sh` | not recorded. The nearest evidence is the cost A/B in `CHANGELOG.md` (Sonnet 5.5 medium, Claude Code 2.1.296) | not recorded |
| The CDN allowlist and the `capabilities` names of a published page | `skills/artifacts/lint.mjs`, `skills/artifacts/SKILL.md` | the Artifact tool's own page contract. No URL recorded | not recorded |
| CI validates the plugin with `@anthropic-ai/claude-code@2.1.296` | `.github/workflows/validate.yml` | pinned on purpose | not recorded |
