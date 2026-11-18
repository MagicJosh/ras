#!/bin/sh
# spec-gate (ras 6): edits are allowed by default. A risky path (CI, env files, migrations, SQL,
# infra, auth) is denied until the user approves specs/current.md in this session.
# Risky paths: the defaults in guard.awk, or the ERE lines of .ras/risky-paths, which replace them.
# Settings files and the plugins folder are risky in every repo and in ~, because they can turn ras off.
# Locked for the agent whatever was approved: .ras/ (except .ras/handoffs/), .claude/spec.*, the .claude folder,
# a claude run that resumes a session, and a scheduled prompt that reads approve spec or skip spec.
# So the agent cannot loosen the list, forge a state file or type the approval for the user.
# The spec lives outside .claude/ because Claude Code always prompts for writes to .claude/.
# Approval state stays in .claude/: one line per session in spec.approved, "<cksum of the spec> <session id>".
# A guard rail for the agent, not a sandbox.
# PreToolUse needs sh, awk and cksum (hooks/guard.awk does the checking), and git for the folder check of rm and mv.
# The other events read their JSON with hooks/event.awk, and also use grep, sed, tr, find and git.
# Usage: spec-gate.sh <hook event>, JSON on stdin.
set -eu
event=${1:-}
code=1
[ "$event" = PreToolUse ] && code=2
if [ "$event" = Stop ]; then trap 'exit 0' EXIT; fi # Stop only informs, so it fails open
reason='The ras hook could not check this call. Retry once. If it keeps failing, tell the user.'
die() { trap - EXIT; echo "ras: ${1:+$1. }$reason" >&2; exit "$code"; }
deny() {
  trap - EXIT
  case $1 in
  *"can turn ras off"*) echo "ras: risky path: $1. Only the user unlocks this. Ask the user to reply with exactly: skip spec, which lets edits through until their next prompt, or write specs/current.md with the spec skill and ask for: approve spec. Do not write the file with Bash or PowerShell." >&2 ;;
  *) echo "ras: risky path: $1. Ask the user your open questions first, then write specs/current.md with the spec skill and ask the user to reply with exactly: approve spec. Do not write the file with Bash or PowerShell." >&2 ;;
  esac
  exit 2
}
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
# Keep what ras writes in specs/ out of git, and leave a repo's own files there visible. Best effort.
# An existing specs/.gitignore stays as it is.
ign() {
  { mkdir -p "$proj/specs" && { [ -f "$proj/specs/.gitignore" ] || printf '%s\n' '# ras: the files ras writes here. Your own files in specs/ stay visible to git.' \
    .gitignore current.md current.url current.html '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' 'review-*' research/ > "$proj/specs/.gitignore"; }; } 2>/dev/null || :
}

# The approval file, read and written only by the next four functions and the approve spec branch.
# One line per session: "<cksum of the spec> <session id>". A session without an id is never approved.
# True when this session approved specs/current.md and the spec is unchanged since.
# Archiving the spec ends the approval.
approved() {
  [ -n "$sid" ] || return 1
  [ -f "$spec" ] || { unmark; return 1; }
  [ -f "$d/spec.approved" ] || return 1
  grep -qxF -- "$(cksum < "$spec") $sid" "$d/spec.approved"
}
# True when the file has a line for this session, whatever the spec looks like now.
marked() {
  [ -n "$sid" ] && [ -f "$d/spec.approved" ] || return 1
  while IFS= read -r a; do
    b=${a%" $sid"}
    [ "$b" != "$a" ] || continue
    case $b in *[!0-9\ ]* | '') ;; *) return 0 ;; esac
  done < "$d/spec.approved"
  return 1
}
# Rewrite the file without this session's line. With $1, a cksum, also drop the lines for another spec text.
prune() {
  [ -f "$d/spec.approved" ] || return 0
  kept=
  while IFS= read -r a; do
    case $a in *" $sid") continue ;; esac
    [ -z "${1:-}" ] || case $a in "$1 "*) ;; *) continue ;; esac
    kept=$kept$a$nl
  done < "$d/spec.approved"
  if [ -n "$kept" ]; then printf '%s' "$kept" > "$d/spec.approved"; else rm -f "$d/spec.approved"; fi
}
# End this session's approval. Without a session id nobody can tell the lines apart: drop the file.
unmark() { if [ -n "$sid" ]; then prune; else rm -f "$d/spec.approved"; fi; }
# True when this session approved a spec and the spec is gone: finalize archived it.
archived() { [ ! -f "$spec" ] && marked; }

# True when this session said "skip spec": the file holds its session id, which must not be empty.
skipped() {
  [ -n "$sid" ] && [ -f "$d/spec.skip" ] || return 1
  s=
  IFS= read -r s < "$d/spec.skip" || :
  [ "$s" = "$sid" ]
}

here=${0%/*}
[ "$here" != "$0" ] || here=${0%\\*} # a Windows path has backslashes
[ "$here" != "$0" ] || here=.

if [ "$event" = PreToolUse ]; then
  # One awk process reads the hook JSON and prints the session id, then a verdict (guard.awk).
  ovr=
  if [ -e "$proj/.ras/risky-paths" ]; then ovr=$proj/.ras/risky-paths; fi
  # The line of .ras/risky-paths that awk cannot compile, as "line N". Runs only after the guard failed.
  badline() {
    n=0
    while IFS= read -r l || [ -n "$l" ]; do
      n=$((n + 1))
      printf '%s\n' "$l" | LC_ALL=C awk '{ gsub(/\r/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); if ($0 == "" || substr($0, 1, 1) == "#") exit; x = ("" ~ tolower($0)) }' 2>/dev/null || { printf 'line %s' "$n"; return 0; }
    done < "$ovr"
  }
  out=$(LC_ALL=C RAS_RISKY=$ovr awk -f "$here/guard.awk") || {
    bad=
    [ -z "$ovr" ] || bad=$(badline) || :
    die "the awk guard failed${bad:+; $bad of .ras/risky-paths is not a valid pattern}${ovr:+; check the patterns in .ras/risky-paths}"
  }
  case $out in *"$nl"*) ;; *) die "unexpected guard output" ;; esac
  sid=${out%%"$nl"*}
  v=${out#*"$nl"}
  case $v in
  *"$nl"*) die "unexpected guard output" ;;
  ok) allow ;;
  specs) ign; allow ;;
  # No approval and no skip opens these two. A call the guard cannot read could hide a locked target.
  "locked "*) trap - EXIT; echo "ras: locked: ${v#locked }. An approved spec and skip spec do not unlock this. If it must happen, ask the user to do it themself." >&2; exit 2 ;;
  "cannot "*) trap - EXIT; echo "ras: ${v#cannot }" >&2; exit 2 ;;
  "risky "*) ;;
  *) die "unexpected guard output" ;;
  esac
  if skipped || approved; then allow; fi
  deny "${v#risky }"
fi

# One awk process reads the event and prints nine lines (event.awk). A process start costs about
# 0.1 s on Windows, and these events run on every prompt and every reply.
ev=$(LC_ALL=C awk -f "$here/event.awk") || die "the awk event reader failed"
{
  IFS= read -r sid; IFS= read -r safe; IFS= read -r src; IFS= read -r agent
  IFS= read -r active; IFS= read -r p; IFS= read -r asks; IFS= read -r decisions; IFS= read -r near
} <<EOF
$ev
EOF
# The file that holds this turn's starting snapshot. Empty when there is no session id.
t=
[ -z "$safe" ] || t=${TMPDIR:-/tmp}/ras-turn-$safe

# Changed text files, one line each: git numstat for tracked files, git --eol for untracked ones.
# Binary files are left out: numstat shows them as "-", --eol as w/-text.
snap() {
  git -C "$proj" diff HEAD --numstat -- . 2>/dev/null | grep -v '^-' || :
  git -C "$proj" ls-files -o --exclude-standard --eol 2>/dev/null | grep -v 'w/-text' || :
}

case $event in
SessionStart)
  [ -d "$proj/specs" ] && ign
  # A new or cleared session starts unapproved. Resume and compact keep the approval.
  # Other sessions keep theirs: only this session's line and its own skip go.
  case $src in startup | clear | '')
    unmark
    if [ -z "$sid" ] || skipped; then rm -f "$d/spec.skip"; fi ;;
  esac
  # Turn snapshots of sessions that ended more than a day ago. Best effort.
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'ras-turn-*' -mtime +0 -exec rm -f {} + 2>/dev/null || :
  # A spec left from earlier work: say so, because `approve spec` would approve that file. A fixed sentence, never spec text.
  old=
  if [ -f "$spec" ] && ! approved; then old=' specs/current.md already holds a spec that is not approved in this session. Tell the user it is there before you start work on a spec.'; fi
  printf '%s%s%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ras plugin. Work normally and keep diffs small.\nThe user can run /spec (or /ras:spec) for a plan: the spec skill asks the open questions, writes specs/current.md and waits for `approve spec`.' "$old" '\nRisky paths (CI, env files, migrations, SQL, infra, auth) are locked until a spec is approved. If a hook denies an edit, load spec.\nFor a failure with an unknown cause, load diagnose. For a question that needs facts from outside the repo, such as a library choice or breaking changes between versions, load research before you answer. When a change touches auth, permissions, secrets, payments, personal data or deletes, load security-check.\nEnd every reply that changed code with a short Decisions section: choices you made that the user did not specify, and what you skipped or did not check, or none."}}' ;;
UserPromptSubmit)
  if [ "$agent" = 1 ]; then allow; fi
  # $p is the last line of the prompt, without . and ! at its end (event.awk).
  # skip spec lasts until this session's next prompt. Another session's prompt leaves it alone.
  if [ "$p" != "skip spec" ] && skipped; then rm -f "$d/spec.skip"; fi
  case $p in
  "approve spec")
    if [ -z "$sid" ]; then
      echo "Not approved: this prompt carries no session id."
    elif [ -f "$spec" ]; then
      init
      ck=$(cksum < "$spec")
      prune "$ck" # no second line for this session, and none left for an older text of the spec
      printf '%s %s\n' "$ck" "$sid" >> "$d/spec.approved"
      echo "Approved spec: $(sed -n '/^## Goal/,/^## /{/^#/!{/./p;};}' "$spec" | sed -n 1p)"
    else
      echo "No specs/current.md to approve."
    fi ;;
  "skip spec")
    if [ -n "$sid" ]; then init; printf '%s\n' "$sid" > "$d/spec.skip"; fi ;;
  esac
  # Remember what was already changed, so Stop can tell what this turn changed.
  if [ -n "$t" ]; then
    { git -C "$proj" rev-parse --is-inside-work-tree >/dev/null && snap > "$t"; } 2>/dev/null || :
  fi
  # A short prompt that names the approval without giving it: say so now, not at the next denied edit.
  if [ "$near" = 1 ] && [ -f "$spec" ] && ! approved; then
    trap - EXIT
    printf '%s\n' '{"systemMessage":"ras: Not approved. Send approve spec alone, or as the last line of your message.","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"ras: Not approved. That prompt named the approval but did not give it. The spec is approved only when the user sends approve spec alone or as the last line of a message. Tell the user, and do not build on it."}}'
    exit 0
  fi ;;
Stop)
  # When the agent asks for approval, show the user the spec's Decisions section.
  if [ "$asks" = 1 ] && [ -f "$spec" ] && ! approved; then
    dec=$(sed -n '/^## Decisions/,/^## /{/^## /!p;}' "$spec" | sed '/^[[:space:]]*$/d')
    [ -n "$dec" ] || dec='None written. Ask the agent which choices the spec makes before you approve.'
    msg=$(printf 'Decisions in specs/current.md:\n%s' "$dec" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\t' ' ' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
    trap - EXIT
    printf '{"systemMessage":"%s"}\n' "$msg"
    exit 0
  fi
  # A Stop that has nothing else to say. When finalize archived the approved spec, remind the user
  # once of /scope-review. Only the user can start it, so this is a message and not a block.
  quiet() {
    if archived; then
      unmark
      trap - EXIT
      printf '%s\n' '{"systemMessage":"ras: the approved spec is archived. Run /scope-review to check the change against it."}'
      exit 0
    fi
    allow
  }
  # Fallback: the turn changed files and the reply has no Decisions heading. Ask once.
  if [ "$active" = 1 ]; then quiet; fi
  if [ "$decisions" = 1 ]; then quiet; fi
  [ -n "$t" ] && [ -f "$t" ] || quiet
  git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1 || quiet
  n=$(snap | grep -vxFc -f "$t" || :)
  [ "${n:-0}" -gt 0 ] || quiet
  trap - EXIT
  printf '{"decision":"block","reason":"ras: this turn touched %s files. End your reply with a short Decisions section: the choices you made that the user did not specify, and what you skipped or did not check, or none."}\n' "$n"
  exit 0 ;;
*)
  die "unknown event '$event'" ;;
esac
allow
