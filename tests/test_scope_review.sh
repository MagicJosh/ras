#!/bin/sh
# Test for skills/scope-review/review-file.sh. Run: sh tests/test_scope_review.sh
root=$(cd "$(dirname "$0")/.." && pwd)
script=$root/skills/scope-review/review-file.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { # name, wanted, got
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); printf 'ok   %s\n' "$1"; else fail=$((fail + 1)); printf 'FAIL %s (want %s, got %s)\n' "$1" "$2" "$3"; fi
}
has() { grep -qF -- "$2" "$1" && echo yes || echo no; } # file, text
commit() { git add -A && git -c user.name=t -c user.email=t@example.com commit -qm "$1"; }

repo() { # a fresh repo with one committed file and an ignored specs/ folder
  rm -rf "$tmp/r" && mkdir -p "$tmp/r/specs" && cd "$tmp/r" && git init -q
  printf 'def is_even(n):\n    return n %% 2 == 1\n' > calc.py
  printf 'print(1)\n' > app.py
  printf '*\n' > specs/.gitignore
  commit init
}
spec() { # $1: the file to write
  cat > "$1" <<'MD'
# Spec: Fix is_even

## Goal
is_even returns True for even numbers.

## Decisions
- Fix the comparison. Rejected: a lookup table. Hard to undo: no.

## Acceptance criteria
1. `python3 test_calc.py` prints ok.

## Non-goals
- No other changes.

## Blast radius
- `calc.py`: line 2. Callers: `app.py`.
MD
}

# Not a repo, no spec, unknown base.
mkdir -p "$tmp/n" && cd "$tmp/n" && GIT_CEILING_DIRECTORIES=$tmp sh "$script" >/dev/null 2>&1; check "outside a git repo: exit 1" 1 $?
repo; sh "$script" >/dev/null 2>&1; check "no spec: exit 1" 1 $?
spec specs/current.md; sh "$script" nosuchcommit >/dev/null 2>&1; check "unknown base: exit 1" 1 $?

# An empty change is refused, and leaves no files behind.
sh "$script" >/dev/null 2>&1; check "empty change: exit 3" 3 $?
check "empty change: no review files left" 0 "$(ls specs | grep -c '^review-')"

# A tracked edit and an untracked file both land in the diff. specs/ stays out.
printf 'def is_even(n):\n    return n %% 2 == 0\n' > calc.py
printf 'assert True\n' > test_new.py
out=$(sh "$script"); check "a change: exit 0" 0 $?
md=$(printf '%s\n' "$out" | sed -n 1p); df=$(printf '%s\n' "$out" | sed -n 2p)
check "prints the review file path" "specs/review-$(date +%Y-%m-%d)-fix-is-even.md" "$md"
check "prints the diff file path" "specs/review-$(date +%Y-%m-%d)-fix-is-even.diff" "$df"
check "diff holds the tracked edit" yes "$(has "$df" '+    return n % 2 == 0')"
check "diff holds the untracked file" yes "$(has "$df" '+assert True')"
check "diff leaves specs/ out" no "$(has "$df" 'Spec: Fix is_even')"
check "review file copies the goal" yes "$(has "$md" 'is_even returns True for even numbers.')"
check "review file copies the criteria" yes "$(has "$md" '1. `python3 test_calc.py` prints ok.')"
check "review file copies the blast radius" yes "$(has "$md" '- `calc.py`: line 2. Callers: `app.py`.')"
check "review file copies the decisions" yes "$(has "$md" 'Rejected: a lookup table.')"
check "review file copies the non-goals" yes "$(has "$md" '- No other changes.')"
check "non-goals sit under Out of scope" yes "$(sed -n '/^## Out of scope/,$p' "$md" | grep -qF 'No other changes.' && echo yes || echo no)"
check "a missing section is said" yes "$(has "$md" '(The spec has no Proposed additions section.)')"
check "review file names the spec cksum" yes "$(has "$md" "cksum $(cksum < specs/current.md)")"
check "review file names the base" yes "$(has "$md" "($(git rev-parse --short HEAD))")"
check "the spec itself is unchanged" yes "$(has specs/current.md '# Spec: Fix is_even')"
check "the names miss the finalize cleanup" 0 "$(ls specs/2*.md 2>/dev/null | wc -l | tr -d ' ')"

# --print writes nothing and puts the scope, then the change, on stdout.
rm -f specs/review-*
out=$(sh "$script" --print); check "print: exit 0" 0 $?
check "print: no review files left" 0 "$(ls specs | grep -c '^review-')"
check "print: last line is the end marker" '== end of scope review ==' "$(printf '%s\n' "$out" | tail -n 1)"
has_out() { printf '%s\n' "$out" | grep -qF -- "$1" && echo yes || echo no; }
check "print: holds the goal" yes "$(has_out 'is_even returns True for even numbers.')"
check "print: holds the tracked edit" yes "$(has_out '+    return n % 2 == 0')"
check "print: holds the untracked file" yes "$(has_out '+assert True')"
check "print: names the report file" yes "$(has_out "Report file: \`specs/review-$(date +%Y-%m-%d)-fix-is-even.report.md\`.")"
check "print: the change comes after the scope" yes "$(printf '%s\n' "$out" | sed -n '/^== change ==$/,$p' | grep -qF '+assert True' && echo yes || echo no)"
git -c user.name=t -c user.email=t@example.com stash -q -u; sh "$script" --print >/dev/null 2>&1; check "print: empty change: exit 3" 3 $?; git stash pop -q

# After finalize archived the spec, the newest archived spec is used.
mv specs/current.md specs/2026-01-02-fix-is-even.md; rm -f specs/review-*
out=$(sh "$script"); check "archived spec: exit 0" 0 $?
check "archived spec is named" yes "$(has "$(printf '%s\n' "$out" | sed -n 1p)" 'specs/2026-01-02-fix-is-even.md')"

# A committed change needs a base.
first=$(git rev-parse HEAD); commit work; rm -f specs/review-*
sh "$script" >/dev/null 2>&1; check "committed work, no base: exit 3" 3 $?
out=$(sh "$script" "$first"); check "committed work with a base: exit 0" 0 $?
check "diff against the base holds the edit" yes "$(has "$(printf '%s\n' "$out" | sed -n 2p)" '+    return n % 2 == 0')"

# A read-only specs/ sends both files to the temp folder. Skipped where chmod does not restrict (Windows, root).
rm -f specs/review-*; chmod 555 specs
if ! ( : > specs/.w ) 2>/dev/null; then
  mkdir -p "$tmp/t"
  out=$(TMPDIR=$tmp/t sh "$script" "$first"); check "read-only specs: exit 0" 0 $?
  check "read-only specs: files go to the temp folder" yes "$([ -s "$tmp/t/$(basename "$(printf '%s\n' "$out" | sed -n 2p)")" ] && echo yes || echo no)"
fi
chmod 755 specs; rm -f specs/.w

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
