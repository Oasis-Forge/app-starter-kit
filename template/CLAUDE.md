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
- `bash scripts/rules.sh [ID]` lists rules nothing cites, and fails on a citation to a rule that does not exist

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
- **A release is the user's call, and most PRs are not one.** Put the change under `## [Unreleased]` in `CHANGELOG.md` and leave the version alone; CI passes a branch whose version stands still, and only checks one that moves. When the user asks for a release, `/release [major|minor|patch]` on the branch moves those entries under the new version (SemVer). Nothing is tagged. The local build goes to `dist/{{SLUG}}-X.Y.Z.*` (gitignored); rebuild it after any app change on the branch. It also writes the store's release notes, in every listing language, to `store/<store>/release-notes/X.Y.Z.txt`.
- **Nothing is published from CI and nothing is tagged:** no GitHub Release, no artifact, no store upload, no `vX.Y.Z`. `release.yml` builds and runs its gates as a *check*, and that is all it leaves behind. The artifact a store receives is built locally, signed from the project's gitignored keystore, and uploaded by a person — so check its signer before handing it over, because falling back to a debug key is silent (`docs/RELEASING.md`).
- Before a branch is merged: `/ship` (coverage of changed files, missing tests, docs, `/verify`, `/release`, drive it by hand, PR). The format check is the last thing before a commit, never a mid-session step.

## Workflow
- The repo lives under the `{{GITHUB_OWNER}}` organization — `github.com/{{GITHUB_OWNER}}/{{REPO}}` — never a personal account. Anything that takes an owner (`gh repo`, `gh api repos/...`, the Pages URL in the store listing) gets the org; `gh api user` answers with the person, which is a different thing and belongs only in the `@claude` actor gate and the noreply commit email.
- Start of an item: `git switch main`, `git pull --ff-only`, then branch from it. Never stack on an unmerged branch.
- Bundle related roadmap items into one PR by theme, and tick their boxes in that PR.
- Pass PR/issue bodies and commit messages through files (`gh pr create --body-file`, `git commit -F`): PowerShell 5.1 splits double quotes in here-strings.
- Before `gh workflow run --ref <branch>`, check `git ls-remote origin refs/heads/<branch>` matches `HEAD`.
- Anything that shows on screen gets driven by hand before the PR, and the PR says what was driven and what was only compiled. Put back any test data or setting changed on a device.
- A green open PR waits for the user; don't merge it.
- Competitors are for learning: observed behavior → what to learn → our better rule. Never copy their rules, text, or assets.
- End of session: `/handoff`. On "resume": read the handoff memory, `gh pr list`, `git log --oneline -3`.

## Token rules
- The session is what costs: every turn re-sends the whole conversation, so a short question late in a long session is not cheap. Compact or clear between roadmap items; `/handoff` is what makes that safe.
- Screenshots never leave the conversation once read. One per thing that has to be judged by eye (right-to-left layout, a chart, a theme); dump the UI as text for everything else.
- Don't open generated or platform folders unless the task is platform-specific (list in `docs/STACK_NOTES.md`).
- Grep with a `path`, then read line ranges. Never read lockfiles or generated project files whole; grep them.
- Don't spawn subagents for tasks touching fewer than ~5 files, except routine work (next rule). Use the `build-doctor` agent for long build logs.
- Routine work goes to a Sonnet subagent whatever its size — translations, doc, roadmap and changelog edits, releases. Decide the change in the main session and hand over the exact files and wording, then check the result with `git diff --stat` rather than by re-reading. A subagent's context never comes back; only its result does.
- Don't summarize diffs back; state the result in 1–3 lines.

## Adding a tool
Before installing a skill or plugin, answer five questions: does it run every session or only when called; does it ingest tool output and replay it later (a prompt-injection surface, and the one that matters most); does it spend tokens in the background; is its state reviewable in a diff or opaque; does it duplicate what `CLAUDE.md` and the docs already say. A skill — instructions loaded on demand — passes all five, so adding skills is close to free. A plugin with lifecycle hooks needs a real reason. Stale memory is worse than none: whatever a tool stored gets asserted later with the confidence of fact.

## Read on demand only
- `docs/ROADMAP.md`: phased plan and known bugs. Read when planning or picking up work.
- `docs/PRODUCT_RULES.md`: behavior rules with IDs. Read the relevant section before implementing or testing a feature.
- `docs/research/competitor-analysis.md`: what the competitor does, or a dated record that none was studied. Read before `/spec` either way — it decides whether a rules section opens with **They do** or with **Learn**.
- `docs/RELEASING.md`: signing, secrets, store release steps.
- `docs/STACK_NOTES.md`: stack commands, architecture that worked, traps, device drill.

## Gotchas
- If the repo is public: never commit secrets or personal data, and never print secrets in workflows.
- Store IDs are permanent after the first upload and carry no personal names: `{{APP_ID}}`.
- Store listing material (listing text, screenshots and graphics, data-safety answers and the scripts that make them, release notes) lives in `store/`, which is gitignored: one place in the repo, never Downloads.
- Quote paths in shell commands; project paths may contain spaces.
