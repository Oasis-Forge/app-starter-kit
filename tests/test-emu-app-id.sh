#!/usr/bin/env bash
# Checks how stacks/flutter/files/tool/emu.sh finds the application id `launch`
# starts. It used to be a {{APP_ID}} placeholder, which made a 250-line tool a
# hand-merge for every app on every fix. The rest of the tool needs an emulator;
# this part does not, and it is the part that can point `launch` at the wrong app.
#
#   bash tests/test-emu-app-id.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
tool=${TOOL:-$kit/stacks/flutter/files/tool/emu.sh}
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi }

fixture() {
  [ -n "$work" ] || exit 1
  rm -rf "$work/app"
  mkdir -p "$work/app/$1"
}
# The id the tool would launch, from inside the fixture.
run() { (cd "$work/app" && bash "$tool" app 2>&1); }

echo "emu.sh application id in $kit"
echo ""

fixture android/app
printf 'android {\n    defaultConfig {\n        applicationId = "com.example.kts"\n        applicationIdSuffix = ".debug"\n    }\n}\n' \
  > "$work/app/android/app/build.gradle.kts"
check 'read from a Kotlin build file' "$(run)" 'com.example.kts'

fixture android/app
printf 'android {\n    defaultConfig {\n        applicationId "com.example.groovy"\n    }\n}\n' \
  > "$work/app/android/app/build.gradle"
check 'read from a Groovy build file' "$(run)" 'com.example.groovy'

# An app whose Flutter project is not at the repo root, as one real app is.
fixture Sub/android/app
printf '        applicationId = "com.example.sub"\n' > "$work/app/Sub/android/app/build.gradle.kts"
check 'found in a subdirectory' "$(run)" 'com.example.sub'

check 'APP_ID wins over the build file' "$(cd "$work/app" && APP_ID=com.example.env bash "$tool" app 2>&1)" 'com.example.env'

fixture .
out=$(run); code=$?
check 'nothing to read from exits 1' "$code" '1'
case "$out" in *APP_ID*) ok 'and says what to set' ;; *) bad "and says what to set (got: $out)" ;; esac

# The point of reading it at use: the tool is then not a templated file, so
# -Update copies a fix straight into every app instead of leaving a .kit-new.
check 'the tool carries no placeholder' "$(grep -c '{{' "$tool")" '0'

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
