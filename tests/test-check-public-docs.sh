#!/usr/bin/env bash
# Checks template/scripts/check_public_docs.sh, which is what stops a working
# document -- the roadmap, the product rules, the release runbook, the competitor
# research -- from being published by GitHub Pages just because docs/_config.yml
# forgot to mention it. GitHub Pages serves every file under docs/ by default, and
# this script is the only thing that compares that folder against the config.
#
#   bash tests/test-check-public-docs.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
script=${SCRIPT:-$kit/template/scripts/check_public_docs.sh}
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; failures=$((failures + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi }

# The same docs/ + _config.yml shape as template/docs itself: comment lines, an
# exclude: list, a comment, then a public: list. Called fresh for every case so
# one test's leftover file can't hide in the next one's.
fixture() {
  rm -rf "$work/docs"
  mkdir -p "$work/docs/research"
  : > "$work/docs/ROADMAP.md"
  : > "$work/docs/PRODUCT_RULES.md"
  : > "$work/docs/RELEASING.md"
  : > "$work/docs/STACK_NOTES.md"
  : > "$work/docs/research/competitor-analysis.md"
  : > "$work/docs/privacy-policy.md"
  cat > "$work/docs/_config.yml" <<'YML'
# GitHub Pages serves this folder, and it publishes every file in it by default.
# Only the privacy policy is meant for the public: the rest are working documents.
exclude:
  - ROADMAP.md
  - PRODUCT_RULES.md
  - RELEASING.md
  - STACK_NOTES.md
  - research

# Not a Jekyll setting: the list CI checks the folder against.
public:
  - privacy-policy.md
YML
}
# cwd is $work, so the script's own default (docs/_config.yml relative to cwd) is
# what runs unless a case passes its own path argument.
run() { (cd "$work" && bash "$script" "$@" 2>&1); }

echo "check_public_docs.sh in $kit"
echo ""

fixture
out=$(run); code=$?
check 'every entry excluded or public: exits 0' "$code" '0'
check 'the success line names the public file' "$out" 'Every entry in docs is accounted for: privacy-policy.md published, the rest excluded.'

fixture
: > "$work/docs/SURPRISE.md"
out=$(run); code=$?
check 'one undeclared file: exits 1' "$code" '1'
case "$out" in *"::error::"*) ok 'and is reported with ::error::' ;; *) bad "and is reported with ::error:: (got: $out)" ;; esac
case "$out" in *"SURPRISE.md"*) ok 'naming the file' ;; *) bad "naming the file (got: $out)" ;; esac

fixture
mkdir -p "$work/docs/notes"
out=$(run); code=$?
check 'an undeclared subdirectory: exits 1' "$code" '1'
case "$out" in *"notes"*) ok 'naming the directory' ;; *) bad "naming the directory (got: $out)" ;; esac

# find is -maxdepth 1, so a file added inside an already-excluded directory is
# invisible to it: only the directory's own name is ever checked against the lists.
fixture
: > "$work/docs/research/extra-notes.md"
out=$(run); code=$?
check 'a nested file inside an excluded directory does not fail' "$code" '0'

fixture
rm "$work/docs/_config.yml"
out=$(run); code=$?
check 'a missing _config.yml: exits 1' "$code" '1'
case "$out" in *"::error::"*) ok 'and is reported with ::error::' ;; *) bad "and is reported with ::error:: (got: $out)" ;; esac

# _config.yml is skipped by name, regardless of whether it is listed in exclude or
# public -- it never has to declare itself.
fixture
out=$(run); code=$?
case "$out" in *"_config.yml"*) bad "_config.yml itself is never reported (got: $out)" ;; *) ok '_config.yml itself is never reported' ;; esac

fixture
out=$(cd "$kit" && bash "$script" "$work/docs/_config.yml" 2>&1); code=$?
check 'the config path works as an argument, from another cwd' "$code" '0'

# A config with both lists empty has to report every entry, not die quietly:
# `grep -v` selected nothing and exited 1, and set -e turned that into a bare
# exit 1 with no ::error:: line.
fixture
printf 'exclude:\npublic:\n' > "$work/docs/_config.yml"
out=$(run); code=$?
check 'an empty config: exits 1' "$code" '1'
case "$out" in *"::error::"*"ROADMAP.md"*) ok 'and reports every entry with ::error::' ;; *) bad "and reports every entry with ::error:: (got: $out)" ;; esac

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
