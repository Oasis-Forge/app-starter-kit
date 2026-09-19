#!/usr/bin/env bash
# Checks template/scripts/rules.sh, which is the only thing that ever verifies the
# rule IDs the whole method hangs on.
#
#   bash tests/test-rules.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
script=${SCRIPT:-$kit/template/scripts/rules.sh}
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }

# A tiny repo: rules.sh reads tracked files, so the fixture has to be a git repo.
fixture() {
  rm -rf "$work/app"
  mkdir -p "$work/app/docs" "$work/app/lib"
  cd "$work/app"
  git init --quiet -b main .
  git config user.email t@example.com
  git config user.name test
  cat > docs/PRODUCT_RULES.md <<'MD'
# Product rules

- **REC-1** Every record has timestamps.
- **REC-2** Every record ID is a UUID.
- **ADS-1** Two formats only.
MD
  cp "$script" rules.sh
}
run() { (cd "$work/app" && git add -A > /dev/null 2>&1; bash rules.sh 2>&1); }

echo "rules.sh in $kit"
echo ""

fixture
printf 'x // REC-1\n' > lib/a.dart
out=$(run); code=$?
check_has() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3 (got: $1)" ;; esac }
check_missing() { case "$1" in *"$2"*) bad "$4 (got: $1)" ;; *) ok "$4" ;; esac }
check_has "$out" 'REC-2' 'a rule nothing cites is listed'
check_has "$out" 'ADS-1' 'and so is another'
check_missing "$out" 'REC-1' x 'a rule that is cited is not listed'
if [ "$code" -eq 0 ]; then ok 'uncited rules do not fail the build'; else bad 'uncited rules do not fail the build'; fi

fixture
printf 'x // REC-1 REC-2 ADS-1\n' > lib/a.dart
out=$(run); code=$?
check_has "$out" 'is cited somewhere else' 'all cited says so'
if [ "$code" -eq 0 ]; then ok 'and exits 0'; else bad 'and exits 0'; fi

# The error worth failing on: an ID nothing defines. A rule ID is stable once
# written, so this is a typo or a renumbering.
fixture
printf 'x // REC-7\n' > lib/a.dart
out=$(run); code=$?
check_has "$out" '::error::' 'a citation to no rule is an error'
check_has "$out" 'REC-7' 'and it names the id'
if [ "$code" -ne 0 ]; then ok 'and fails the build'; else bad 'and fails the build'; fi

# The roadmap cites a whole area at once: "REC-1–REC-2" (en dash) has to count for
# both, or day one reports nearly every rule as cited by nobody and stops being read.
fixture
printf -- '- [ ] Records (REC-1\xe2\x80\x93REC-2) and ads (ADS-1)\n' > docs/ROADMAP.md
out=$(run); code=$?
check_has "$out" 'is cited somewhere else' 'an en-dash range counts for every rule in it'
if [ "$code" -eq 0 ]; then ok 'and exits 0'; else bad "and exits 0 (got: $out)"; fi

# Not every capitalised-thing-dash-number is a rule ID.
fixture
printf 'x // UTF-8 SHA-256 ISO-8601 and REC-1 REC-2 ADS-1\n' > lib/a.dart
out=$(run); code=$?
check_missing "$out" 'UTF-8' x 'UTF-8 is not read as a rule id'
check_missing "$out" 'SHA-256' x 'nor SHA-256'
if [ "$code" -eq 0 ]; then ok 'so they do not fail the build'; else bad "so they do not fail the build (got: $out)"; fi

fixture
rm docs/PRODUCT_RULES.md
out=$(run); code=$?
if [ "$code" -ne 0 ]; then ok 'a missing rules file is an error'; else bad 'a missing rules file is an error'; fi

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
