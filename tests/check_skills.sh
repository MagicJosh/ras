#!/bin/sh
# Check the skills in skills/. Run from any directory: sh tests/check_skills.sh
# For each listed skill (a missing one fails): Agent Skills frontmatter, word caps, no local names.
# If skills/which exists: its table must name exactly the other skill folders.
cd "$(dirname "$0")/.." || exit 1
fail=0
bad() { echo "FAIL $*"; fail=1; }

for s in spec build finalize diagnose architecture distributed-architecture deep-review security-check which rules spar; do
  f=skills/$s/SKILL.md
  [ -f "$f" ] || { bad "$s: missing $f"; continue; }
  fm=$(sed -n '2,/^---$/p' "$f" | sed '$d')
  [ "$(sed -n 1p "$f")" = --- ] || bad "$s: no frontmatter"
  [ "$(printf '%s\n' "$fm" | grep -m1 '^name:')" = "name: $s" ] || bad "$s: name is not $s"
  printf '%s\n' "$fm" | grep -q '^description: Use when ' || bad "$s: description must be one line that starts with 'Use when'"
  printf '%s\n' "$fm" | grep '^description:' | sed 's/^description: //' | grep -q ': ' && bad "$s: description has ': ', which breaks YAML"
  keys=$(printf '%s\n' "$fm" | grep -oE '^[a-z-]+:' | tr -d ':' | tr '\n' ' ')
  want='name description '
  case $s in which | rules | spar | debt | handoff) want='name description disable-model-invocation ' ;; esac
  [ "$keys" = "$want" ] || bad "$s: frontmatter keys are '$keys', want '$want'"
  case $s in which | rules | spar | debt | handoff) printf '%s\n' "$fm" | grep -qx 'disable-model-invocation: true' || bad "$s: needs disable-model-invocation: true" ;; esac
  grep -nE 'Hermes|Woshy|Igor|/home/|~/\.hermes' "$f" && bad "$s: names Hermes, Woshy, Igor or a local path"
  case $s in spec | build | diagnose) cap=600 ;; finalize) cap=800 ;; spar) cap=400 ;; which | handoff) cap=320 ;; rules | debt) cap=250 ;; *) cap=0 ;; esac
  [ "$cap" = 0 ] || [ "$(wc -w < "$f")" -le "$cap" ] || bad "$s: over $cap words"
done

if [ -f skills/which/SKILL.md ]; then
  have=$(ls skills | grep -vx which | sort)
  named=$(sed -n 's/^| `\([a-z-]*\)` |.*/\1/p' skills/which/SKILL.md | sort)
  [ "$have" = "$named" ] || bad "which table differs from the skill folders. table: $(echo $named) folders: $(echo $have)"
fi

[ "$fail" = 0 ] && echo "check_skills: ok"
exit "$fail"
