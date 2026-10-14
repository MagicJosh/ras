#!/bin/sh
# spec-gate (ras 6): edits are allowed by default. A risky path (CI, env files, migrations, SQL,
# infra, auth) is denied until the user approves specs/current.md in this session.
# Risky paths: the defaults in guard.awk, or the ERE lines of .ras/risky-paths, which replace them.
# .ras/ (except .ras/handoffs/) and .claude/spec.* always count, so the agent cannot loosen the list or forge a state file.
# The spec lives outside .claude/ because Claude Code always prompts for writes to .claude/.
# Approval state stays in .claude/, so the agent cannot forge it without a prompt.
# A guard rail for the agent, not a sandbox.
# PreToolUse needs sh, awk and cksum (hooks/guard.awk does the checking), and git for the folder check of rm and mv. The other events also use grep, sed, tr and git.
# Usage: spec-gate.sh <hook event>, JSON on stdin.
set -eu
event=${1:-}
code=1
[ "$event" = PreToolUse ] && code=2
if [ "$event" = Stop ]; then trap 'exit 0' EXIT; fi # Stop only informs, so it fails open
reason='The ras hook could not check this call. Retry once. If it keeps failing, tell the user.'
die() { trap - EXIT; echo "ras: ${1:+$1. }$reason" >&2; exit "$code"; }
deny() { trap - EXIT; echo "ras: risky path: $1. Ask the user your open questions first, then write specs/current.md with the spec skill and ask the user to reply with exactly: approve spec. Do not write the file with Bash or PowerShell." >&2; exit 2; }
allow() { trap - EXIT; exit 0; }
trap 'die "internal error"' EXIT # fail closed on any unexpected error

proj=${CLAUDE_PROJECT_DIR:-}
[ -n "$proj" ] || die "CLAUDE_PROJECT_DIR is not set"
d=$proj/.claude
spec=$proj/specs/current.md
nl='
'
# Create .claude/ and its .gitignore on the first state write.
init() { mkdir -p "$d"; [ -f "$d/.gitignore" ] || printf 'spec.approved\nspec.skip\n' > "$d/.gitignore"; }
# Keep specs/ out of git: a specs/.gitignore with * ignores the folder and itself. Best effort.
ign() { { mkdir -p "$proj/specs" && { [ -f "$proj/specs/.gitignore" ] || printf '*\n' > "$proj/specs/.gitignore"; }; } 2>/dev/null || :; }
# True when specs/current.md is approved, unchanged since, and approved in this session.
# Archiving the spec ends the approval.
approved() {
  [ -f "$spec" ] || { rm -f "$d/spec.approved"; return 1; }
  [ -f "$d/spec.approved" ] || return 1
  a= b=
  { IFS= read -r a || :; IFS= read -r b || :; } < "$d/spec.approved"
  [ "$a" = "$(cksum < "$spec")" ] && [ "$b" = "$sid" ]
}

# True when this session said "skip spec": the file holds its session id, which must not be empty.
skipped() {
  [ -n "$sid" ] && [ -f "$d/spec.skip" ] || return 1
  s=
  IFS= read -r s < "$d/spec.skip" || :
  [ "$s" = "$sid" ]
}

if [ "$event" = PreToolUse ]; then
  # One awk process reads the hook JSON and prints the session id, then a verdict (guard.awk).
  here=${0%/*}
  [ "$here" != "$0" ] || here=${0%\\*} # a Windows path has backslashes
  [ "$here" != "$0" ] || here=.
  ovr=
  if [ -e "$proj/.ras/risky-paths" ]; then ovr=$proj/.ras/risky-paths; fi
  out=$(LC_ALL=C RAS_RISKY=$ovr awk -f "$here/guard.awk") || die "the awk guard failed; if .ras/risky-paths exists, check its patterns"
  case $out in *"$nl"*) ;; *) die "unexpected guard output" ;; esac
  sid=${out%%"$nl"*}
  v=${out#*"$nl"}
  case $v in
  *"$nl"*) die "unexpected guard output" ;;
  ok) allow ;;
  specs) ign; allow ;;
  "risky "* | "cannot "*) ;;
  *) die "unexpected guard output" ;;
  esac
  if skipped || approved; then allow; fi
  case $v in cannot*) trap - EXIT; echo "ras: ${v#cannot }" >&2; exit 2 ;; esac
  deny "${v#risky }"
fi

input=$(cat)
# First string value of a JSON key. An escaped \" inside a value cannot match a key.
field() { printf '%s' "$input" | grep -oE '"('"$1"')"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' |
  sed -n '1{s/^"[a-z_]*"[[:space:]]*:[[:space:]]*"//;s/"$//;p;}'; }
sid=$(field session_id)

# Changed text files, one line each: git numstat for tracked files, git --eol for untracked ones.
# Binary files are left out: numstat shows them as "-", --eol as w/-text.
snap() {
  git -C "$proj" diff HEAD --numstat -- . 2>/dev/null | grep -v '^-' || :
  git -C "$proj" ls-files -o --exclude-standard --eol 2>/dev/null | grep -v 'w/-text' || :
}
# The file that holds this turn's starting snapshot. Empty when there is no session id.
turn() { t=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-'); [ -z "$t" ] || echo "${TMPDIR:-/tmp}/ras-turn-$t"; }

case $event in
SessionStart)
  [ -d "$proj/specs" ] && ign
  # A new or cleared session starts unapproved. Resume and compact keep the approval.
  case $(field source) in startup | clear | '') rm -f "$d/spec.approved" "$d/spec.skip" ;; esac
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ras plugin. Work normally and keep diffs small.\nThe user can run /spec (or /ras:spec) for a plan: the spec skill asks the open questions, writes specs/current.md and waits for `approve spec`.\nRisky paths (CI, env files, migrations, SQL, infra, auth) are locked until a spec is approved. If a hook denies an edit, load spec.\nFor a failure with an unknown cause, load diagnose. When a change touches auth, permissions, secrets, payments, personal data or deletes, load security-check.\nEnd every reply that changed code with a short Decisions section: choices you made that the user did not specify, and what you skipped or did not check, or none."}}' ;;
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
    printf '%s\n' "$sid" > "$d/spec.skip" ;;
  esac
  # Remember what was already changed, so Stop can tell what this turn changed.
  t=$(turn)
  if [ -n "$t" ]; then
    { git -C "$proj" rev-parse --is-inside-work-tree >/dev/null && snap > "$t"; } 2>/dev/null || :
  fi ;;
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
  printf '%s' "$last" | grep -qE '(^|\\n)[[:space:]]*([-*+][[:space:]]+)?(#+[[:space:]]*|\*\*)?decisions' && allow
  t=$(turn)
  [ -n "$t" ] && [ -f "$t" ] || allow
  git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1 || allow
  n=$(snap | grep -vxFc -f "$t" || :)
  [ "${n:-0}" -gt 0 ] || allow
  trap - EXIT
  printf '{"decision":"block","reason":"ras: this turn touched %s files. End your reply with a short Decisions section: the choices you made that the user did not specify, and what you skipped or did not check, or none."}\n' "$n"
  exit 0 ;;
*)
  die "unknown event '$event'" ;;
esac
allow
