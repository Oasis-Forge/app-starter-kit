#!/usr/bin/env bash
# A directory a stack denies reading must not be one its own docs tell you to run
# a command on.
#
# Claude Code's deny list is not scoped to the Read tool: a denied glob also
# refuses a shell command whose path argument falls under it. An app recorded
# that the hard way, in its release skill -- "with PowerShell Copy-Item and
# absolute paths (Bash cp under build/ is blocked)" -- where the only rule
# naming build/ is Read(./build/**) in deny.
#
# The flutter stack then shipped Read(./dist/**) in the same deny list while its
# emulator skill said `install dist/<slug>-X.Y.Z.apk` and its stack notes said
# `adb install -r dist/<slug>-X.Y.Z.apk`, so the one hand-test step /ship
# requires could not run. Nothing caught it, because the kit executes none of
# this: the first app to adopt that settings file would have paid for it.
#
# The shared template kept the same Read(./dist/**) after the flutter stack dropped
# it, so an app on a stack the kit has no overlay for got it -- and the release
# skill tells /release to copy its artifacts into dist/. That mention is prose
# ("copy the results to `dist/...`"), not a command, so the check below would not
# have seen it: dist/ gets its own rule, as the one directory the kit's own skills
# write into.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0
checked=0

# dist/ is where /release puts the local artifact and where /emulator installs it
# from, in every stack. No settings file the kit ships may deny it.
for settings in template/.claude/settings.json stacks/*/files/.claude/settings.json; do
  [ -e "$settings" ] || continue
  if grep -qE '"Read\(\./dist/\*\*\)"' "$settings"; then
    echo "FAIL: $settings denies Read(./dist/**), the directory /release writes the artifact to and /emulator installs from"
    status=1
  fi
done

# A candidate is treated as a command when it opens with a lowercase word followed
# by a space: `adb install -r dist/x.apk` is a command, `dist/x.apk` on its own is
# a path being named, a "# dist/ holds ..." comment line is not a command, and
# `flutter build apk` never matches build/ because the word there is followed by a
# space, not a slash. That last distinction is what keeps prose such as the
# coverage skill's "without reading coverage/lcov.info" out of the results.
looks_like_a_command() {
  printf '%s' "$1" | grep -qE '^[a-z][a-z0-9_.-]*[[:space:]]'
}

# Every command a doc shows: the backticked spans, plus the lines inside its shell
# fences. Both carry real commands -- the emulator skill's install step is inline
# in backticks, the stack notes' is in a ```bash block.
commands_in() {
  grep -oE '`[^`]+`' "$1" | sed -E 's|^`||; s|`$||' || true
  awk '
    /^```/ {
      if (fence) { fence = 0; next }
      lang = substr($0, 4)
      gsub(/[^a-z]/, "", lang)
      fence = (lang == "" || lang == "bash" || lang == "sh" || lang == "shell" || lang == "console")
      next
    }
    fence { print }
  ' "$1"
}

# The shared settings against the shared docs (what a -Stack none app gets), and
# each stack's settings against its own docs plus the shared ones.
for settings in template/.claude/settings.json stacks/*/files/.claude/settings.json; do
  [ -e "$settings" ] || continue
  case "$settings" in
    template/*) stack=template ;;
    *) stack=$(basename "$(dirname "$(dirname "$(dirname "$settings")")")") ;;
  esac

  denied=$(grep -oE '"Read\(\./[^)*]+/\*\*\)"' "$settings" |
    sed -E 's|^"Read\(\./||; s|/\*\*\)"$||' || true)
  [ -n "$denied" ] || continue

  docs=()
  for pattern in \
    "stacks/$stack/files/.claude/skills"/*/SKILL.md \
    "stacks/$stack/files/docs"/*.md \
    template/.claude/skills/*/SKILL.md \
    template/docs/*.md; do
    [ -e "$pattern" ] && docs+=("$pattern")
  done
  [ ${#docs[@]} -gt 0 ] || continue

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    checked=$((checked + 1))
    for doc in "${docs[@]}"; do
      while IFS= read -r candidate; do
        case "$candidate" in
          *"$dir/"*) ;;
          *) continue ;;
        esac
        if looks_like_a_command "$candidate"; then
          echo "FAIL: $stack denies Read(./$dir/**) but $doc runs: $candidate"
          status=1
        fi
      done < <(commands_in "$doc")
    done
  done <<<"$denied"
done

if [ "$checked" -eq 0 ]; then
  echo 'FAIL: no denied directories were found to check -- the test proved nothing'
  exit 1
fi

if [ "$status" -eq 0 ]; then
  echo "ok: $checked denied path(s), none of them used as a command argument"
fi
exit "$status"
