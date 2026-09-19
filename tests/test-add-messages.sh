#!/usr/bin/env bash
# Checks stacks/flutter/files/tool/add_messages.dart, which edits every ARB file at
# once. Its failure mode is the dangerous kind: it reported "1 added ... in N files"
# while dropping the message from one of them.
#
#   bash tests/test-add-messages.sh
# Needs a Dart SDK; skips itself with a message if there is none.
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
tool=${TOOL:-$kit/stacks/flutter/files/tool/add_messages.dart}
dart=${DART:-$(command -v dart || true)}
work=$(mktemp -d)
failures=0
trap 'rm -rf "$work"' EXIT

if [ -z "$dart" ]; then
  echo "add_messages.dart: no dart on PATH, skipping (set DART to run these)."
  exit 0
fi

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi }

# A project with an English file and a French one that has drifted: it is missing
# importButton, the key the new message anchors itself after.
fixture() {
  rm -rf "$work/app"
  mkdir -p "$work/app/lib/l10n"
  cat > "$work/app/lib/l10n/app_en.arb" <<'ARB'
{
  "@@locale": "en",
  "importButton": "Import",
  "greeting": "Hello {name}",
  "@greeting": {
    "description": "Shown on the home screen.",
    "placeholders": { "name": { "type": "String" } }
  }
}
ARB
  cat > "$work/app/lib/l10n/app_fr.arb" <<'ARB'
{
  "@@locale": "fr",
  "greeting": "Bonjour {name}"
}
ARB
}
# run <json> -> prints the tool's stdout, exit code in $?
run() { (cd "$work/app" && printf '%s' "$1" > in.json && "$dart" "$tool" in.json 2>&1); }
count() { local n; n=$(grep -c "$1" "$work/app/lib/l10n/app_$2.arb" 2>/dev/null || true); echo "${n:-0}"; }
lineof() { grep -n "\"$1\"" "$work/app/lib/l10n/app_$2.arb" | head -1 | cut -d: -f1; }

echo "add_messages.dart in $kit"
echo ""
echo "adding a message"
fixture
out=$(run '{"importDone":{"en":"Imported {count} rows.","fr":"{count} lignes importees.","placeholders":{"count":{"type":"int"}},"after":"importButton"}}')
check 'it reports one added'          "$(printf '%s' "$out" | head -1)" '1 added, 0 changed, 0 removed, in 2 files.'
check 'English gets it'               "$(count '"importDone"' en)" '1'
# The regression: "after" is validated against English, but put() ran per language.
# A file without the anchor got a non-null anchor that never matched, so the message
# was dropped there while the summary still counted it.
check 'a file missing the anchor gets it too' "$(count '"importDone"' fr)" '1'
if [ "$(lineof importDone en)" -gt "$(lineof importButton en)" ]; then
  ok 'it lands after its anchor'
else
  bad 'it lands after its anchor'
fi

echo ""
echo "changing a message's metadata"
fixture
run '{"greeting":{"en":"Hi {name}","fr":"Salut {name}","description":"Updated."}}' > /dev/null
check 'the new description is written'  "$(count 'Updated.' en)" '1'
# Metadata was built from the input alone and replaced the whole @key block, so
# supplying one field deleted the other -- and a message still using {name} lost
# the declaration gen-l10n needs for it.
check 'placeholders it did not mention survive' "$(count '"name"' en)" '1'

fixture
run '{"greeting":{"en":"Hi there","fr":"Salut","placeholders":null}}' > /dev/null
check 'a field set to null is removed'  "$(count placeholders en)" '0'
check 'and its description stays'       "$(count 'Shown on the home screen' en)" '1'

echo ""
echo "removing a message"
fixture
run '{"greeting":null}' > /dev/null
check 'gone from English'      "$(count '"greeting"' en)" '0'
check 'its metadata goes too'  "$(count '@greeting' en)" '0'
check 'gone from French'       "$(count '"greeting"' fr)" '0'

echo ""
echo "refusing a bad message, without writing anything"
for bad_input in \
  '{"onlyEnglish":{"en":"Text"}}' \
  '{"unused":{"en":"No braces","fr":"Pas d accolades","placeholders":{"count":{"type":"int"}}}}' \
  '{"typo":{"en":"Hi","fr":"Salut","nonsense":1}}' \
  '{"missing":null}'
do
  fixture
  before=$(cat "$work/app/lib/l10n/app_en.arb")
  out=$(run "$bad_input"); code=$?
  after=$(cat "$work/app/lib/l10n/app_en.arb")
  label=$(printf '%s' "$bad_input" | cut -c1-34)
  if [ "$code" -eq 0 ]; then bad "refused: $label (it succeeded)"
  elif [ "$before" != "$after" ]; then bad "refused: $label (it wrote anyway)"
  else ok "refused, nothing written: $label"; fi
done

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
