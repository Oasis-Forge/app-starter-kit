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
#
# Always call this through repo(). If it half-fails, $dir is empty, and every
# `git -C "$dir" ...` below then runs against the CURRENT directory instead --
# which is this kit's own checkout. That is not hypothetical: an earlier version
# of this file lost `local dir=` to an unbound-variable error and deleted the
# kit repo's origin remote.
new_repo() {
  local name=${1:-}
  [ -n "$name" ] || return 1
  local dir="$work/$name"
  [ -n "$work" ] || return 1
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

# Refuses to hand back anything that isn't a real directory under $work, so a
# broken fixture stops the run instead of aiming git at the current repository.
repo() {
  local dir
  dir=$(new_repo "$1") || true
  case "$dir" in
    "$work"/*) ;;
    *) echo "  FAIL  could not build the fixture '$1'; stopping before git touches this repo" >&2; exit 1 ;;
  esac
  [ -d "$dir" ] || { echo "  FAIL  fixture '$1' is not a directory; stopping" >&2; exit 1; }
  echo "$dir"
}

echo "version.sh in $kit"
echo ""
echo "reading the version"

d=$(repo pubspec)
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"
check 'pubspec with a build number: name'  "$(cd "$d" && bash version.sh name)"  '1.1.0'
check 'pubspec with a build number: build' "$(cd "$d" && bash version.sh build)" '9'

# The usage text promises "0 when there is none", but the regex required +N, so a
# plain `version: 1.1.0` made the script fail with "the version must look like x.y.z".
printf 'name: app\nversion: 1.1.0\n' > "$d/pubspec.yaml"
check 'pubspec without a build number: name'  "$(cd "$d" && bash version.sh name)"  '1.1.0'
check 'pubspec without a build number: build' "$(cd "$d" && bash version.sh build)" '0'

d2=$(repo npm)
printf '{\n  "name": "app",\n  "version": "1.1.0"\n}\n' > "$d2/package.json"
check 'package.json: name'  "$(cd "$d2" && bash version.sh name)"  '1.1.0'
check 'package.json: build' "$(cd "$d2" && bash version.sh build)" '0'

d3=$(repo plain)
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
# The baseline is the version on origin/main, not a tag: nothing is published
# from CI, so the repo carries no release tags to compare against.
#
# The other point: --depth=1 is a property of the fetch, not the refspec, so
# running this against a full clone used to write .git/shallow and truncate the
# repository.
printf 'name: app\nversion: 1.0.0+1\n' > "$d/pubspec.yaml"
git -C "$d" add -A > /dev/null
git -C "$d" commit --quiet -m one
git -C "$d" commit --quiet --allow-empty -m two
git -C "$d" push --quiet origin main

# On main — the merge build — the baseline is the commit before the merge.
# Two PRs opened together both pass the gate against the same main; the first
# merge moves it, and the second would otherwise ship as part of no release.
# Here the last commit left the version alone, which is that case.
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad 'on main, a version the last commit did not raise is refused' || ok 'on main, a version the last commit did not raise is refused'

# The same merge build, but the merge did raise the version: that is a release.
# In its own fixture, so pushing to main here can't move the baseline the
# checks below rely on.
d6=$(repo mainraise)
printf 'name: app\nversion: 1.0.0+1\n' > "$d6/pubspec.yaml"
git -C "$d6" add -A > /dev/null
git -C "$d6" commit --quiet -m one
git -C "$d6" push --quiet origin main
printf 'name: app\nversion: 1.1.0+2\n' > "$d6/pubspec.yaml"
git -C "$d6" add -A > /dev/null
git -C "$d6" commit --quiet -m 'raise on main'
git -C "$d6" push --quiet origin main
(cd "$d6" && bash version.sh check > /dev/null 2>&1) && ok 'on main, a raised version is a release' || bad 'on main, a raised version is a release'

# Now a branch: HEAD is ahead of origin/main, which is what a PR looks like.
git -C "$d" commit --quiet --allow-empty -m three
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"
before=$(git -C "$d" rev-list --count HEAD)
(cd "$d" && bash version.sh check > /dev/null) && ok 'a raised version passes' || bad 'a raised version passes'
after=$(git -C "$d" rev-list --count HEAD)
check 'the local clone keeps its history' "$after" "$before"
check 'no .git/shallow is written' "$(git -C "$d" rev-parse --is-shallow-repository)" 'false'

printf 'name: app\nversion: 1.0.0+9\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad "a version at main's is refused" || ok "a version at main's is refused"
printf 'name: app\nversion: 0.9.0+9\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad "a version below main's is refused" || ok "a version below main's is refused"
printf 'name: app\nversion: 1.1.0+1\n' > "$d/pubspec.yaml"
(cd "$d" && bash version.sh check > /dev/null 2>&1) && bad "a build number at main's is refused" || ok "a build number at main's is refused"
printf 'name: app\nversion: 1.1.0+9\n' > "$d/pubspec.yaml"

# Before /kickoff creates the GitHub repo there is no origin. That is "nothing is
# released yet", not a crash: set -e used to abort on the command substitution and
# print git's own fatal with exit 128, so no ::error:: annotation was ever produced.
d4=$(repo noremote)
git -C "$d4" remote remove origin
printf 'name: app\nversion: 1.1.0+9\n' > "$d4/pubspec.yaml"
(cd "$d4" && bash version.sh check > /dev/null 2>&1) && ok 'no origin yet is not an error' || bad 'no origin yet is not an error'

d5=$(repo unreachable)
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
