#!/bin/sh
# spec-gate (ras 6): edits are allowed by default. A risky path (CI, env files, migrations, SQL,
# infra, auth) is denied until the user approves specs/current.md in this session.
# Risky paths: the defaults below, or the ERE lines of .ras/risky-paths, which replace them.
# The spec lives outside .claude/ because Claude Code always prompts for writes to .claude/.
# Approval state stays in .claude/, so the agent cannot forge it without a prompt.
# A guard rail for the agent, not a sandbox.
# POSIX sh plus grep, sed, tr, cksum, awk, git. Usage: spec-gate.sh <hook event>, JSON on stdin.
set -eu
event=${1:-}
code=1
[ "$event" = PreToolUse ] && code=2
if [ "$event" = Stop ]; then trap 'exit 0' EXIT; fi # Stop only informs, so it fails open
reason='The ras hook could not check this call. Retry once. If it keeps failing, tell the user.'
die() { trap - EXIT; echo "ras: ${1:+$1. }$reason" >&2; exit "$code"; }
deny() { trap - EXIT; echo "ras: risky path: $1. Ask the user your open questions first, then write specs/current.md with the spec skill and ask the user to reply with exactly: approve spec. Do not write the file with Bash." >&2; exit 2; }
allow() { trap - EXIT; exit 0; }
trap 'die "internal error"' EXIT # fail closed on any unexpected error

proj=${CLAUDE_PROJECT_DIR:-}
[ -n "$proj" ] || die "CLAUDE_PROJECT_DIR is not set"
d=$proj/.claude
spec=$proj/specs/current.md
input=$(cat)

# First string value of a JSON key. An escaped \" inside a value cannot match a key.
field() { printf '%s' "$input" | grep -oE '"('"$1"')"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' |
  sed -n '1{s/^"[a-z_]*"[[:space:]]*:[[:space:]]*"//;s/"$//;p;}'; }
# Lowercase, \ to /, one slash, /c/x to c:/x, no trailing slash.
norm() { printf '%s' "$1" | tr 'A-Z\\' 'a-z/' | sed -E 's,//+,/,g; s,^/([a-z])/,\1:/,; s,/$,,'; }
b=$(norm "$proj")
sid=$(field session_id)
# Create .claude/ and its .gitignore on the first state write.
init() { mkdir -p "$d"; [ -f "$d/.gitignore" ] || printf 'spec.approved\nspec.skip\n' > "$d/.gitignore"; }
# Keep specs/ out of git: a specs/.gitignore with * ignores the folder and itself. Best effort.
ign() { { mkdir -p "$proj/specs" && { [ -f "$proj/specs/.gitignore" ] || printf '*\n' > "$proj/specs/.gitignore"; }; } 2>/dev/null || :; }
# True when specs/current.md is approved, unchanged since, and approved in this session.
# Archiving the spec ends the approval.
approved() {
  [ -f "$spec" ] || { rm -f "$d/spec.approved"; return 1; }
  [ -f "$d/spec.approved" ] &&
    [ "$(sed -n 1p "$d/spec.approved")" = "$(cksum < "$spec")" ] &&
    [ "$(sed -n 2p "$d/spec.approved")" = "$sid" ]
}

risky_defaults='(^|/)\.github/workflows(/|$)
(^|/)\.gitlab-ci\.yml$
(^|/)\.env(\.[^/]*)?$
(^|/)\.(husky|devcontainer)(/|$)
(^|/)\.mcp\.json$
(^|/)migrations?(/|$)
\.sql$
(^|/)dockerfile[^/]*$
(^|/)docker-compose[^/]*$
\.tf(vars)?$
(^|/)prisma/schema\.prisma$
(^|/)supabase(/|$)
(^|/)(auth|permissions)(/|$)
(^|/)(auth|permissions|policies)\.[^/]*$'
# Print the pattern that makes the repo-relative, lowercase path $1 risky. Print nothing if none does.
# .ras/ always counts, so the agent cannot loosen the list without an approved spec.
risky() {
  case $1 in .ras/* | */.ras/*) echo '.ras/'; return 0 ;; esac
  if [ -f "$proj/.ras/risky-paths" ]; then
    pats=$(grep -vE '^[[:space:]]*(#|$)' "$proj/.ras/risky-paths" || :) # blank lines would match everything
  else
    printf '%s\n' "$1" | grep -qiE '(^|/)\.env\.(example|sample|template|dist)$' && return 0
    pats=$risky_defaults
  fi
  printf '%s\n' "$pats" | while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    if printf '%s\n' "$1" | grep -qiE -e "$pat"; then echo "$pat"; break; fi
  done || :
}
# Bash guard rail, not a sandbox: a write-ish token (redirect, tee, sed -i, cp, mv, rm, truncate,
# git apply, patch, dd) plus a risky path in the same command. It misses variables, scripts and
# anything built at run time. Print "word (matches pattern)" for the first risky path word.
bashhit() {
  c=$(field command | tr 'A-Z' 'a-z' | sed -E 's,\\n, ,g; s,[0-9&]*>>?[[:space:]]*/dev/null, ,g; s,[0-9]*>&[0-9-], ,g')
  printf '%s\n' "$c" | grep -qE '>|(^|[^a-z0-9_.-])(tee|cp|mv|rm|truncate|dd|patch)([^a-z0-9_.-]|$)|sed[[:space:]]+(-[a-z]+[[:space:]]+)*(-[a-z]*i|--in-place)|git[[:space:]]+apply' || return 0
  printf '%s\n' "$c" | tr -s ' \t;&|()<>=`\047\042\134' '\n' | while IFS= read -r w; do
    w=$(norm "$w")
    case $w in "$b"/*) w=${w#"$b"/} ;; /* | '~'* | specs/* | '') continue ;; esac
    h=$(risky "$w")
    if [ -n "$h" ]; then echo "$w (matches $h)"; break; fi
  done || :
}
# Changed files, one "added<TAB>deleted<TAB>path" line each (git numstat). Untracked files count their lines.
# ponytail: the first 200 untracked files only. Raise it if a turn creates more.
snap() {
  git -C "$proj" diff HEAD --numstat -- . 2>/dev/null || :
  git -C "$proj" ls-files -o --exclude-standard 2>/dev/null | head -200 | while IFS= read -r f; do
    printf '%s\t0\t%s\n' "$(wc -l < "$proj/$f" 2>/dev/null | tr -d ' ' || echo 0)" "$f"
  done || :
}
# The file that holds this turn's starting snapshot. Empty when there is no session id.
turn() { t=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-'); [ -z "$t" ] || echo "${TMPDIR:-/tmp}/ras-turn-$t"; }

case $event in
SessionStart)
  [ -d "$proj/specs" ] && ign
  # A new or cleared session starts unapproved. Resume and compact keep the approval.
  case $(field source) in startup | clear | '') rm -f "$d/spec.approved" "$d/spec.skip" ;; esac
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ras plugin. Work normally and keep diffs small.\nThe user can run /spec (or /ras:spec) for a plan: the spec skill asks the open questions, writes specs/current.md and waits for `approve spec`.\nRisky paths (CI, env files, migrations, SQL, infra, auth) are locked until a spec is approved. If a hook denies an edit, load spec.\nFor a failure with an unknown cause, load diagnose. When a change touches auth, permissions, secrets, payments, personal data or deletes, load security-check.\nEnd every reply that changed code with a short Decisions section: choices you made that the user did not specify, or none."}}' ;;
UserPromptSubmit)
  if printf '%s' "$input" | grep -qE '"agent_id"[[:space:]]*:'; then allow; fi
  p=$(field prompt | tr 'A-Z' 'a-z' | sed -E 's/^(\\[nrt]|[[:space:]])+//; s/(\\[nrt]|[[:space:]])+$//')
  [ "$p" = "skip spec" ] || rm -f "$d/spec.skip"
  case $p in
  "approve spec")
    if [ -f "$spec" ]; then
      init
      printf '%s\n%s\n' "$(cksum < "$spec")" "$sid" > "$d/spec.approved"
      echo "Approved spec: $(sed -n '/^## Goal/,/^## /{/^#/!{/./p;};}' "$spec" | sed -n 1p)"
    else
      echo "No specs/current.md to approve."
    fi ;;
  "skip spec")
    init
    : > "$d/spec.skip" ;;
  esac
  # Remember what was already changed, so Stop can tell what this turn changed.
  t=$(turn)
  if [ -n "$t" ]; then
    { git -C "$proj" rev-parse --is-inside-work-tree >/dev/null && snap > "$t"; } 2>/dev/null || :
  fi ;;
PreToolUse)
  if [ "$(field tool_name)" = Bash ]; then
    hit=$(bashhit)
  else
    p=$(field 'file_path|notebook_path')
    [ -n "$p" ] || die "no file_path in the tool input"
    p=$(norm "$p")
    case $p in /*|[a-z]:*) ;; *) p=$b/$p ;; esac
    case $p/ in "$b"/*) ;; *) allow ;; esac
    rel=${p#"$b"/}
    case $rel in specs/*) ign; allow ;; esac
    h=$(risky "$rel")
    hit=${h:+$rel (matches $h)}
  fi
  [ -n "$hit" ] || allow
  if [ -e "$d/spec.skip" ]; then allow; fi
  if approved; then allow; fi
  deny "$hit" ;;
Stop)
  last=$(field last_assistant_message | tr 'A-Z' 'a-z')
  # When the agent asks for approval, show the user the spec's Decisions section.
  if [ -f "$spec" ] && ! approved && printf '%s' "$last" | grep -q 'approve spec'; then
    dec=$(sed -n '/^## Decisions/,/^## /{/^## /!p;}' "$spec" | sed '/^[[:space:]]*$/d')
    [ -n "$dec" ] || dec='None written. Ask the agent which choices the spec makes before you approve.'
    msg=$(printf 'Decisions in specs/current.md:\n%s' "$dec" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\t' ' ' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
    trap - EXIT
    printf '{"systemMessage":"%s"}\n' "$msg"
    exit 0
  fi
  # Fallback: the turn changed files and the reply has no Decisions heading. Ask once.
  if printf '%s' "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then allow; fi
  printf '%s' "$last" | grep -qE '(^|\\n)[[:space:]]*(#+[[:space:]]*|\*\*)?decisions' && allow
  t=$(turn)
  [ -n "$t" ] && [ -f "$t" ] || allow
  git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1 || allow
  set -- $(snap | grep -vxFf "$t" | awk -F'\t' '{ s += $1 + $2 } END { print NR + 0, s + 0 }' || :)
  [ "${1:-0}" -gt 0 ] || allow
  trap - EXIT
  printf '{"decision":"block","reason":"ras: this turn touched %s files, %s lines. End your reply with a short Decisions section: the choices you made that the user did not specify, or none."}\n' "$1" "${2:-0}"
  exit 0 ;;
*)
  die "unknown event '$event'" ;;
esac
allow
