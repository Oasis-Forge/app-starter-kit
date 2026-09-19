#!/usr/bin/env bash
# Every {{PLACEHOLDER}} the kit ships has to be one /kickoff can actually fill in:
# listed in README.md's table, and for a command, given a value by every stack's
# Fill-ins. A placeholder nobody documented is one /kickoff stops to ask about, or
# worse, leaves in the copied app.
#
#   bash tests/test-placeholders.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
cd "$kit"
failures=0

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }
has() { printf '%s\n' "$2" | grep -qxF "$1"; }

# Backticked NAME or NAME_* from a markdown table's rows, not from prose: README
# talks about `HEAD` and `CMD_*` in sentences too.
row_names() { grep -hE '^\|' "$1" | grep -oE '`[A-Z_]+\*?`' | tr -d '`' | sort -u; }
first_col()  { grep -hoE '^\| `[A-Z_]+\*?`' "$1" | tr -d '|` ' | sort -u; }

used=$(grep -rhoE '\{\{[A-Z_]+\}\}' template stacks | tr -d '{}' | sort -u)
documented=$(row_names README.md)

echo "placeholders in $kit"
echo ""
echo "every placeholder used is documented in README.md"
before=$failures
for token in $used; do
  if has "$token" "$documented"; then
    continue
  elif case "$token" in CMD_*) has 'CMD_*' "$documented" ;; *) false ;; esac; then
    continue
  else
    bad "{{$token}} is used but not in README.md's placeholder table"
  fi
done
[ "$failures" -eq "$before" ] && ok "all $(printf '%s\n' "$used" | wc -l | tr -d ' ') placeholders are documented"

echo ""
echo "nothing documented is unused"
before=$failures
for token in $documented; do
  case "$token" in CMD_*) continue ;; esac  # the wildcard row; commands are checked per stack
  has "$token" "$used" || bad "README.md documents {{$token}}, which nothing uses"
done
[ "$failures" -eq "$before" ] && ok "no stale rows"

echo ""
echo "every command placeholder has a value in each stack's Fill-ins"
before=$failures
shared=$(grep -rhoE '\{\{CMD_[A-Z_]+\}\}' template | tr -d '{}' | sort -u)
for notes in stacks/*/files/docs/STACK_NOTES.md; do
  [ -f "$notes" ] || continue
  stack=$(echo "$notes" | cut -d/ -f2)
  fillins=$(first_col "$notes")
  for token in $shared; do
    has "$token" "$fillins" || bad "$stack has no Fill-ins row for {{$token}}, so /kickoff must stop and ask"
  done
  # A placeholder only this stack's files use is this stack's to define.
  for token in $(grep -rhoE '\{\{[A-Z_]+\}\}' "stacks/$stack" | tr -d '{}' | sort -u); do
    case "$token" in CMD_*) continue ;; esac
    if ! has "$token" "$fillins" && ! has "$token" "$documented"; then
      bad "{{$token}} is used by the $stack stack but defined neither there nor in README.md"
    fi
  done
done
[ "$failures" -eq "$before" ] && ok "every stack defines the commands the template calls"

echo ""
echo "no malformed placeholders"
before=$failures
# {{Name}}, {{ NAME }} and a stray {{ never get replaced, and /kickoff's grep for
# {{[A-Z_]+}} would not see them either. GitHub Actions ${{ ... }} is not ours.
stray=$(grep -rn '{{' template stacks \
  | sed -E -e 's/\$[{][{][^}]*[}][}]//g' -e 's/[{][{][A-Z_]+[}][}]//g' \
  | grep '{{' || true)
if [ -n "$stray" ]; then
  printf '%s\n' "$stray" | while read -r line; do echo "      $line"; done
  bad "a {{ that is not a {{UPPER_SNAKE}} placeholder"
fi
[ "$failures" -eq "$before" ] && ok "every {{ opens a well-formed placeholder"

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
