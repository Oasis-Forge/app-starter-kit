# App starter kit

The docs, Claude Code setup and GitHub workflows every new app starts from. `README.md` is what it contains; `PLAYBOOK.md` is the method it encodes.

**Nothing here runs in production, and that is the whole difficulty.** Everything under `template/` and `stacks/` is content to be *copied into* an app, not code this repo executes. A bug in it is invisible until an app pays for it, which is how the kit shipped CI that failed on line one of every PR, a version script that silently truncated the local clone, and an emulator tool that reported screens it had never read.

## Commands

- `bash tests/test-<name>.sh` and `powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-new-app.ps1` — the kit's own tests. Run the ones near what you changed; CI runs all of them.
- `shellcheck --severity=warning template/scripts/*.sh stacks/*/files/tool/*.sh tests/*.sh`
- `.\new-app.ps1 -Name <name> -Stack flutter -ProjectsRoot <temp> -DryRun` — see what a copy would produce without writing.

## Editing template/ and stacks/

- A file here is what **every future app** starts with. Write it for a project that does not exist yet: no app's name, data, domain or screenshots.
- `template/` is the shared base; `stacks/<stack>/files/` is copied over it and wins on any path they share. Stack-specific content in `template/` is a bug — `-Stack none` gets it too.
- `{{UPPER_SNAKE}}` placeholders only. A new one needs a row in `README.md`'s table, and a `CMD_*` needs a Fill-ins row in every stack; `tests/test-placeholders.sh` fails otherwise.
- A templated file (one that still has `{{...}}`) is one the app rewrites, so `-Update` never overwrites an app's copy of it — it lands as `.kit-new` to merge by hand. Prefer putting logic in a file with no placeholders, so a fix can reach existing apps outright.
- Changing a path that `template/` files reference means changing every reference: `grep -rn` before and after.

## Anything the kit ships that can run, gets a test

- `tests/` is the only place the kit's own tooling is ever executed. A change to `new-app.ps1`, `scripts/`, or a stack's `tool/` comes with a test in the same PR.
- **A test has to fail against the old behaviour.** Write it, run it against the previous version, and say in the PR that you did. A test that only passes on the new code proves nothing — that check has caught vacuous tests here more than once.
- Reproduce a bug before fixing it. Every finding in this repo's history was confirmed by running it, not by reading.
- Fixtures live under `mktemp -d`. Guard against an empty path before any `git -C "$dir"` or `rm -rf`: a fixture that half-failed once deleted this repo's own origin remote.

## Workflow

- Branch from a freshly pulled `main`, one theme per PR. Never stack on an unmerged branch.
- Commit messages and PR bodies go through files (`git commit -F`, `gh pr create --body-file`): PowerShell 5.1 splits double quotes in here-strings.
- Say in the PR what you ran and what you only read. "Not run" is a normal line; a checked box that nobody verified is worse than an empty one.
- **Stop at the open PR.** The user reviews and merges.
- The kit has no release and no version. It is copied by commit, and `.kit-version` in each app records which one.

## A fix here does not reach the apps already built

`new-app.ps1 -Name <app> -Update` re-copies what changed since the commit that app recorded. When a fix matters to a shipped app, say so in the PR so it can be pulled down; otherwise it only helps the next one.

## Subagents

The conventions in `template/CLAUDE.md` describe an app, not this repo — including its Sonnet rule, which covers routine work like translations and changelog edits. Judgement work here (tracing shell under `set -euo pipefail`, reasoning about a workflow race, deciding whether a finding is real) stays on the strong model. Hand down a tier for genuinely mechanical passes, and say which model you used if it matters to the result.

## Gotchas

- **Windows PowerShell 5.1, not `pwsh`.** No `&&`, no ternary, different default encodings. CI tests under 5.1 because that is what the kit is run with.
- Never derive a relative path by cutting a root off by its length. The caller's spelling and the provider's are not always the same one, and an 8.3 short path made `-Existing` overwrite a repo's own files.
- Bash heredocs here mangle `\\` and can choke on PowerShell content. For a `.ps1`, use the Write tool or `Set-Content`, not `cat <<'EOF'`.
- `.gitattributes` keeps `*.sh` at LF. Anything CI runs with `bash` must stay LF.
- `set -e` does not fire on a failing `A` in `A && B`. Verify a shell assumption by running it rather than recalling it.
