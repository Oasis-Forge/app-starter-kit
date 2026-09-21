#!/usr/bin/env bash
# Every app the kit makes lives under the Oasis-Forge organization, so {{GITHUB_OWNER}}
# is the organization and {{GITHUB_USER}} is the person. They are not interchangeable,
# and each way of swapping them fails quietly rather than loudly:
#
#   - `github.actor` is the login of whoever acted, and is never an organization. A gate
#     comparing it to the org matches nobody, so @claude answers no one and the workflow
#     still reports success, because a job whose `if` is false is a job that was skipped.
#   - The noreply commit email is a person's address. Built from the org it reaches
#     nothing, and the address is in every commit before anyone checks.
#   - `gh repo create <REPO>` with no owner creates the repo on the personal account.
#     By the time that shows, the remote is pushed and the store listing points at it.
#
#   bash tests/test-repo-owner.sh
set -uo pipefail

kit=$(cd "$(dirname "$0")/.." && pwd)
cd "$kit" || exit 1
failures=0

ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; failures=$((failures + 1)); }

# Nothing to compare against is not a pass: these checks only mean something while the
# line they guard still exists, and a rename would otherwise make them all vacuous.
present() {
  [ -n "$2" ] && return 0
  bad "$1"
  return 1
}

echo "owner vs user in $kit"

echo ""
echo "the @claude gate compares against a person"
before=$failures
gates=$(grep -rn 'github\.actor[[:space:]]*==' template stacks || true)
if present "no github.actor gate found at all — did claude.yml move?" "$gates"; then
  while IFS= read -r line; do
    case "$line" in
      *'{{GITHUB_USER}}'*) ;;
      *) bad "actor gate compares against something other than {{GITHUB_USER}}: $line" ;;
    esac
  done <<< "$gates"
fi
[ "$failures" -eq "$before" ] && ok "every actor gate uses {{GITHUB_USER}}"

echo ""
echo "the noreply commit email is a person's"
before=$failures
mails=$(grep -rn 'users\.noreply\.github\.com' template stacks || true)
if present "no noreply address found — did RELEASING.md drop it?" "$mails"; then
  while IFS= read -r line; do
    case "$line" in
      *'{{GITHUB_USER}}'*) ;;
      *) bad "noreply address is not built from {{GITHUB_USER}}: $line" ;;
    esac
  done <<< "$mails"
fi
[ "$failures" -eq "$before" ] && ok "the noreply address uses {{GITHUB_USER}}"

echo ""
echo "/kickoff creates the repo under the organization"
before=$failures
creates=$(grep -rn 'gh repo create' template || true)
if present "/kickoff no longer creates the repo — check step 7" "$creates"; then
  while IFS= read -r line; do
    case "$line" in
      *'gh repo create Oasis-Forge/'*) ;;
      *) bad "gh repo create is not namespaced to the org, so it lands on the personal account: $line" ;;
    esac
  done <<< "$creates"
fi
# The owner is a constant, not something to read off whichever account gh is signed in
# as. Match the derivation itself, not the two names in one line: step 2 names both, and
# has to, because the person is still inferred that way.
owner_from_account=$(grep -nF 'GITHUB_OWNER` from `gh api user' \
  template/.claude/skills/kickoff/SKILL.md || true)
[ -n "$owner_from_account" ] && bad "/kickoff infers GITHUB_OWNER from the signed-in account: $owner_from_account"
[ "$failures" -eq "$before" ] && ok "the org owns the repo, and /kickoff does not ask the account who that is"

echo ""
echo "the person's handle never stands where an owner belongs"
before=$failures
# github.com/<owner>/<repo>, gh api repos/<owner>/<repo>, <owner>.github.io: all three
# address the account that owns the repo, which is the org.
misplaced=$(grep -rnE '(github\.com/|repos/)\{\{GITHUB_USER\}\}|\{\{GITHUB_USER\}\}\.github\.io' template stacks || true)
if [ -n "$misplaced" ]; then
  while IFS= read -r line; do
    bad "{{GITHUB_USER}} used as the repo's owner, which points at a personal account: $line"
  done <<< "$misplaced"
fi
[ "$failures" -eq "$before" ] && ok "owner positions all use {{GITHUB_OWNER}}"

echo ""
if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed."; exit 1; fi
echo "All checks passed."
