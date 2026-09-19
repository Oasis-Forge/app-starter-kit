#!/usr/bin/env bash
# Checks stacks/flutter/files/tool/check_permissions.sh, the RUN-2 gate. It used to
# live inline in release.yml behind `aapt2 ... | tee`, where the default `bash -e`
# step shell reported tee's exit code and a failed dump passed the gate with an
# empty file. A gate that fails open is worse than no gate, so it gets its own test.
#
#   bash tests/test-permission-gate.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
gate="$kit/stacks/flutter/files/tool/check_permissions.sh"
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }

# Writes an aapt2-style dump of the named permissions.
dump() {
  local file="$work/permissions.txt"
  : > "$file"
  for p in "$@"; do echo "uses-permission: name='$p'" >> "$file"; done
  echo "$file"
}
# run <allowed> <expect-pass> <name> -- permissions...
run() {
  local allowed=$1 expect=$2 name=$3; shift 3
  local out
  out=$(ALLOWED="$allowed" PACKAGE_NAME=com.example.app bash "$gate" "$(dump "$@")" 2>&1)
  local code=$?
  if [ "$expect" = pass ] && [ "$code" -eq 0 ]; then ok "$name"
  elif [ "$expect" = fail ] && [ "$code" -ne 0 ]; then ok "$name"
  else bad "$name (exit $code: $out)"; fi
}

echo "check_permissions.sh in $kit"
echo ""

run ''                                   pass 'no permissions, empty allow list'
run ''                                   fail 'an empty allow list refuses a permission, it does not allow everything' android.permission.INTERNET
run 'android.permission.INTERNET'        pass 'a declared permission on the list' android.permission.INTERNET
run 'android.permission.INTERNET'        fail 'a permission on the list that vanished from the build'
run 'android.permission.INTERNET'        fail 'one allowed, one snuck in by a plugin' android.permission.INTERNET android.permission.RECEIVE_BOOT_COMPLETED
run 'android.permission.INTERNET android.permission.POST_NOTIFICATIONS' pass 'several, all listed' android.permission.POST_NOTIFICATIONS android.permission.INTERNET

# The app's own generated permissions are not ours to declare.
run '' pass "the app's own generated permission is ignored" com.example.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION

# uses-permission-sdk-23 is a real form aapt2 prints and must not slip past.
sdk23="$work/sdk23.txt"
printf "uses-permission-sdk-23: name='android.permission.BLUETOOTH_CONNECT'\n" > "$sdk23"
out=$(ALLOWED='' PACKAGE_NAME=com.example.app bash "$gate" "$sdk23" 2>&1)
if [ $? -ne 0 ]; then ok 'uses-permission-sdk-23 is caught too'; else bad "uses-permission-sdk-23 is caught too ($out)"; fi

# A missing dump is the fail-open case: it must not be read as "nothing declared".
out=$(ALLOWED='' PACKAGE_NAME=com.example.app bash "$gate" "$work/does-not-exist.txt" 2>&1)
if [ $? -ne 0 ]; then ok 'a missing dump fails instead of passing empty'; else bad "a missing dump fails instead of passing empty ($out)"; fi
out=$(ALLOWED='' PACKAGE_NAME=com.example.app bash "$gate" 2>&1)
if [ $? -ne 0 ]; then ok 'no argument fails'; else bad "no argument fails ($out)"; fi

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
