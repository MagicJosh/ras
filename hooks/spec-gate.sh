#!/bin/sh
# spec-gate: deny file edits until the user approves specs/current.md.
# The spec lives outside .claude/ because Claude Code always prompts for writes to .claude/.
# Approval state stays in .claude/, so the agent cannot forge it without a prompt.
# A guard rail for the agent, not a sandbox: Bash can still write files.
# POSIX sh plus grep, sed, tr, cksum. Usage: spec-gate.sh <hook event>, JSON on stdin.
set -eu
event=${1:-}
code=1
[ "$event" = PreToolUse ] && code=2
if [ "$event" = Stop ]; then trap 'exit 0' EXIT; fi # Stop only informs, so it fails open
reason='Write specs/current.md (skill: spec) and ask the user to reply with exactly: approve spec. Do not write project files with Bash or PowerShell.'
die() { trap - EXIT; echo "${1:+spec-gate: $1. }$reason" >&2; exit "$code"; }
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
# Create .claude/ and its .gitignore on the first state write.
init() { mkdir -p "$d"; [ -f "$d/.gitignore" ] || printf 'spec.approved\nspec.skip\n' > "$d/.gitignore"; }
# Keep specs/ out of git: a specs/.gitignore with * ignores the folder and itself. Best effort.
ign() { { mkdir -p "$proj/specs" && { [ -f "$proj/specs/.gitignore" ] || printf '*\n' > "$proj/specs/.gitignore"; }; } 2>/dev/null || :; }

case $event in
SessionStart)
  [ -d "$proj/specs" ] && ign
  # A new or cleared session starts unapproved. Resume and compact keep the approval.
  case $(field source) in startup | clear | '') rm -f "$d/spec.approved" "$d/spec.skip" ;; esac
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ras plugin: before you change a project file, load the spec skill and write specs/current.md. A hook denies edits until the user replies `approve spec`. The user can reply `skip spec` to skip the gate until the next prompt, or `ask me` to get questions about the spec. For a failure with an unknown cause, load diagnose before spec."}}' ;;
UserPromptSubmit)
  if printf '%s' "$input" | grep -qE '"agent_id"[[:space:]]*:'; then allow; fi
  p=$(field prompt | tr 'A-Z' 'a-z' | sed -E 's/^(\\[nrt]|[[:space:]])+//; s/(\\[nrt]|[[:space:]])+$//')
  [ "$p" = "skip spec" ] || rm -f "$d/spec.skip"
  case $p in
  "approve spec")
    if [ -f "$spec" ]; then
      init
      cksum < "$spec" > "$d/spec.approved"
      echo "Approved spec: $(sed -n '/^## Goal/,/^## /{/^#/!{/./p;};}' "$spec" | sed -n 1p)"
    else
      echo "No specs/current.md to approve."
    fi ;;
  "skip spec")
    init
    : > "$d/spec.skip" ;;
  esac ;;
PreToolUse)
  p=$(field 'file_path|notebook_path')
  [ -n "$p" ] || die "no file_path in the tool input"
  p=$(norm "$p")
  b=$(norm "$proj")
  case $p in /*|[a-z]:*) ;; *) p=$b/$p ;; esac
  if [ "$p" = "$b/specs/current.md" ]; then ign; allow; fi
  if [ -e "$d/spec.skip" ]; then allow; fi
  case $p/ in "$b"/*) ;; *) allow ;; esac
  if [ -f "$spec" ] && [ -f "$d/spec.approved" ]; then
    cur=$(cksum < "$spec")
    [ -n "$cur" ] && [ "$cur" = "$(cat "$d/spec.approved")" ] && allow
  fi
  die "" ;;
Stop)
  # When the agent asks for approval, show the user the spec's Decisions section.
  [ -f "$spec" ] || allow
  if [ -f "$d/spec.approved" ] && [ "$(cksum < "$spec")" = "$(cat "$d/spec.approved")" ]; then allow; fi
  field last_assistant_message | tr 'A-Z' 'a-z' | grep -q 'approve spec' || allow
  dec=$(sed -n '/^## Decisions/,/^## /{/^## /!p;}' "$spec" | sed '/^[[:space:]]*$/d')
  [ -n "$dec" ] || dec='None written. Ask the agent which choices the spec makes before you approve.'
  msg=$(printf 'Decisions in specs/current.md:\n%s' "$dec" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\t' ' ' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
  trap - EXIT
  printf '{"systemMessage":"%s"}\n' "$msg"
  exit 0 ;;
*)
  die "unknown event '$event'" ;;
esac
allow
