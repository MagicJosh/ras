#!/bin/sh
# Test for hooks/spec-gate.sh. Run: sh tests/test_spec_gate.sh (or dash/bash).
# Each case feeds one JSON event on stdin and checks the exit code or the output.
root=$(cd "$(dirname "$0")/.." && pwd)
proj=$(mktemp -d)
tmp=$(mktemp -d)
g=$(mktemp -d)
trap 'rm -rf "$proj" "$tmp" "$g"' EXIT
export CLAUDE_PROJECT_DIR=$proj TMPDIR=$tmp GIT_CEILING_DIRECTORIES=$(dirname "$proj") # the temp dirs are no git repos
S=$proj/.claude
SID=s1
pass=0 fail=0

gate() { printf '%s' "$2" | sh "$root/hooks/spec-gate.sh" "$1" 2>/dev/null; } # event, json
write() { gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$1\",\"content\":\"x\"}}"; }
bash_() { gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"; }
say() { gate UserPromptSubmit "{\"session_id\":\"$SID\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$1\"}"; }
check() { # name, wanted exit code, got exit code
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1 (want exit $2, got $3)"; fi
}
reset() { rm -rf "$S" "$proj/specs" "$proj/.ras"; SID=s1; }
SP=$proj/specs/current.md
mkspec() { mkdir -p "$proj/specs" && printf '# Spec: t\n\n## Goal\nFix the bug.\n\n## Criteria\n- a\n' > "$SP"; }
R=$proj/.github/workflows/ci.yml

# Default lane: ordinary edits pass, with or without a spec.
reset; write "$proj/src/a.py"; check "allow a normal edit with no spec" 0 $?
write "src/a.py"; check "allow a relative path" 0 $?
mkspec; write "$proj/src/a.py"; check "allow a normal edit with an unapproved spec" 0 $?

# Risky paths need an approved spec.
reset; write "$R"; check "deny a risky edit with no spec" 2 $?
msg=$(printf '%s' "{\"session_id\":\"s1\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R\"}}" | sh "$root/hooks/spec-gate.sh" PreToolUse 2>&1 >/dev/null)
case $msg in *"risky path"*"workflows"*"specs/current.md"*"approve spec"*) check "deny message names the pattern and the way out" 0 0 ;; *) check "deny message names the pattern and the way out" 0 1 ;; esac
mkspec; write "$R"; check "deny a risky edit before approval" 2 $?
out=$(say "approve spec"); write "$R"; check "allow a risky edit after approve spec" 0 $?
case $out in "Approved spec: Fix the bug.") check "approval prints goal line" 0 0 ;; *) check "approval prints goal line" 0 1 ;; esac
write "$R"; check "allow again in the same session" 0 $?
SID=s2; write "$R"; check "approval from another session is ignored" 2 $?
SID=s1
echo "- changed" >> "$SP"; write "$R"; check "deny after the spec changes" 2 $?
say "approve spec" >/dev/null; write "$R"; check "re-approval allows again" 0 $?
mkdir -p "$proj/specs/done" && mv "$SP" "$proj/specs/done/x.md"; write "$R"; check "deny after the spec is archived" 2 $?
[ ! -e "$S/spec.approved" ]; check "archiving the spec drops the approval file" 0 $?
mkspec; write "$R"; check "a new spec needs its own approval" 2 $?
reset; mkdir -p "$S"; : > "$S/spec.approved"; write "$R"; check "deny: spec missing, spec.approved empty" 2 $?
reset; mkspec; mkdir -p "$S"; printf '%s\n' "$(cksum < "$SP")" > "$S/spec.approved"; write "$R"; check "deny: approval file has no session" 2 $?

# Which paths are risky.
reset
for f in .github/workflows/ci.yml .gitlab-ci.yml .env .env.local app/.env.production .husky/pre-commit .devcontainer/devcontainer.json \
  .mcp.json db/migrations/001_init.py migrations/x.txt schema.sql db/seed.SQL Dockerfile Dockerfile.dev docker-compose.yml docker-compose.prod.yml \
  infra/main.tf prisma/schema.prisma supabase/config.toml supabase/migrations/1.sql src/auth/login.py src/permissions/roles.py \
  src/auth.ts lib/permissions.rb app/policies.js .ras/risky-paths; do
  write "$proj/$f"; check "deny risky path $f" 2 $?
done
for f in .env.example .env.sample src/author.py src/oauth/client.py src/authors/list.py README.md src/migrate.py docs/auth-notes.md \
  src/env.py .github/CODEOWNERS specs/current.md specs/x.sql specs/migrations/y.txt sub/specs/current.md; do
  write "$proj/$f"; check "allow $f" 0 $?
done
write "/elsewhere/a.sql"; check "allow a risky name outside the project" 0 $?

# Windows paths.
# Runs in $proj: on Linux the hook would create a folder named C:\Users\me\repo in the working directory.
win() { (cd "$proj" && printf '%s' "{\"tool_input\":{\"file_path\":\"$1\"}}" | CLAUDE_PROJECT_DIR='C:\Users\me\repo' sh "$root/hooks/spec-gate.sh" PreToolUse 2>/dev/null); }
win 'C:\\Users\\me\\repo\\specs\\current.md'; check "allow Windows path to the spec" 0 $?
win 'C:\\Users\\me\\repo\\src\\a.py'; check "allow Windows path to a normal file" 0 $?
win 'c:/users/me/repo/.github/workflows/ci.yml'; check "deny Windows path to a risky file" 2 $?
win '/c/Users/me/repo/.github/workflows/ci.yml'; check "deny Git Bash path to a risky file" 2 $?
write "$(printf '%s' "$proj" | tr 'a-z' 'A-Z')/.github/workflows/ci.yml"; check "deny: project path in other case" 2 $?

# Repo override: .ras/risky-paths replaces the defaults.
reset; mkdir -p "$proj/.ras" && printf '# my paths\n\n^secret/\n' > "$proj/.ras/risky-paths"
write "$proj/secret/k.txt"; check "override: deny its own pattern" 2 $?
write "$R"; check "override: defaults no longer apply" 0 $?
write "$proj/.ras/risky-paths"; check "override: the file guards itself" 2 $?
bash_ "echo x > secret/k.txt"; check "override: Bash write denied" 2 $?
printf '# nothing is risky here\n\n' > "$proj/.ras/risky-paths"; write "$proj/secret/k.txt"; check "override: comments only means no risky path" 0 $?
rm -f "$proj/.ras/risky-paths"; write "$R"; check "override removed: defaults apply again" 2 $?

# Bash: a write-ish token plus a risky path. A guard rail, not a sandbox.
reset
bash_ "echo x > .env"; check "Bash: redirect into .env denied" 2 $?
bash_ "echo x >> $proj/.env.local"; check "Bash: append to an absolute .env.local denied" 2 $?
bash_ "cat a.txt | tee Dockerfile"; check "Bash: tee into Dockerfile denied" 2 $?
bash_ "sed -i s/a/b/ db/migrations/001.sql"; check "Bash: sed -i on a migration denied" 2 $?
bash_ "sed -n -i.bak s/a/b/ infra/main.tf"; check "Bash: sed -n -i on a tf file denied" 2 $?
bash_ "cp x.sql backup.txt"; check "Bash: cp of a sql file denied" 2 $?
bash_ "mv .github/workflows/ci.yml /tmp/ci.yml"; check "Bash: mv of a workflow denied" 2 $?
bash_ "cd app && rm -rf supabase"; check "Bash: rm of supabase denied" 2 $?
bash_ "git apply fix.patch; truncate -s 0 .env"; check "Bash: truncate .env denied" 2 $?
bash_ "dd if=x of=src/auth/login.py"; check "Bash: dd into an auth dir denied" 2 $?
bash_ "cat .env"; check "Bash: reading .env allowed" 0 $?
bash_ "cat .env 2>/dev/null"; check "Bash: read with 2>/dev/null allowed" 0 $?
bash_ "grep -r foo db/migrations/ 2>&1 | head"; check "Bash: grep of migrations allowed" 0 $?
bash_ "echo hi > src/a.py"; check "Bash: write to a normal file allowed" 0 $?
bash_ "cp specs/current.md specs/x.sql"; check "Bash: copy inside specs/ allowed" 0 $?
bash_ "ls -t specs/2*.md | tail -n +6 | xargs rm -f"; check "Bash: the finalize cleanup allowed" 0 $?
bash_ "mv specs/current.md specs/2026-01-01-x.md"; check "Bash: archiving the spec allowed" 0 $?
bash_ "git add -A && git commit -m done"; check "Bash: git add and commit allowed" 0 $?
bash_ "echo x > /etc/app.sql"; check "Bash: risky name outside the project allowed" 0 $?
gate PreToolUse '{"session_id":"s1","tool_name":"Bash","tool_input":{}}'; check "Bash: no command allowed" 0 $?
mkspec; say "approve spec" >/dev/null; bash_ "echo x > .env"; check "Bash: allowed after approval" 0 $?
SID=s2; bash_ "echo x > .env"; check "Bash: approval from another session ignored" 2 $?
SID=s1

# skip spec lets a risky edit through until the next prompt.
reset; say "skip spec" >/dev/null; write "$R"; check "allow after skip spec" 0 $?
say "go on" >/dev/null; write "$R"; check "deny on the next prompt" 2 $?

# Approval rules.
reset; mkspec; say "do not approve spec yet" >/dev/null; write "$R"; check "no approval from 'do not approve spec yet'" 2 $?
gate UserPromptSubmit '{"agent_id":"x","session_id":"s1","prompt":"approve spec"}' >/dev/null; write "$R"; check "no approval from agent_id event" 2 $?
say "  Approve Spec\\n" >/dev/null; write "$R"; check "approval ignores case and edge space" 0 $?
reset; out=$(say "approve spec"); case $out in "No specs/current.md to approve.") check "approve with no spec says so" 0 0 ;; *) check "approve with no spec says so" 0 1 ;; esac
reset; mkspec; say "approve spec" >/dev/null; gate SessionStart '{"source":"startup","session_id":"s1"}' >/dev/null; write "$R"; check "SessionStart clears the approval" 2 $?
[ -f "$S/.gitignore" ] && grep -q spec.approved "$S/.gitignore"; check "first state write adds .claude/.gitignore" 0 $?
gate PreToolUse 'not json {'; check "corrupt stdin denies" 2 $?
gate PreToolUse ''; check "empty stdin denies" 2 $?
printf '%s' '{"tool_input":{"file_path":"/x"}}' | env -u CLAUDE_PROJECT_DIR sh "$root/hooks/spec-gate.sh" PreToolUse 2>/dev/null; check "missing CLAUDE_PROJECT_DIR denies" 2 $?

# Stop: show the Decisions section when the agent asks for approval.
stop() { gate Stop "{\"session_id\":\"$SID\",\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"$1\"}"; }
json_ok() { j=$1; shift; printf '%s' "$j" | python3 -c 'import json,sys; m=json.load(sys.stdin)["systemMessage"]; sys.exit(0 if all(w in m for w in sys.argv[1:]) else 1)' "$@"; }
reset; mkspec; printf '\n## Decisions\n- Lock the row. Rejected: "retry" with a\\ backslash. Hard to undo: no.\n\n## Non-goals\n- x\n' >> "$SP"
out=$(stop 'Spec written. Reply with exactly: `approve spec`.'); check "Stop exits 0" 0 $?
json_ok "$out" 'Lock the row.' '"retry"' 'a\ backslash'; check "Stop prints the Decisions as valid JSON" 0 $?
json_ok "$out" 'Non-goals' 'x'; check "Stop stops at the next section" 1 $?
out=$(stop 'Which format do you want?'); check "Stop: silent when not asking for approval" "" "$out"
say "approve spec" >/dev/null; out=$(stop 'reply approve spec'); check "Stop: silent after approval" "" "$out"
reset; mkspec; out=$(stop 'Reply approve spec'); json_ok "$out" 'None written'; check "Stop: says when Decisions are missing" 0 $?
reset; out=$(stop 'Reply approve spec'); check "Stop: silent with no spec" "" "$out"
out=$(gate Stop 'not json {'); check "Stop: corrupt stdin stays silent" "0:" "$?:$out"

# Stop fallback: a turn that changed files must end with a Decisions section. Ask once, never loop.
git -C "$g" init -q && printf 'a\nb\n' > "$g/a.py" && git -C "$g" add a.py && git -C "$g" -c user.name=t -c user.email=t@t commit -qm init
gp() { CLAUDE_PROJECT_DIR=$g gate UserPromptSubmit "{\"session_id\":\"$SID\",\"prompt\":\"$1\"}" >/dev/null; }
gs() { CLAUDE_PROJECT_DIR=$g gate Stop "{\"session_id\":\"$SID\",\"stop_hook_active\":$2,\"last_assistant_message\":\"$1\"}"; }
blocked() { printf '%s' "$out" | python3 -c 'import json,sys; j=json.load(sys.stdin); sys.exit(0 if j["decision"] == "block" and all(w in j["reason"] for w in sys.argv[1:]) else 1)' "$@"; }
SID=t1; gp "fix it"; printf 'c\n' >> "$g/a.py"; printf 'n1\nn2\nn3\n' > "$g/new.py"
out=$(gs 'Done. All tests pass.' false); blocked 'touched 2 files, 4 lines' 'Decisions'; check "fallback blocks once and counts files and lines" 0 $?
out=$(gs 'Done. All tests pass.' true); check "fallback stays quiet when stop_hook_active is true" "" "$out"
out=$(gs 'Done.\\n\\n## Decisions\\n- none' false); check "fallback: a Decisions heading is enough" "" "$out"
out=$(gs 'Done.\\n\\n**Decisions**: none' false); check "fallback: bold Decisions is enough" "" "$out"
out=$(gs 'I made no decisions that matter.' false); blocked 'touched'; check "fallback: the word in prose is not a heading" 0 $?
gp "thanks, what did you change?"; out=$(gs 'A one-line fix.' false); check "fallback: a turn with no new change is quiet" "" "$out"
SID=t2; gp "again"; out=$(gs 'Nothing to report.' false); check "fallback: earlier uncommitted work is not this turn's" "" "$out"
SID=t3; out=$(gs 'No prompt seen.' false); check "fallback: no turn snapshot is quiet" "" "$out"
out=$(CLAUDE_PROJECT_DIR=$proj gate Stop '{"session_id":"t1","last_assistant_message":"Done."}'); check "fallback: not a git repo is quiet" "" "$out"
SID=t4; gp "spec please"; printf 'x\n' >> "$g/a.py"; mkdir -p "$g/specs"; printf '# Spec: t\n\n## Goal\nG.\n' > "$g/specs/current.md"
out=$(gs 'Spec written. Reply approve spec.' false); printf '%s' "$out" | grep -q systemMessage; check "fallback: an approval request shows the spec Decisions, not a block" 0 $?
SID=s1

# SessionStart: short context for every source; only startup and clear end the approval.
out=$(gate SessionStart '{"source":"startup"}'); printf '%s' "$out" | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]; t=c["additionalContext"]; sys.exit(0 if c["hookEventName"] == "SessionStart" and "approve spec" in t and "Decisions" in t and "/spec" in t and len(t.split("\n")) < 6 else 1)'; check "SessionStart prints under 6 lines of context as JSON" 0 $?
reset; mkspec; say "approve spec" >/dev/null; gate SessionStart '{"source":"compact"}' >/dev/null; write "$R"; check "compact keeps the approval" 0 $?
gate SessionStart '{"source":"resume"}' >/dev/null; write "$R"; check "resume keeps the approval" 0 $?
gate SessionStart '{"source":"clear"}' >/dev/null; write "$R"; check "clear ends the approval" 2 $?

# specs/ stays out of git.
reset; write "$proj/specs/current.md"; [ "$(cat "$proj/specs/.gitignore" 2>/dev/null)" = '*' ]; check "writing the spec creates specs/.gitignore" 0 $?
reset; mkdir -p "$proj/specs"; gate SessionStart '{"source":"resume"}' >/dev/null; [ -f "$proj/specs/.gitignore" ]; check "session start ignores an existing specs/" 0 $?
g2=$(mktemp -d); git -C "$g2" init -q && mkdir -p "$g2/specs" && printf '*\n' > "$g2/specs/.gitignore" && : > "$g2/specs/current.md" && : > "$g2/specs/2026-01-01-x.md"
[ -z "$(git -C "$g2" status --porcelain)" ]; check "git sees nothing in specs/" 0 $?; rm -rf "$g2"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
