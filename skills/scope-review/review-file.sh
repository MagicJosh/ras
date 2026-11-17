#!/bin/sh
# Build what a scope reviewer reads, from the spec and the change. The reviewer gets nothing else.
# Usage: review-file.sh [--print] [base]   Run in the project root. base is a commit, HEAD by default.
# --print writes nothing. The scope and then the change go to stdout, and the last line is
# "== end of scope review ==". The reviewer runs this itself, so it reads what the script made and
# not what the builder passed on. It also works where a sandbox makes every folder read-only.
# Without --print it writes specs/review-<date>-<slug>.md (the scope, copied word for word from the
# spec) and specs/review-<date>-<slug>.diff (git diff <base> plus the untracked files), and prints
# both paths. When specs/ is read-only, both files go to ${TMPDIR:-/tmp} as ras-review-<date>-<slug>.*
# The names start with "review-", so the specs/2*.md cleanup of finalize never matches them.
# Exit 1: no spec, not a git repo, an unknown base, or nowhere to write. Exit 3: the change is empty, so name a base.
set -eu
print=0
[ "${1:-}" = --print ] && { print=1; shift; }
base=${1:-HEAD}
export GIT_OPTIONAL_LOCKS=0 # a read-only sandbox cannot refresh the index
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "scope-review: not a git repository" >&2; exit 1; }
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "scope-review: unknown base '$base'" >&2; exit 1; }

# The live spec, or the newest archived one: finalize may already have moved it.
spec=specs/current.md
[ -f "$spec" ] || spec=$(ls -t specs/2*.md 2>/dev/null | sed -n 1p)
[ -n "$spec" ] && [ -f "$spec" ] || { echo "scope-review: no specs/current.md and no archived spec in specs/" >&2; exit 1; }

title=$(sed -n 's/^# Spec:[[:space:]]*//p' "$spec" | sed -n 1p)
slug=$(printf '%s' "${title:-spec}" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)
name=review-$(date +%Y-%m-%d)-${slug:-spec}

# The change: tracked files against the base, then each untracked file as an added file. specs/ is left out.
change() {
  git diff "$base" -- . ':(exclude)specs'
  git ls-files -o --exclude-standard -- . ':(exclude)specs' | while IFS= read -r f; do
    git diff --no-index -- /dev/null "$f" || : # exits 1 when the files differ, which they always do
  done
}
empty() {
  echo "scope-review: no change against $base. Name the commit the work started from: review-file.sh <commit>" >&2
  exit 3
}

# One section of the spec, word for word, without its heading. Empty when the spec has no such section.
section() { awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$spec" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }
copy() { # heading in the review file, section name in the spec
  printf '### %s\n\n' "$1"
  s=$(section "$2")
  if [ -n "$s" ]; then printf '%s\n\n' "$s"; else printf '(The spec has no %s section.)\n\n' "$2"; fi
}
scope() { # $1: where the change is
  printf '# Scope review: %s\n\n' "${title:-untitled spec}"
  printf 'Spec: `%s`, cksum %s.\n' "$spec" "$(cksum < "$spec")"
  printf 'Base: `%s` (%s). The change is %s: `git diff` against the base, plus the untracked files.\n' "$base" "$(git rev-parse --short "$base")" "$1"
  printf 'Report file: `specs/%s.report.md`.\n' "$name"
  printf 'Not known: which files were already changed before the work started. A file like that may show up in the diff.\n\n'
  printf '## In scope\n\n'
  copy 'Goal' 'Goal'
  copy 'Acceptance criteria' 'Acceptance criteria'
  copy 'Blast radius' 'Blast radius'
  copy 'Decisions' 'Decisions'
  copy 'Proposed additions' 'Proposed additions'
  printf '## Out of scope\n\n'
  copy 'Non-goals' 'Non-goals'
}

if [ "$print" = 1 ]; then
  diff=$(change)
  [ -n "$diff" ] || empty
  scope 'below, after the line "== change =="'
  printf '== change ==\n%s\n== end of scope review ==\n' "$diff"
  exit 0
fi

out=specs/$name
# A sandbox can make the project read-only for shell commands. Then the files go to the temp folder.
# The subshell matters: in dash a failed redirect on ":" ends the whole script.
if ! ( : > "$out.diff" ) 2>/dev/null; then
  out=${TMPDIR:-/tmp}/ras-$name
  ( : > "$out.diff" ) 2>/dev/null || { echo "scope-review: cannot write to specs/ or to ${TMPDIR:-/tmp}" >&2; exit 1; }
fi
change > "$out.diff"
[ -s "$out.diff" ] || { rm -f "$out.diff"; empty; }
scope "in \`$out.diff\`" > "$out.md"
printf '%s\n%s\n' "$out.md" "$out.diff"
