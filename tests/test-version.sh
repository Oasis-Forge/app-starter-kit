#!/usr/bin/env bash
# Checks template/scripts/version.sh against the ways it has been wrong before.
# No test framework: run it, read the lines, exit 0 means every case held.
#
#   bash tests/test-version.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
script="$kit/template/scripts/version.sh"
work=$(mktemp -d)
failures=0

trap 'rm -rf "$work"' EXIT

ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; failures=$((failures + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi }

# A repo with a real origin, so `check` exercises the tag lookup for real.
new_repo() {
  local name=$1 dir="$work/$name"
  rm -rf "$dir" "$work/$name.git"
  git init --quiet --bare "$work/$name.git"
  git init --quiet -b main "$dir"
  git -C "$dir" remote add origin "$work/$name.git"
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name test
  printf '# Changelog\n\n## [Unreleased]\n\n## [1.1.0] - 2026-01-02\n\n### Added\n- A thing.\n\n## [1.0.0] - 2026-01-01\n\n### Added\n- The first thing.\n' > "$dir/CHANGELOG.md"
  cp "$script" "$dir/version.sh"
  echo "$dir"
}

echo "version.sh in $kit"
echo ""
echo "reading the version"

d=$(new_repo pubspec)
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"
check 'pubspec with a build number: name'  "$(cd "$d" && bash version.sh name)"  '1.1.0'
check 'pubspec with a build number: build' "$(cd "$d" && bash version.sh build)" '9'

# The usage text promises "0 when there is none", but the regex required +N, so a
# plain `version: 1.1.0` made the script fail with "the version must look like x.y.z".
printf 'name: app\nversion: 1.1.0\n' > "$d/pubspec.yaml"
check 'pubspec without a build number: name'  "$(cd "$d" && bash version.sh name)"  '1.1.0'
check 'pubspec without a build number: build' "$(cd "$d" && bash version.sh build)" '0'

d2=$(new_repo npm)
printf '{\n  "name": "app",\n  "version": "1.1.0"\n}\n' > "$d2/package.json"
check 'package.json: name'  "$(cd "$d2" && bash version.sh name)"  '1.1.0'
check 'package.json: build' "$(cd "$d2" && bash version.sh build)" '0'

d3=$(new_repo plain)
printf '1.1.0+9\n' > "$d3/VERSION"
check 'VERSION file: name'  "$(cd "$d3" && bash version.sh name)"  '1.1.0'
check 'VERSION file: build' "$(cd "$d3" && bash version.sh build)" '9'

echo ""
echo "changelog notes"
check 'notes prints only this version'  "$(cd "$d" && bash version.sh notes | grep -c 'A thing')" '1'
check 'notes stops at the next version' "$(cd "$d" && bash version.sh notes | grep -c 'first thing')" '0'
printf 'name: app\nversion: 9.9.9\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh notes > /dev/null 2>&1) && bad 'notes fails without an entry' || ok 'notes fails without an entry'
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"

echo ""
echo "check"
# The whole point: --depth=1 is a property of the fetch, not the refspec, so running
# this against a full clone used to write .git/shallow and truncate the repository.
git -C "$d" add -A > /dev/null
git -C "$d" commit --quiet -m one
git -C "$d" commit --quiet --allow-empty -m two
git -C "$d" commit --quiet --allow-empty -m three
git -C "$d" push --quiet origin main
git -C "$d" tag v1.0.0 HEAD~2
git -C "$d" push --quiet origin v1.0.0
before=$(git -C "$d" rev-list --count HEAD)
(cd "$d" && bash version.sh check > /dev/null) && ok 'a raised version passes' || bad 'a raised version passes'
after=$(git -C "$d" rev-list --count HEAD)
check 'the local clone keeps its history' "$after" "$before"
check 'no .git/shallow is written' "$(git -C "$d" rev-parse --is-shallow-repository)" 'false'

printf 'name: app\nversion: 1.0.0+9\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad 'a version at the tag is refused' || ok 'a version at the tag is refused'
printf 'name: app\nversion: 1.1.0+1\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad 'a build number at the tag is refused' || ok 'a build number at the tag is refused'
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"

# Before /kickoff creates the GitHub repo there is no origin. That is "nothing is
# released yet", not a crash: set -e used to abort on the command substitution and
# print git's own fatal with exit 128, so no ::error:: annotation was ever produced.
d4=$(new_repo noremote)
git -C "$d4" remote remove origin
printf 'name: app\nversion: 1.1.0+9\n' > "$d4/pubspec.yaml"
(cd "$d4" && bash version.sh check > /dev/null 2>&1) && ok 'no origin yet is not an error' || bad 'no origin yet is not an error'

d5=$(new_repo unreachable)
git -C "$d5" remote set-url origin "$work/does-not-exist.git"
printf 'name: app\nversion: 1.1.0+9\n' > "$d5/pubspec.yaml"
out=$(cd "$d5" && bash version.sh check 2>&1); code=$?
check 'an unreachable origin exits 1, not 128' "$code" '1'
case "$out" in *"::error::"*) ok 'an unreachable origin is annotated' ;; *) bad "an unreachable origin is annotated (got: $out)" ;; esac

echo ""
echo "usage"
out=$(cd "$d" && bash version.sh 2>&1); code=$?
check 'no argument exits 2' "$code" '2'
case "$out" in *"version.sh name"*) ok 'usage lists the commands' ;; *) bad "usage lists the commands (got: $out)" ;; esac

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
