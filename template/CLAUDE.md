# {{APP_NAME}}

{{PITCH}} Built with {{STACK}}. Targets {{PLATFORMS}}.

## Commands (use the quiet forms)
- `{{CMD_INSTALL}}`
- `{{CMD_ANALYZE}}`
- `{{CMD_TEST_FILE}}` while iterating; `{{CMD_TEST_ALL}}` once at the end
- `{{CMD_FORMAT}}`: rarely needed if the format hook runs on every edit
- `{{CMD_BUILD_RELEASE}}` builds the release artifact; `{{CMD_RUN}}` runs the app
- `/verify` runs format check + analyze + tests and reports failures only
- `bash scripts/version.sh name|build|check|notes` reads the version, runs CI's bump check, prints the changelog entry

## Architecture
<!-- Fill in as Phase 1 lands: one line per folder or key file, plus the data flow (screen → state → storage). Update it in the PR that changes the structure. -->

## Conventions
- Product principles: {{PRINCIPLES}}. Every feature keeps them.
- Behavior is defined in `docs/PRODUCT_RULES.md` with stable rule IDs (`ADD-3`). Code comments, tests, PRs, and roadmap items cite them. No rule yet? `/spec <area>` before coding.
- State lives in the state layer; screens stay presentational. Don't add a second state library.
- Schema change = append a migration step and test the upgrade; never edit a merged step.
- Device services (notifications, auth, files, widgets) sit behind an interface. Tests get a no-op fake by default; only the app's entry point builds the real one.
- Every model/state change gets a test. Tests assert what the user sees (text on screen, contents of a file), never just that output exists.
- Feature order: model → migration → state → screen → test → analyze.
- One branch per theme, PR to `main`; CI (`.github/workflows/ci.yml`) must pass.
- Every merged PR is a release: `/release [major|minor|patch]` on the branch (SemVer + `CHANGELOG.md` entry; CI checks it). The merge tags `vX.Y.Z` and drafts a GitHub Release. The local build goes to `dist/{{SLUG}}-X.Y.Z.*` (gitignored); rebuild it after any app change on the branch.
- Before a branch is merged: `/ship` (coverage of changed files, missing tests, drive it by hand, release, PR).

## Workflow
- Start of an item: `git switch main`, `git pull --ff-only`, then branch from it. Never stack on an unmerged branch.
- Bundle related roadmap items into one PR by theme, and tick their boxes in that PR.
- Pass PR/issue bodies and commit messages through files (`gh pr create --body-file`, `git commit -F`): PowerShell 5.1 splits double quotes in here-strings.
- Before `gh workflow run --ref <branch>`, check `git ls-remote origin refs/heads/<branch>` matches `HEAD`.
- Anything that shows on screen gets driven by hand before the PR, and the PR says what was driven and what was only compiled. Put back any test data or setting changed on a device.
- A green open PR waits for the user; don't merge it.
- Competitors are for learning: observed behavior → what to learn → our better rule. Never copy their rules, text, or assets.
- End of session: `/handoff`. On "resume": read the handoff memory, `gh pr list`, `git log --oneline -3`.

## Token rules
- Don't open generated or platform folders unless the task is platform-specific (list in `docs/STACK_NOTES.md`).
- Grep with a `path`, then read line ranges. Never read lockfiles or generated project files whole; grep them.
- Don't spawn subagents for tasks touching fewer than ~5 files. Use the `build-doctor` agent for long build logs.
- Don't summarize diffs back; state the result in 1–3 lines.

## Read on demand only
- `docs/ROADMAP.md`: phased plan and known bugs. Read when planning or picking up work.
- `docs/PRODUCT_RULES.md`: behavior rules with IDs. Read the relevant section before implementing or testing a feature.
- `docs/research/competitor-analysis.md`: what the competitor does. Read before `/spec`.
- `docs/RELEASING.md`: signing, secrets, store release steps.
- `docs/STACK_NOTES.md`: stack commands, architecture that worked, traps, device drill.

## Gotchas
- If the repo is public: never commit secrets or personal data, and never print secrets in workflows.
- Store IDs are permanent after the first upload and carry no personal names: `{{APP_ID}}`.
- Quote paths in shell commands; project paths may contain spaces.
