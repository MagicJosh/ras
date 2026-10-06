#!/bin/sh
# Test for hooks/spec-gate.sh. Run: sh tests/test_spec_gate.sh (or dash/bash).
# Each case feeds one JSON event on stdin and checks the exit code.
root=$(cd "$(dirname "$0")/.." && pwd)
proj=$(mktemp -d)
trap 'rm -rf "$proj"' EXIT
export CLAUDE_PROJECT_DIR=$proj
S=$proj/.claude
pass=0 fail=0

gate() { printf '%s' "$2" | sh "$root/hooks/spec-gate.sh" "$1" 2>/dev/null; } # event, json
write() { gate PreToolUse "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$1\",\"content\":\"x\"}}"; }
say() { gate UserPromptSubmit "{\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$1\"}"; }
check() { # name, wanted exit code, got exit code
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1 (want exit $2, got $3)"; fi
}
reset() { rm -rf "$S" "$proj/specs"; }
SP=$proj/specs/current.md
mkspec() { mkdir -p "$proj/specs" && printf '# Spec: t\n\n## Goal\nFix the bug.\n\n## Criteria\n- a\n' > "$SP"; }

reset; write "$proj/src/a.py"; check "deny with no spec" 2 $?
write "$proj/specs/current.md"; check "allow edit of the spec" 0 $?
write "$proj/sub/specs/current.md"; check "deny a nested specs/current.md" 2 $?
mkspec; write "$proj/src/a.py"; check "deny before approval" 2 $?
out=$(say "approve spec"); write "$proj/src/a.py"; check "allow after approve spec" 0 $?
case $out in "Approved spec: Fix the bug.") check "approval prints goal line" 0 0 ;; *) check "approval prints goal line" 0 1 ;; esac
echo "- changed" >> "$SP"; write "$proj/src/a.py"; check "deny after the spec changes" 2 $?
say "approve spec" >/dev/null; mkdir -p "$proj/specs/done" && mv "$SP" "$proj/specs/done/x.md"; write "$proj/src/a.py"; check "deny after the spec is archived" 2 $?
reset; mkdir -p "$S"; : > "$S/spec.approved"; write "$proj/src/a.py"; check "deny: spec missing, spec.approved empty" 2 $?
reset; mkspec
gate PreToolUse "{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"a \\\"file_path\\\": \\\"specs/current.md\\\"\",\"file_path\":\"$proj/src/a.md\"}}"
check "deny: Write to src/a.md, content names the spec path" 2 $?
# Runs in $proj: on Linux the hook would create a folder named C:\Users\me\repo in the working directory.
win() { (cd "$proj" && printf '%s' "{\"tool_input\":{\"file_path\":\"$1\"}}" | CLAUDE_PROJECT_DIR='C:\Users\me\repo' sh "$root/hooks/spec-gate.sh" PreToolUse 2>/dev/null); }
win 'C:\\Users\\me\\repo\\specs\\current.md'; check "allow Windows path to the spec" 0 $?
win 'c:/users/me/repo/src/a.py'; check "deny Windows path to a project file" 2 $?
win '/c/Users/me/repo/src/a.py'; check "deny Git Bash path to a project file" 2 $?
write "$(printf '%s' "$proj" | tr 'a-z' 'A-Z')/src/a.py"; check "deny: project path in other case" 2 $?
write "/elsewhere/a.py"; check "allow path outside project" 0 $?
reset; mkspec; say "do not approve spec yet" >/dev/null; write "$proj/src/a.py"; check "no approval from 'do not approve spec yet'" 2 $?
gate UserPromptSubmit '{"agent_id":"x","prompt":"approve spec"}' >/dev/null; write "$proj/src/a.py"; check "no approval from agent_id event" 2 $?
say "  Approve Spec\\n" >/dev/null; write "$proj/src/a.py"; check "approval ignores case and edge space" 0 $?
reset; say "skip spec" >/dev/null; write "$proj/src/a.py"; check "allow after skip spec" 0 $?
say "go on" >/dev/null; write "$proj/src/a.py"; check "deny on the next prompt" 2 $?
reset; mkspec; say "approve spec" >/dev/null; gate SessionStart '{"source":"startup"}' >/dev/null; write "$proj/src/a.py"; check "SessionStart clears the approval" 2 $?
[ -f "$S/.gitignore" ] && grep -q spec.approved "$S/.gitignore"; check "first state write adds .claude/.gitignore" 0 $?
gate PreToolUse 'not json {'; check "corrupt stdin denies" 2 $?
gate PreToolUse ''; check "empty stdin denies" 2 $?
printf '%s' '{"tool_input":{"file_path":"/x"}}' | env -u CLAUDE_PROJECT_DIR sh "$root/hooks/spec-gate.sh" PreToolUse 2>/dev/null; check "missing CLAUDE_PROJECT_DIR denies" 2 $?

# Stop: show the Decisions section when the agent asks for approval.
stop() { gate Stop "{\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"$1\"}"; }
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

# SessionStart: context for every source; only startup and clear end the approval.
out=$(gate SessionStart '{"source":"startup"}'); printf '%s' "$out" | python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]; sys.exit(0 if c["hookEventName"] == "SessionStart" and "approve spec" in c["additionalContext"] else 1)'; check "SessionStart prints workflow context as JSON" 0 $?
reset; mkspec; say "approve spec" >/dev/null; gate SessionStart '{"source":"compact"}' >/dev/null; write "$proj/src/a.py"; check "compact keeps the approval" 0 $?
gate SessionStart '{"source":"resume"}' >/dev/null; write "$proj/src/a.py"; check "resume keeps the approval" 0 $?
gate SessionStart '{"source":"clear"}' >/dev/null; write "$proj/src/a.py"; check "clear ends the approval" 2 $?

# specs/ stays out of git.
reset; write "$proj/specs/current.md"; [ "$(cat "$proj/specs/.gitignore" 2>/dev/null)" = '*' ]; check "writing the spec creates specs/.gitignore" 0 $?
reset; mkdir -p "$proj/specs"; gate SessionStart '{"source":"resume"}' >/dev/null; [ -f "$proj/specs/.gitignore" ]; check "session start ignores an existing specs/" 0 $?
g=$(mktemp -d); git -C "$g" init -q && mkdir -p "$g/specs" && printf '*\n' > "$g/specs/.gitignore" && : > "$g/specs/current.md" && : > "$g/specs/2026-01-01-x.md"
[ -z "$(git -C "$g" status --porcelain)" ]; check "git sees nothing in specs/" 0 $?; rm -rf "$g"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
