#!/usr/bin/env bash
# One version tool for CI, the release workflow, and /release.
#
#   scripts/version.sh name    print x.y.z
#   scripts/version.sh build   print the build number N (0 when there is none)
#   scripts/version.sh check   fail unless the version is above the base branch's
#                              and CHANGELOG.md has a "## [x.y.z] - YYYY-MM-DD" entry
#   scripts/version.sh notes   print the CHANGELOG.md entry for the current version
#
# The version lives in the first file found of pubspec.yaml (x.y.z, +N optional),
# package.json ("version": "x.y.z"), or VERSION (x.y.z or x.y.z+N).
# Set VERSION_FILE to choose one explicitly.
set -euo pipefail

fail() { echo "::error::$1" >&2; exit 1; }

usage() {
  sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

version_file() {
  if [ -n "${VERSION_FILE:-}" ]; then echo "$VERSION_FILE"; return; fi
  for f in pubspec.yaml package.json VERSION; do
    if [ -f "$f" ]; then echo "$f"; return; fi
  done
  fail "no pubspec.yaml, package.json, or VERSION file found"
}

# Reads a version file's content on stdin and prints "x.y.z N".
# The build number is optional everywhere: `build` reports 0 when there is none.
parse() {
  case "$(basename "$1")" in
    pubspec.yaml) sed -nE 's/^version: *([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?[[:space:]]*$/\1 \3/p' | head -n 1 ;;
    package.json) sed -nE 's/^[[:space:]]*"version": *"([0-9]+\.[0-9]+\.[0-9]+)".*$/\1 0/p' | head -n 1 ;;
    *) sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?[[:space:]]*$/\1 \3/p' | head -n 1 ;;
  esac
}

changelog_entry() {
  awk -v heading="## [$1] - " '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
    END { exit !found }
  ' CHANGELOG.md
}

# The version already on the trunk, which is what a PR has to rise above, or
# empty when there is no baseline yet. Release tags are not used: nothing is
# published from CI, so there are none to compare with.
#
# An origin that is configured but unreachable is an error worth naming: a
# silent pass would skip the gate exactly when the network is the problem, and
# without this, set -e killed the script on the command substitution and
# printed git's raw "fatal:" with exit 128, so the ::error:: annotation this
# script exists to produce never appeared.
base_branch_version() {
  local branch=${VERSION_BASE_BRANCH:-main}
  local ref="refs/remotes/origin/$branch"
  local heads status
  if ! git remote get-url origin > /dev/null 2>&1; then
    echo "No origin remote yet, so there is nothing to compare against." >&2
    return 0
  fi

  # Reachable and the branch exists? 0. Reachable and it doesn't (a repo whose
  # trunk was never pushed)? 2, and there is simply no baseline. Anything else
  # is the network, and has to be said out loud.
  status=0
  heads=$(git ls-remote --exit-code --heads origin "$branch" 2>&1) || status=$?
  case "$status" in
    0) ;;
    2) echo "origin has no $branch yet, so there is nothing to compare against." >&2
       return 0 ;;
    *) fail "can't reach origin to read $branch's version: $(printf '%s' "$heads" | head -n 1)" ;;
  esac

  if ! git rev-parse --verify --quiet "$ref" > /dev/null; then
    # --depth=1 is a property of the fetch, not of the refspec: run against a full
    # local clone it writes .git/shallow and truncates the repository, silently, so
    # a later `git log origin/main..HEAD` reads across the cut. CI is already shallow
    # (actions/checkout defaults to fetch-depth 1), which is the only case that wants it.
    if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
      git fetch --quiet --depth=1 origin "+refs/heads/$branch:$ref"
    else
      git fetch --quiet origin "+refs/heads/$branch:$ref"
    fi
  fi

  if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$ref")" ]; then
    # On the trunk itself — the merge build — compare against the commit
    # before the merge. Two PRs opened together both pass the gate against the
    # same trunk; the first merge moves it, and without this the second would
    # ship as part of no release, leaving the trunk's code unreleased and the
    # artifact older than its own changelog. Needs fetch-depth 2 in CI; with a
    # depth-1 checkout there is no previous commit to read and the check is
    # skipped rather than guessed at.
    git rev-parse --verify --quiet HEAD~1 > /dev/null || return 0
    git show "HEAD~1:$file" 2>/dev/null | parse "$file"
    return 0
  fi
  git show "$ref:$file" 2>/dev/null | parse "$file"
}

file=$(version_file)
read -r name build < <(parse "$file" < "$file") || true
[ -n "${name:-}" ] || fail "$file: the version must look like x.y.z (x.y.z+N where the stores need a build number)"
build=${build:-0}

case "${1:-}" in
  name) echo "$name" ;;
  build) echo "$build" ;;
  notes) changelog_entry "$name" || fail "CHANGELOG.md has no '## [$name] - ' entry" ;;
  check)
    base_branch=${VERSION_BASE_BRANCH:-main}
    last_name=
    last_build=0
    # Command substitution, not `< <(…)`: a process substitution runs in a
    # subshell whose exit status the script never sees, so `fail` inside the
    # helper would print its annotation and then be ignored. Assigning lets
    # set -e stop the script, which is the whole point of naming the error.
    baseline=$(base_branch_version)
    read -r last_name last_build <<< "$baseline" || true
    last_build=${last_build:-0}

    if [ -n "$last_name" ]; then
      highest=$(printf '%s\n%s\n' "$last_name" "$name" | sort -V | tail -n 1)
      if [ "$name" = "$last_name" ] || [ "$highest" != "$name" ]; then
        fail "$base_branch was already on $last_name: raise the version above it (major, minor, or patch)"
      fi
      if [ "$build" != 0 ] && [ "$build" -le "$last_build" ]; then
        fail "$base_branch was already on build $last_build: raise the build number above it"
      fi
    fi
    changelog_entry "$name" > /dev/null || fail "CHANGELOG.md needs a '## [$name] - YYYY-MM-DD' entry"
    echo "Releasing $name+$build (was ${last_name:-nothing yet})."
    ;;
  *) usage ;;
esac
