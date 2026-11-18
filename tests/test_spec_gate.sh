#!/bin/sh
# Test for hooks/spec-gate.sh. Run: sh tests/test_spec_gate.sh (or dash/bash).
# Each case feeds one JSON event on stdin and checks the exit code or the output.
root=$(cd "$(dirname "$0")/.." && pwd)
proj=$(mktemp -d)
tmp=$(mktemp -d)
g=$(mktemp -d)
g3=$(mktemp -d)
gf=$(mktemp -d)
hm=$(mktemp -d)
trap 'rm -rf "$proj" "$tmp" "$g" "$g3" "$gf" "$hm"' EXIT
export CLAUDE_PROJECT_DIR=$proj TMPDIR=$tmp GIT_CEILING_DIRECTORIES=$(dirname "$proj") # the temp dirs are no git repos
export HOME=$hm # the guard checks ~/.claude: keep the real one out of the tests
S=$proj/.claude
SID=s1
pass=0 fail=0
py=python3; $py -c 1 2>/dev/null || py=python

gate() { printf '%s' "$2" | sh "$root/hooks/spec-gate.sh" "$1" 2>/dev/null; } # event, json
write() { gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$1\",\"content\":\"x\"}}"; }
ps_() { gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"PowerShell\",\"tool_input\":{\"command\":\"$1\"}}"; }
bash_() { gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"; }
say() { gate UserPromptSubmit "{\"session_id\":\"$SID\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$1\"}"; }
check() { # name, wanted exit code, got exit code
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); printf 'ok   %s\n' "$1"; else fail=$((fail + 1)); printf 'FAIL %s (want exit %s, got %s)\n' "$1" "$2" "$3"; fi
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
  src/auth.ts lib/permissions.rb app/policies.js .ras/risky-paths .claude/spec.approved .claude/spec.skip .ras/handoffs/../risky-paths \
  .envrc compose.yaml compose.yml compose.override.yml db/migrate/20240101_x.rb .github/actions/setup/action.yml; do
  write "$proj/$f"; check "deny risky path $f" 2 $?
done
for f in .env.example .env.sample .env.template .env.dist supabase/functions/x/index.ts src/compose.ts docker/composer.yaml src/author.py src/oauth/client.py src/authors/list.py README.md src/migrate.py docs/auth-notes.md \
  src/env.py .github/CODEOWNERS .ras/handoffs/2026-10-13.md specs/current.md specs/x.sql specs/migrations/y.txt sub/specs/current.md; do
  write "$proj/$f"; check "allow $f" 0 $?
done
write "/elsewhere/a.sql"; check "allow a risky name outside the project" 0 $?

# Windows paths.
# Runs in $proj: on Linux the hook would create a folder named C:\Users\me\repo in the working directory.
# Git Bash has cygpath: there the project is the real temp folder in its Windows form.
if command -v cygpath >/dev/null 2>&1; then W=$(cygpath -w "$proj"); else W='C:\Users\me\repo'; fi
Wj=$(printf '%s' "$W" | sed 's/\\/\\\\/g')                      # for inside JSON
Wf=$(printf '%s' "$W" | tr '\\A-Z' '/a-z')                      # c:/users/me/repo
Wg=/$(printf '%s' "$Wf" | sed 's,^\([a-z]\):,\1,')             # /c/users/me/repo
winj() { (cd "$proj" && printf '%s' "$1" | CLAUDE_PROJECT_DIR=$W sh "$root/hooks/spec-gate.sh" PreToolUse 2>/dev/null); }
win() { winj "{\"tool_input\":{\"file_path\":\"$1\"}}"; }
winb() { winj "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"; }
winp() { winj "{\"tool_name\":\"PowerShell\",\"tool_input\":{\"command\":\"$1\"}}"; }
win "$Wj"'\\specs\\current.md'; check "allow Windows path to the spec" 0 $?
win "$Wj"'\\src\\a.py'; check "allow Windows path to a normal file" 0 $?
win "$Wf/.github/workflows/ci.yml"; check "deny Windows path to a risky file" 2 $?
win "$Wg/.github/workflows/ci.yml"; check "deny Git Bash path to a risky file" 2 $?
win "$Wj"'\\specs\\..\\.env'; check "deny Windows path that climbs out of specs" 2 $?
winb 'echo x > specs/../.env'; check "deny Bash climb out of specs with a Windows project" 2 $?
winb "echo x > $Wf/.env"; check "deny Bash redirect to a drive-letter path" 2 $?
winb "echo x > $Wg/.env"; check "deny Bash redirect to a Git Bash path" 2 $?
winb "echo x > $Wf/src/a.py"; check "allow Bash redirect to a normal drive-letter path" 0 $?
winp "Set-Content -Path $Wj\\\\.env -Value x"; check "deny PowerShell Set-Content on a Windows path" 2 $?
winp "Set-Content -Path $Wj\\\\src\\\\a.py -Value x"; check "allow PowerShell Set-Content on a normal Windows path" 0 $?
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
bash_ "cp backup.txt x.sql"; check "Bash: cp into a sql file denied" 2 $?
bash_ "cp x.sql backup.txt"; check "Bash: reading a sql file into another file allowed" 0 $?
bash_ "mv .github/workflows/ci.yml /tmp/ci.yml"; check "Bash: mv of a workflow denied" 2 $?
bash_ "rm -rf supabase/migrations"; check "Bash: rm of supabase/migrations denied" 2 $?
bash_ "cd app && rm -rf supabase"; check "Bash: rm of the supabase folder allowed in a project outside git (the folder check needs git)" 0 $?
bash_ "git apply fix.patch; truncate -s 0 .env"; check "Bash: truncate .env denied" 2 $?
bash_ "dd if=x of=src/auth/login.py"; check "Bash: dd into an auth dir denied" 2 $?
bash_ "cat .env"; check "Bash: reading .env allowed" 0 $?
bash_ "cat .env 2>/dev/null"; check "Bash: read with 2>/dev/null allowed" 0 $?
bash_ "grep -r foo db/migrations/ 2>&1 | head"; check "Bash: grep of migrations allowed" 0 $?
bash_ "echo hi > src/a.py"; check "Bash: write to a normal file allowed" 0 $?
bash_ "cp specs/current.md specs/x.sql"; check "Bash: copy inside specs/ allowed" 0 $?
bash_ "ls -t specs/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md | tail -n +6 | xargs rm -f"; check "Bash: the finalize cleanup allowed" 0 $?
bash_ "mv specs/current.md specs/2026-01-01-x.md"; check "Bash: archiving the spec allowed" 0 $?
bash_ "git add -A && git commit -m done"; check "Bash: git add and commit allowed" 0 $?
bash_ "echo x > /etc/app.sql"; check "Bash: risky name outside the project allowed" 0 $?
gate PreToolUse '{"session_id":"s1","tool_name":"Bash","tool_input":{}}'; check "Bash: no command allowed" 0 $?
mkspec; say "approve spec" >/dev/null; bash_ "echo x > .env"; check "Bash: allowed after approval" 0 $?
SID=s2; bash_ "echo x > .env"; check "Bash: approval from another session ignored" 2 $?
SID=s1

# Paths resolve as text, so . and .. cannot hide a risky path.
reset
write "specs/../.env"; check "deny Write specs/../.env" 2 $?
write "$proj/specs/../.env"; check "deny Write of an absolute specs/../.env" 2 $?
write ".github/./workflows/ci.yml"; check "deny Write .github/./workflows/ci.yml" 2 $?
write 'specs\\..\\.env'; check "deny Write with backslashes climbing out of specs" 2 $?
write '\u002eenv'; check "deny: a \\u escape the guard cannot check" 2 $?
write "src/./a.py"; check "allow src/./a.py" 0 $?
write "specs/./current.md"; check "allow specs/./current.md as a spec" 0 $?
write "../outside/.env"; check "allow a relative path that leaves the project" 0 $?

# Bash and PowerShell: redirect targets and the arguments of write commands. A guard rail, not a sandbox.
bdeny() { bash_ "$1"; check "Bash deny: $1" 2 $?; }
ballow() { bash_ "$1"; check "Bash allow: $1" 0 $?; }
pdeny() { ps_ "$1"; check "PowerShell deny: $1" 2 $?; }
pallow() { ps_ "$1"; check "PowerShell allow: $1" 0 $?; }
bdeny "echo x > specs/../.env"
bdeny "echo x > .github/./workflows/ci.yml"
bdeny "echo x >.env"
bdeny "echo x>.env"
bdeny "echo x &> .env"
bdeny "ls 2>.env"
bdeny "printf x | tee -a .env"
bdeny 'bash -c \"echo x > .env\"'
bdeny "sh -c 'rm -f .env'"
bdeny 'eval \"rm .env\"'
bdeny 'echo $(rm -f .env)'
bdeny "(cd app; rm .env)"
bdeny "sudo rm .env"
bdeny "FOO=1 rm .env"
bdeny "/bin/rm .env"
bdeny "cat > .env <<'EOF'\nx\nEOF"
bdeny "bash <<'EOF'\nrm -f .env\nEOF"
bdeny "cp backup.txt x.sql"
bdeny "ln -sf /dev/null .env"
bdeny "perl -pi -e s/a/b/ .env"
bdeny "git rm .env"
bdeny "git restore .github/workflows/ci.yml"
bdeny "echo x > $proj/.env"
bdeny "rm -rf supabase/migrations"
bdeny "rm -rf .ras"
bdeny "mv .ras /tmp/x"
bdeny "touch .claude/spec.skip"
bdeny "echo x > .claude/spec.approved"
ballow 'git commit -m \"Patch auth redirect\"'
ballow "pytest tests/auth > /tmp/out 2>&1"
ballow "npx supabase gen types typescript --local > src/types/db.ts"
ballow "cat .env > /tmp/x"
ballow "cp .env /tmp/env.bak"
ballow 'echo \"a > .env\" > notes.txt'
ballow "echo hi # > .env"
ballow "git checkout feature/auth"
ballow "cat > notes.md <<'EOF'\necho x > .env\nrm -rf .ras\nEOF"
ballow "rm -rf ./build"
ballow "echo x > ./out.txt"
ballow "ls -la .ras"
ballow "cat .claude/spec.approved"
ballow "rm -rf .ras/handoffs/old"
ballow "echo x > .ras/handoffs/h.md"
ballow "supabase functions deploy"
ballow "grep -r auth src > /tmp/hits"
pdeny "Set-Content -Path .env -Value x"
pdeny "Remove-Item -Recurse .ras"
pdeny 'Out-File specs\\..\\.env'
pdeny '\"x\" | Out-File -FilePath .github\\workflows\\ci.yml'
pdeny "echo x > .env"
pdeny "Copy-Item a.txt .env"
pallow "Get-Content .env"
pallow "Set-Content -Path notes.txt -Value x"
pallow 'Get-ChildItem .github\\workflows'
bdeny "git -C app rm .env"
bdeny "rm -- .env"
bdeny "rm .ENV"
bdeny "ls | xargs rm .env"
bdeny "install -m 644 a .github/workflows/x.yml"
bdeny "dd if=x of=.env bs=1"
bdeny "sed --in-place=.bak s/a/b/ .env"
bdeny "mv --target-directory=.github/workflows a"
bdeny "pwsh -c 'Remove-Item .env'"
bdeny "echo a\nrm .env"
ballow "dd if=.env of=/tmp/x"
ballow "sed -n s/a/b/p .env"
ballow "rm ~/.env"
ballow "rm specs/x.sql"
ballow "echo a \\\\\nrm .env"
pdeny "Remove-Item -Path:.env"
pdeny "Remove-Item a,.env"
pdeny 'Set-Content -Path \"a b\\.env\" -Value x'
pallow "Copy-Item .env a.txt"
pallow "Get-Content .env | Set-Content notes.txt"
ps_ ""; check "PowerShell: empty command allowed" 0 $?
mkspec; say "approve spec" >/dev/null; ps_ "Set-Content -Path .env -Value x"; check "PowerShell: allowed after approval" 0 $?
reset

# Limits and failures. A guard that cannot check a call says so and denies it.
line='alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu'
big="cat > src/gen.py <<'EOF'"; i=0
while [ $i -lt 150 ]; do big="$big\n$line $i"; i=$((i + 1)); done
big="$big\nEOF"
t0=$(date +%s%N); bash_ "$big"; rc=$?; t1=$(date +%s%N)
check "a 150-line heredoc into a normal file is allowed" 0 $rc
case $t0$t1 in
*N*) echo "note: date has no %N, skipping the heredoc timing check" ;;
*) ms=$(( (t1 - t0) / 1000000 )); echo "     150-line heredoc: $ms ms"; [ "$ms" -lt 1000 ]; check "a 150-line heredoc takes under 1 s" 0 $? ;;
esac
guard_err() { rc=0; err=$(printf '%s' "$1" | sh "$root/hooks/spec-gate.sh" PreToolUse 2>&1 >/dev/null) || rc=$?; }
guard_err "{\"session_id\":\"s1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo $(head -c 102400 /dev/zero | tr '\0' a)\"}}"
check "a 100 KB command is denied" 2 $rc
case $err in *"too long"*) check "the 100 KB denial says too long" 0 0 ;; *) check "the 100 KB denial says too long" 0 1 ;; esac
lines=$(awk 'BEGIN { for (i = 0; i < 2001; i++) printf "x\\n" }')
bash_ "$lines"; check "a command of 2001 lines is denied" 2 $?
bash_ 'echo x\necho y\necho z'; check "a short multi-line command is allowed" 0 $?
mkdir -p "$proj/.ras"; printf '[\n' > "$proj/.ras/risky-paths"
write "src/a.py"; check "override: a bad regex denies every Write" 2 $?
bash_ "ls"; check "override: a bad regex denies every Bash call" 2 $?
printf '^secret/\r\n' > "$proj/.ras/risky-paths"
write "$proj/secret/k.txt"; check "override: a file with CRLF line ends still works" 2 $?
write "src/a.py"; check "override: CRLF does not turn every path risky" 0 $?
chmod 000 "$proj/.ras/risky-paths"
if [ "$(id -u)" = 0 ] || [ -r "$proj/.ras/risky-paths" ]; then echo "note: root, or chmod 000 does not hide the file here, skipping the unreadable risky-paths check"; else
  write "src/a.py"; check "override: an unreadable file denies" 2 $?
fi
chmod 644 "$proj/.ras/risky-paths"
reset
noawk=$(mktemp -d); printf '#!/bin/sh\nexit 127\n' > "$noawk/awk"; chmod +x "$noawk/awk"
(PATH=$noawk:$PATH; write "src/a.py"); check "no working awk denies" 2 $?
for out_ in 'ok' 'x\nok\nok' 'x\nweird' 'x\nrisky a (matches b)\nmore'; do
  printf '#!/bin/sh\ncat >/dev/null\nprintf "%s\\n" "%s"\n' '%b' "$out_" > "$noawk/awk"
  (PATH=$noawk:$PATH; write "src/a.py"); check "awk output that is not two lines with a known verdict denies: $out_" 2 $?
done
rm -rf "$noawk"
$py -c 'import json,sys; e=json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]; h=e["hooks"][0]; sys.exit(0 if all(w in e["matcher"].split("|") for w in ("Edit", "Write", "NotebookEdit", "Bash", "PowerShell")) and h["timeout"] == 30 and h["onFailure"] == "block" else 1)' "$root/hooks/hooks.json"
check "hooks.json: PreToolUse names Bash and PowerShell, timeout 30, onFailure block" 0 $?

# skip spec lets a risky edit through until the next prompt.
reset; say "skip spec" >/dev/null; write "$R"; check "allow after skip spec" 0 $?
say "go on" >/dev/null; write "$R"; check "deny on the next prompt" 2 $?
reset; say "skip spec" >/dev/null; SID=s2; write "$R"; check "skip spec from another session is ignored" 2 $?
SID=s1; write "$R"; check "skip spec still works in its own session" 0 $?
reset; mkdir -p "$S"; : > "$S/spec.skip"; write "$R"; check "an empty skip file counts for no session" 2 $?
reset; SID=; say "skip spec" >/dev/null; write "$R"; check "skip spec with no session id counts for nothing" 2 $?
SID=s1

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
json_ok() { j=$1; shift; printf '%s' "$j" | $py -c 'import json,sys; m=json.load(sys.stdin)["systemMessage"]; sys.exit(0 if all(w in m for w in sys.argv[1:]) else 1)' "$@"; }
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
blocked() { printf '%s' "$out" | $py -c 'import json,sys; j=json.load(sys.stdin); sys.exit(0 if j["decision"] == "block" and all(w in j["reason"] for w in sys.argv[1:]) else 1)' "$@"; }
SID=t1; gp "fix it"; printf 'c\n' >> "$g/a.py"; printf 'n1\nn2\nn3\n' > "$g/new.py"
out=$(gs 'Done. All tests pass.' false); blocked 'touched 2 files. End your reply' 'Decisions'; check "fallback blocks once and counts files" 0 $?
out=$(gs 'Done. All tests pass.' true); check "fallback stays quiet when stop_hook_active is true" "" "$out"
out=$(gs 'Done. All tests pass.' false); blocked 'did not check'; check "fallback asks what was skipped or not checked" 0 $?
out=$(gs 'Done.\\n\\n## Decisions\\n- none' false); check "fallback: a Decisions heading is enough" "" "$out"
out=$(gs 'Done.\\n\\n**Decisions**: none' false); check "fallback: bold Decisions is enough" "" "$out"
out=$(gs 'Done.\\n\\n- Decisions: none' false); check "fallback: a list item Decisions is enough" "" "$out"
out=$(gs 'Done.\\n\\n- **Decisions**: none' false); check "fallback: a bold list item Decisions is enough" "" "$out"
out=$(gs 'Done.\\n\\n* Decisions' false); check "fallback: a star list item Decisions is enough" "" "$out"
out=$(gs 'Done.\\n\\n  1. Decisions' false); blocked 'touched'; check "fallback: a numbered item is not a Decisions heading" 0 $?
out=$(gs 'I made no decisions that matter.' false); blocked 'touched'; check "fallback: the word in prose is not a heading" 0 $?
gp "thanks, what did you change?"; out=$(gs 'A one-line fix.' false); check "fallback: a turn with no new change is quiet" "" "$out"
SID=t2; gp "again"; out=$(gs 'Nothing to report.' false); check "fallback: earlier uncommitted work is not this turn's" "" "$out"
SID=t3; out=$(gs 'No prompt seen.' false); check "fallback: no turn snapshot is quiet" "" "$out"
out=$(CLAUDE_PROJECT_DIR=$proj gate Stop '{"session_id":"t1","last_assistant_message":"Done."}'); check "fallback: not a git repo is quiet" "" "$out"
SID=t4; gp "spec please"; printf 'x\n' >> "$g/a.py"; mkdir -p "$g/specs"; printf '# Spec: t\n\n## Goal\nG.\n' > "$g/specs/current.md"
out=$(gs 'Spec written. Reply approve spec.' false); printf '%s' "$out" | grep -q systemMessage; check "fallback: an approval request shows the spec Decisions, not a block" 0 $?
# Binary files do not count: not a changed one (numstat shows -), not a new one (--eol shows w/-text).
git -C "$g3" init -q && printf 'a\n' > "$g3/a.py" && printf 'x\000y\n' > "$g3/b.dat" && git -C "$g3" add . && git -C "$g3" -c user.name=t -c user.email=t@t commit -qm init
gp3() { CLAUDE_PROJECT_DIR=$g3 gate UserPromptSubmit "{\"session_id\":\"$SID\",\"prompt\":\"go\"}" >/dev/null; }
gs3() { CLAUDE_PROJECT_DIR=$g3 gate Stop "{\"session_id\":\"$SID\",\"stop_hook_active\":false,\"last_assistant_message\":\"Done.\"}"; }
SID=t5; gp3; printf 'x\000z\n' > "$g3/b.dat"; printf 'p\000q\n' > "$g3/new.dat"
out=$(gs3); check "fallback: binary files alone are quiet" "" "$out"
printf 'a\nb\n' > "$g3/a.py"; printf 'n\n' > "$g3/new.py"
out=$(gs3); blocked 'touched 2 files.'; check "fallback: only the text files count" 0 $?
SID=s1

# The folder check: rm or mv of a folder that holds a tracked risky file. Needs git.
mkdir -p "$gf/.github/workflows" "$gf/supabase" "$gf/docs" && : > "$gf/.github/workflows/ci.yml" && : > "$gf/supabase/config.toml" && : > "$gf/docs/a.md" && : > "$gf/notes.md"
gc=$(dirname "$gf")
GIT_CEILING_DIRECTORIES=$gc git -C "$gf" init -q && git -C "$gf" add . && git -C "$gf" -c user.name=t -c user.email=t@example.com commit -qm init
fgate() ( CLAUDE_PROJECT_DIR=$gf GIT_CEILING_DIRECTORIES=$gc; export CLAUDE_PROJECT_DIR GIT_CEILING_DIRECTORIES; "$@" )
fgate bash_ "rm -rf .github"; check "folder check: rm -rf .github denied" 2 $?
fgate bash_ "rm -rf supabase"; check "folder check: rm -rf supabase denied" 2 $?
fgate bash_ "mv supabase old"; check "folder check: mv supabase old denied" 2 $?
fgate bash_ "git rm -r -q .github"; check "folder check: git rm -r -q .github denied" 2 $?
fgate ps_ "Remove-Item -Recurse -Force .github"; check "folder check: PowerShell Remove-Item .github denied" 2 $?
fgate bash_ "rm -rf docs"; check "folder check: rm -rf docs allowed, it holds no risky file" 0 $?
fgate bash_ "mv notes.md supabase/"; check "folder check: mv notes.md supabase/ allowed, a destination is not a candidate" 0 $?
fgate bash_ "rm -rf build"; check "folder check: rm -rf build allowed, nothing in it is tracked" 0 $?

# SessionStart: short context for every source; only startup and clear end the approval.
out=$(gate SessionStart '{"source":"startup"}'); printf '%s' "$out" | $py -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]; t=c["additionalContext"]; sys.exit(0 if c["hookEventName"] == "SessionStart" and "approve spec" in t and "Decisions" in t and "/spec" in t and len(t.split("\n")) < 6 else 1)'; check "SessionStart prints under 6 lines of context as JSON" 0 $?
out=$(gate SessionStart '{"source":"startup"}'); printf '%s' "$out" | grep -q 'did not check'; check "SessionStart asks what was skipped or not checked" 0 $?
reset; mkspec; say "approve spec" >/dev/null; gate SessionStart '{"source":"compact"}' >/dev/null; write "$R"; check "compact keeps the approval" 0 $?
gate SessionStart '{"source":"resume"}' >/dev/null; write "$R"; check "resume keeps the approval" 0 $?
gate SessionStart '{"source":"clear"}' >/dev/null; write "$R"; check "clear ends the approval" 2 $?

# specs/ stays out of git.
reset; write "$proj/specs/current.md"; grep -qxF 'current.md' "$proj/specs/.gitignore" 2>/dev/null && ! grep -qxF '*' "$proj/specs/.gitignore"; check "writing the spec creates specs/.gitignore, without *" 0 $?
reset; mkdir -p "$proj/specs"; gate SessionStart '{"source":"resume"}' >/dev/null; [ -f "$proj/specs/.gitignore" ]; check "session start ignores an existing specs/" 0 $?
g2=$(mktemp -d); git -C "$g2" init -q && mkdir -p "$g2/specs" && printf '*\n' > "$g2/specs/.gitignore" && : > "$g2/specs/current.md" && : > "$g2/specs/2026-01-01-x.md" && : > "$g2/specs/current.url" && : > "$g2/specs/current.html"
[ -z "$(git -C "$g2" status --porcelain)" ]; check "git sees nothing in specs/" 0 $?; rm -rf "$g2"

# The spec page's link file and local page live in specs/: never risky, and they leave the approval alone.
reset; write "$proj/specs/current.url"; check "allow Write of specs/current.url" 0 $?
bash_ "echo https://example.com/a > specs/current.url"; check "Bash: writing specs/current.url allowed" 0 $?
bash_ "node spec-page.mjs build specs/current.md specs/current.html"; check "Bash: building specs/current.html allowed" 0 $?
bash_ "rm -f specs/current.url specs/current.html"; check "Bash: the finalize cleanup of the page files allowed" 0 $?
mkspec; say "approve spec" >/dev/null; printf 'https://example.com/a\n' > "$proj/specs/current.url"; : > "$proj/specs/current.html"
write "$R"; check "the page files do not change the approval" 0 $?

# Stop: one reminder of /scope-review when finalize archived the approved spec.
reset; mkspec; say "approve spec" >/dev/null
bash_ "mv specs/current.md specs/2026-01-02-t.md"; check "archive reminder: finalize's mv is allowed" 0 $?
out=$(stop 'Done.'); check "archive reminder: silent while the spec is still there" "" "$out"
mv "$SP" "$proj/specs/2026-01-02-t.md"
SID=s2; out=$(stop 'Done.'); check "archive reminder: another session stays silent" "" "$out"
[ -f "$S/spec.approved" ]; check "archive reminder: another session keeps the marker" 0 $?
SID=s1; out=$(stop 'Done.'); json_ok "$out" 'Run /scope-review'; check "archive reminder: shown after the archive" 0 $?
out=$(stop 'Done.'); check "archive reminder: shown once" "" "$out"
reset; mkspec; rm "$SP"; out=$(stop 'Done.'); check "archive reminder: silent when nothing was approved" "" "$out"
# A turn that must be blocked is blocked first. The reminder comes on the retry.
SID=t6; printf '# Spec: t\n\n## Goal\nG.\n' > "$g/specs/current.md"; gp "approve spec"; gp "build it"
printf 'z\n' >> "$g/a.py"; rm "$g/specs/current.md"
out=$(gs 'Done.' false); blocked 'touched'; check "archive reminder: the Decisions block comes first" 0 $?
out=$(gs 'Done.' true); json_ok "$out" 'Run /scope-review'; check "archive reminder: shown on the retry" 0 $?
SID=s1

# SessionStart: a spec left unapproved is named, with a fixed sentence.
reset; mkspec; printf '\n## Decisions\n- "quoted" text\n' >> "$SP"
out=$(gate SessionStart '{"source":"startup","session_id":"s1"}'); printf '%s' "$out" | $py -c 'import json,sys; t=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; sys.exit(0 if "already holds a spec" in t and "quoted" not in t else 1)'; check "SessionStart names an unapproved spec, as valid JSON" 0 $?
reset; out=$(gate SessionStart '{"source":"startup","session_id":"s1"}'); printf '%s' "$out" | grep -q 'already holds a spec'; check "SessionStart: no notice without a spec" 1 $?
reset; mkspec; say "approve spec" >/dev/null; out=$(gate SessionStart '{"source":"resume","session_id":"s1"}'); printf '%s' "$out" | grep -q 'already holds a spec'; check "SessionStart: no notice for a spec approved in this session" 1 $?

# SessionStart drops turn snapshots older than a day and keeps fresh ones.
: > "$tmp/ras-turn-old"; touch -t 202001010000 "$tmp/ras-turn-old"; : > "$tmp/ras-turn-new"
gate SessionStart '{"source":"resume","session_id":"s1"}' >/dev/null
[ ! -e "$tmp/ras-turn-old" ] && [ -e "$tmp/ras-turn-new" ]; check "SessionStart removes only old turn snapshots" 0 $?

# ---- Gate Wave 1

# A lock holds under approval and under skip spec. Only the user can change these.
# A tool call as Claude Code makes it: the hook runs only for a tool that the matcher in hooks.json names.
# A tool the matcher leaves out is never checked, so it passes.
matcher=$($py -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["matcher"])' "$root/hooks/hooks.json")
tool_() {
  case "|$matcher|" in *"|$1|"*) ;; *) return 0 ;; esac
  gate PreToolUse "{\"session_id\":\"$SID\",\"tool_name\":\"$1\",\"tool_input\":{\"$2\":\"$3\"}}"
}
ldeny() { bash_ "$1"; check "lock: $1" 2 $?; }
reset; mkspec; say "approve spec" >/dev/null
write "$proj/.claude/spec.approved"; check "lock: Write of .claude/spec.approved under approval" 2 $?
write "$proj/.ras/risky-paths"; check "lock: Write of .ras/risky-paths under approval" 2 $?
write '\u002eclaude/spec.approved'; check "lock: a \\u escape is denied under approval" 2 $?
ldeny "echo x > .claude/spec.approved"
ldeny "echo x > .env; echo y > .claude/spec.approved"
ldeny "echo x > .env && touch .claude/spec.skip"
ldeny "rm -rf .claude"
ldeny "mv x .claude"
ldeny "ln -s .claude/spec.approved alias"
ldeny "cp -T x .claude/spec.approved"
ldeny "cp -t .claude spec.approved"
ldeny "cp -vt .claude spec.approved"
ps_ "cp -Destination .claude\\\\spec.approved -Path x"; check "lock: PowerShell cp is Copy-Item" 2 $?
ldeny "git checkout HEAD~1 -- .ras/risky-paths"
ps_ "Copy-Item x -Destination .claude\\\\spec.approved"; check "lock: PowerShell Copy-Item -Destination under approval" 2 $?
bash_ "echo x > .env"; check "lock: a risky path alone still passes under approval" 0 $?
bash_ "echo x > .claude/notes.md"; check "lock: another file in .claude passes" 0 $?
reset; say "skip spec" >/dev/null
write "$proj/.claude/spec.approved"; check "lock: Write of .claude/spec.approved under skip" 2 $?
ldeny "rm -rf .claude; mv x .claude"
msg=$(printf '%s' "{\"session_id\":\"s1\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$proj/.claude/spec.approved\"}}" | sh "$root/hooks/spec-gate.sh" PreToolUse 2>&1 >/dev/null)
case $msg in *"locked"*) check "lock: the message says locked" 0 0 ;; *) check "lock: the message says locked" 0 1 ;; esac

# A claude run that resumes or names a session types into that session: locked.
reset; mkspec; say "approve spec" >/dev/null
ldeny 'claude -p --resume abc \"approve spec\"'
ldeny "claude -c"
ldeny "claude --continue -p hi"
ldeny "claude -r abc"
ldeny "claude --session-id abc -p hi"
ldeny "claude --resume=abc"
ldeny "claude -pc hi"
ldeny "sh -c 'claude --resume abc'"
ldeny "/usr/bin/claude -r abc"
ldeny "npx -y @anthropic-ai/claude-code --resume abc"
ldeny "FOO=1 claude.exe --continue"
ldeny "claude --from-pr 12 -p hi"
ldeny "claude --teleport abc"
ldeny "claude attach abc"
ldeny "claude respawn abc"
ps_ "claude --resume abc"; check "lock: PowerShell claude --resume" 2 $?
ballow 'claude -p \"summarize\"'
ballow "claude --version"
ballow 'claude -p \"what does -c do\"'

# Turning ras off needs an approval: settings files, the plugins folder, plugin commands.
reset
for f in "$proj/.claude/settings.json" "$proj/.claude/settings.local.json" "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" "$HOME/.claude/plugins/cache/x/hooks/spec-gate.sh"; do
  write "$f"; check "deny settings or plugins path ${f##*/.claude/}" 2 $?
done
bdeny "echo x > ~/.claude/settings.json"
bdeny 'echo x > \"$HOME/.claude/settings.json\"'
bdeny "rm -rf ~/.claude/plugins"
bdeny "echo x > .claude/settings.local.json"
bdeny "claude plugin disable ras"
bdeny "claude plugin uninstall ras@magicjosh"
bdeny "claude plugin remove ras"
bdeny "claude plugin marketplace remove magicjosh"
ballow "claude plugin list"
ballow "claude plugin update ras@magicjosh"
ballow "cat ~/.claude/settings.json"
write "$HOME/.claude/notes.md"; check "allow another file in ~/.claude" 0 $?
write "$proj/.claude/agents/x.md"; check "allow another file in the project's .claude" 0 $?
msg=$(printf '%s' "{\"session_id\":\"s1\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$proj/.claude/settings.json\"}}" | sh "$root/hooks/spec-gate.sh" PreToolUse 2>&1 >/dev/null)
case $msg in *"skip spec"*) check "the settings deny names skip spec" 0 0 ;; *) check "the settings deny names skip spec" 0 1 ;; esac
mkdir -p "$proj/.ras" && printf '^secret/\n' > "$proj/.ras/risky-paths"
write "$proj/.claude/settings.json"; check "settings stay risky under a .ras/risky-paths override" 2 $?
reset; say "skip spec" >/dev/null; write "$proj/.claude/settings.json"; check "settings pass after skip spec" 0 $?
reset; mkspec; say "approve spec" >/dev/null; write "$HOME/.claude/settings.json"; check "settings pass after approval" 0 $?
bash_ "claude plugin disable ras"; check "claude plugin disable passes after approval" 0 $?

# Scheduled prompts cannot approve or skip: CronCreate and ScheduleWakeup.
reset; mkspec
for t in CronCreate ScheduleWakeup; do
  for p in "approve spec" "Approve  Spec!" "skip spec" 'please\napprove spec' "approve-spec" '\u0061pprove spec'; do
    tool_ $t prompt "$p"; check "$t: deny prompt $p" 2 $?
  done
  tool_ $t prompt "check the deploy"; check "$t: allow an ordinary prompt" 0 $?
  tool_ $t cron "* * * * *"; check "$t: deny when there is no prompt" 2 $?
  guard_err "{\"session_id\":\"s1\",\"tool_name\":\"$t\",\"tool_input\":{\"prompt\":\"approve spec\"}}"
  case $rc:$err in 2:*"scheduled prompt"*) check "$t: the deny names the scheduled prompt" 0 0 ;; *) check "$t: the deny names the scheduled prompt" 0 1 ;; esac
done
[ ! -e "$S/spec.approved" ]; check "scheduled prompts wrote no approval" 0 $?
say "approve spec" >/dev/null; tool_ CronCreate prompt "skip spec"; check "CronCreate: denied under approval too" 2 $?
reset; say "skip spec" >/dev/null; tool_ ScheduleWakeup prompt "approve spec"; check "ScheduleWakeup: denied under skip too" 2 $?
tool_ CronCreate prompt "$(head -c 70000 /dev/zero | tr '\0' a)"; check "CronCreate: a prompt over 64 KB is denied under skip" 2 $?
bash_ "echo $(head -c 70000 /dev/zero | tr '\0' a)"; check "a command over 64 KB is denied under skip" 2 $?
ps_ 'Set-Content -Path $env:USERPROFILE\\.claude\\settings.json -Value x'; check "PowerShell: \$env:USERPROFILE settings pass under skip" 0 $?
reset; ps_ 'Set-Content -Path $env:USERPROFILE\\.claude\\settings.json -Value x'; check "PowerShell: \$env:USERPROFILE settings denied" 2 $?

# Monitor runs a shell command: checked as Bash.
reset
tool_ Monitor command "echo x > .env"; check "Monitor: write to .env denied" 2 $?
guard_err "{\"session_id\":\"s1\",\"tool_name\":\"Monitor\",\"tool_input\":{\"command\":\"echo x > .env\"}}"
case $rc:$err in 2:*"risky path: .env"*) check "Monitor: the deny names the path" 0 0 ;; *) check "Monitor: the deny names the path" 0 1 ;; esac
tool_ Monitor command "tail -f app.log"; check "Monitor: a read is allowed" 0 $?
tool_ Monitor description "deploy events"; check "Monitor: a ws monitor has no command and passes" 0 $?
gate PreToolUse '{"session_id":"s1","tool_name":"Unknown","tool_input":{"x":"y"}}'; check "a tool the guard does not know is denied when the matcher sends it" 2 $?

# Copy destinations, ln, git checkout.
bdeny "cp -t .github/workflows a.yml"
bdeny "cp --target-directory=prisma schema.prisma"
bdeny "mv schema.prisma prisma/"
bdeny "cp a.sql b.sql out"
bdeny "cp -t backup .env"
bdeny "ln -s .env alias"
bdeny "git checkout HEAD~1 -- .env"
bdeny "git checkout main .env"
bdeny "git checkout -- .github/workflows/ci.yml"
ballow "cp -T backup.sql out.txt"
ballow "install -m 644 a.sql out.txt"
ballow "mv a.txt b.txt docs/"
ballow "git checkout -b fix origin/auth"
ballow "git checkout -"
pdeny "Copy-Item a.txt -Destination .env"
pdeny "Copy-Item a.txt -fo .env"
winj "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$Wj\\\\.claude\\\\settings.json\"}}"; check "deny a Windows path to the project's settings" 2 $?
(HOME=$Wg; export HOME; winj "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$Wj\\\\.claude\\\\plugins\\\\x.sh\"}}"); check "deny a Windows path under a Git Bash HOME" 2 $?
pallow "Copy-Item .env -Destination backup.txt"
pallow "Copy-Item -Path src -Destination out -Exclude .env"

# One approval line per session. Another session's approval, start or prompt leaves it alone.
nlines() { wc -l < "$S/spec.approved" | tr -d ' '; }
reset; mkspec; say "approve spec" >/dev/null
SID=s2; say "approve spec" >/dev/null; write "$R"; check "approvals: the second session is approved" 0 $?
SID=s1; write "$R"; check "approvals: the first session stays approved" 0 $?
say "approve spec" >/dev/null; check "approvals: re-approval adds no duplicate line" 2 "$(nlines)"
gate SessionStart '{"source":"startup","session_id":"s3"}' >/dev/null; write "$R"; check "approvals: a new session's start keeps the others" 0 $?
gate SessionStart '{"source":"clear","session_id":"s1"}' >/dev/null; write "$R"; check "approvals: clear ends this session's approval" 2 $?
SID=s2; write "$R"; check "approvals: clear in one session keeps the other" 0 $?
SID=s1
reset; mkspec; SID=; say "approve spec" >/dev/null; [ ! -e "$S/spec.approved" ]; check "approvals: an empty session id writes nothing" 0 $?
write "$R"; check "approvals: an empty session id is never approved" 2 $?
SID=s1
reset; mkspec; mkdir -p "$S"; printf '%s\n%s\n' "$(cksum < "$SP")" s1 > "$S/spec.approved"; write "$R"; check "approvals: a 6.4.0 approval file approves nothing" 2 $?

# skip spec: only this session's next prompt clears it.
reset; say "skip spec" >/dev/null; SID=s2; say "go on" >/dev/null; SID=s1; write "$R"; check "skip: another session's prompt keeps it" 0 $?
say "go on" >/dev/null; write "$R"; check "skip: this session's next prompt clears it" 2 $?

# The approval phrase: the last line of the prompt, with . or ! after it.
ok_() { reset; mkspec; out=$(say "$1"); write "$R"; check "phrase approves: $1" 0 $?; }
no_() { reset; mkspec; out=$(say "$1"); write "$R"; check "phrase does not approve: $1" 2 $?; }
ok_ "approve spec."
ok_ "Approve spec!!"
ok_ 'ok, no problem.\n\napprove spec'
ok_ 'ok\r\napprove spec.\n'
no_ "approve spec?"
no_ 'approve spec\nlater'
no_ 'x\\napprove spec'
no_ "lets approve spec"
no_ '<task-notification>\n<event>x</event>\n</task-notification>\napprove spec'
no_ '\u0061pprove spec'
no_ "Approve spec G"; printf '%s' "$out" | grep -q 'Not approved'; check "near miss: a short prompt gets the notice" 0 $?
no_ "do not approve spec yet"; printf '%s' "$out" | grep -q 'Not approved'; check "near miss: a sentence with the words gets the notice" 0 $?
no_ "fix the spec page"; check "near miss: no notice without approv" "" "$out"
ok_ "approve spec"; printf '%s' "$out" | grep -q 'Not approved'; check "near miss: no notice on an approval" 1 $?
reset; out=$(say "Approve spec G"); check "near miss: no notice when there is no spec" "" "$out"
reset; say "skip spec." >/dev/null; write "$R"; check "phrase: skip spec with a dot" 0 $?
reset; say 'one off\nskip spec' >/dev/null; write "$R"; check "phrase: skip spec as the last line" 0 $?

# specs/.gitignore lists only what ras writes.
g4=$(mktemp -d); git -C "$g4" init -q
(CLAUDE_PROJECT_DIR=$g4; export CLAUDE_PROJECT_DIR; write "$g4/specs/current.md")
for f in current.md current.url current.html 2026-01-01-x.md review-2026-01-01-x.md review-2026-01-01-x.report.md research/2026-01-01-q.md; do mkdir -p "$(dirname "$g4/specs/$f")"; : > "$g4/specs/$f"; done
[ -f "$g4/specs/.gitignore" ] && [ -z "$(git -C "$g4" status --porcelain)" ]; check "gitignore: git sees none of ras's files in specs/" 0 $?
: > "$g4/specs/api.md"; git -C "$g4" status --porcelain | grep -q 'specs/'; check "gitignore: git sees a repo's own file in specs/" 0 $?
rm -rf "$g4"

# A bad line in .ras/risky-paths is named.
reset; mkdir -p "$proj/.ras"; printf '# mine\n^ok/\n[\n' > "$proj/.ras/risky-paths"
guard_err "{\"session_id\":\"s1\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/a.py\"}}"
case $rc:$err in 2:*"line 3"*) check "override: a bad pattern is named by its line" 0 0 ;; *) check "override: a bad pattern is named by its line" 0 1 ;; esac
reset

$py -c 'import json,sys; m=json.load(open(sys.argv[1]))["hooks"]["PreToolUse"][0]["matcher"].split("|"); sys.exit(0 if all(w in m for w in ("Monitor", "CronCreate", "ScheduleWakeup")) else 1)' "$root/hooks/hooks.json"
check "hooks.json: PreToolUse names Monitor, CronCreate and ScheduleWakeup" 0 $?

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
