#!/usr/bin/env bash
# Checks stacks/flutter/files/tool/coverage_gaps.dart, which turns
# coverage/lcov.info and `git diff` into the only thing the pre-merge coverage
# check needs: the lines still missed in the Dart files this branch touched.
# Needs a Dart SDK; skips itself with a message if there is none.
#
#   bash tests/test-coverage-gaps.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
tool=${TOOL:-$kit/stacks/flutter/files/tool/coverage_gaps.dart}
dart=${DART:-$(command -v dart || true)}
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

if [ -z "$dart" ]; then
  echo "coverage_gaps.dart: no dart on PATH, skipping (set DART to run these)."
  exit 0
fi

ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; failures=$((failures + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi }

# A repo with a real origin: the tool runs `git merge-base origin/main HEAD`
# itself, and a local push leaves refs/remotes/origin/main behind without
# needing a fetch.
#
# Always go through repo(), not new_repo() directly: if it half-fails, $dir comes
# back empty and every `git -C "$dir"`/`rm -rf` below would otherwise run against
# the current directory -- this kit's own checkout.
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
  echo "$dir"
}
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

d=$(repo app)

# lib/a.dart and lib/l10n/app_localizations.dart get changed and committed on a
# branch; lib/b.dart is left alone; lib/c.dart is added but never `git add`ed, to
# exercise the untracked path on its own. The l10n files are what gen-l10n
# writes -- never hand-edited -- so the tool is documented to never report them
# even though one of them did change.
mkdir -p "$d/lib/l10n"
printf 'int a() => 1;\n' > "$d/lib/a.dart"
printf 'int b() => 2;\n' > "$d/lib/b.dart"
printf '// GENERATED\nclass AppLocalizations {}\n' > "$d/lib/l10n/app_localizations.dart"
printf '// GENERATED\nclass AppLocalizationsEn extends AppLocalizations {}\n' > "$d/lib/l10n/app_localizations_en.dart"
git -C "$d" add -A > /dev/null
git -C "$d" commit --quiet -m initial
git -C "$d" tag base-tag
git -C "$d" push --quiet origin main
git -C "$d" checkout --quiet -b feature
printf 'int a() => 1;\nint a2() => 2;\n' > "$d/lib/a.dart"
printf '// GENERATED, changed\nclass AppLocalizations {}\n' > "$d/lib/l10n/app_localizations.dart"
git -C "$d" commit --quiet -am changed
printf 'int c() => 3;\n' > "$d/lib/c.dart"
mkdir -p "$d/coverage"

run() { (cd "$d" && "$dart" "$tool" "$@" 2>&1); }

echo "coverage_gaps.dart in $kit"
echo ""

# lib/b.dart is in lcov too, to prove it stays out for being unchanged, not for
# being unmeasured. lib/l10n/... is fully covered, to prove it stays out on name
# alone. lib/c.dart is left out of lcov entirely.
cat > "$d/coverage/lcov.info" <<'LCOV'
SF:lib/a.dart
DA:1,1
DA:2,1
DA:3,0
DA:4,0
DA:5,0
DA:6,1
DA:7,1
DA:8,1
DA:9,0
end_of_record
SF:lib/b.dart
DA:1,1
end_of_record
SF:lib/l10n/app_localizations.dart
DA:1,1
DA:2,1
end_of_record
LCOV

out=$(run)
case "$out" in *"lib/a.dart: 55%, missed 3-5, 9"*) ok 'a run of misses collapses, with a trailing singleton, and percent floors' ;; *) bad "a run of misses collapses, with a trailing singleton, and percent floors (got: $out)" ;; esac
case "$out" in *"lib/c.dart: no test loads it"*) ok 'a changed file lcov never mentions' ;; *) bad "a changed file lcov never mentions (got: $out)" ;; esac
case "$out" in *"lib/c.dart"*) ok 'an untracked new file counts as changed' ;; *) bad "an untracked new file counts as changed (got: $out)" ;; esac
case "$out" in *"lib/b.dart"*) bad "an unchanged file is not printed (got: $out)" ;; *) ok 'an unchanged file is not printed' ;; esac
case "$out" in *"app_localizations"*) bad "the generated l10n files are never printed, even the one that changed (got: $out)" ;; *) ok 'the generated l10n files are never printed, even the one that changed' ;; esac

cat > "$d/coverage/lcov.info" <<'LCOV'
SF:lib/a.dart
DA:1,1
DA:2,1
end_of_record
LCOV
out=$(run)
case "$out" in *"lib/a.dart: 100%"*) ok 'a changed file with every line hit' ;; *) bad "a changed file with every line hit (got: $out)" ;; esac

# Flutter can write an absolute SF: path; only the lib/... suffix is the path git
# and the rest of the tool's output use.
cat > "$d/coverage/lcov.info" <<'LCOV'
SF:/builds/ci/app/lib/a.dart
DA:1,2
DA:2,0
end_of_record
LCOV
out=$(run)
case "$out" in *"lib/a.dart: 50%, missed 2"*) ok 'an absolute SF: path containing /lib/ matches the relative path' ;; *) bad "an absolute SF: path containing /lib/ matches the relative path (got: $out)" ;; esac

cat > "$d/coverage/lcov.info" <<'LCOV'
SF:lib/a.dart
DA:1,1
DA:2,0
end_of_record
LCOV
out_default=$(run)
out_tag=$(run base-tag)
check 'an explicit base ref (a tag) agrees with the origin/main default' "$out_tag" "$out_default"

rm -f "$d/coverage/lcov.info"
errfile="$work/stderr.txt"
stdout_out=$(cd "$d" && "$dart" "$tool" 2>"$errfile"); code=$?
stderr_out=$(cat "$errfile")
check 'no coverage/lcov.info: exits 1' "$code" '1'
check 'stdout stays clean' "$stdout_out" ''
case "$stderr_out" in *"No coverage/lcov.info"*) ok 'and says so on stderr' ;; *) bad "and says so on stderr (got: $stderr_out)" ;; esac

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
