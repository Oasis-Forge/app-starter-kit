# App starter kit

The docs, Claude Code setup, and GitHub workflows that took a real app from an empty repo to a tagged release in two days, generalized so every new app starts the same way. [PLAYBOOK.md](PLAYBOOK.md) explains the flow and why each piece exists.

## What's in it

```
CLAUDE.md                           Conventions for working on the kit itself (not the same as an app's)
skills/new-app                      Personal skill: "start a new app" → create the project → /kickoff
PLAYBOOK.md                         The flow: kickoff → research → rules → roadmap → build loop → release
new-app.ps1                         Copies the kit in; -Existing adopts, -Refresh updates tooling only, -Update follows the kit
tests/                              Checks the kit's own tooling against the ways it has been wrong before
.github/workflows/ci.yml            Runs those tests, shellchecks the scripts, lints every template workflow
template/                           Copied into every app
  CLAUDE.md                         Stack, commands, conventions, workflow, token rules, gotchas
  README.md  CHANGELOG.md           
  docs/ROADMAP.md                   Phases 0–5 with the items every app needs
  docs/PRODUCT_RULES.md             They do → Learn → rules with stable IDs; starter rules
  docs/RELEASING.md                 Versioning, secrets, branch protection, store one-time setup
  docs/privacy-policy.md            Store-ready policy, the one file GitHub Pages publishes
  docs/_config.yml                  Keeps the working docs off the domain the store listing points at
  docs/STACK_NOTES.md               Skeleton for a stack the kit has no overlay for; the overlay replaces it
  docs/research/competitor-analysis.md
  scripts/version.sh                Version read, CI bump check, changelog notes (pubspec/package.json/VERSION)
  scripts/check_public_docs.sh      Fails when a doc is neither excluded from Pages nor declared public
  scripts/rules.sh                  Rules nothing cites, and citations to rules that do not exist
  .claude/settings.json             Allow/deny lists
  .claude/skills/kickoff            Fill the placeholders, scaffold, first commit, GitHub repo (run once)
  .claude/skills/spec               Write a feature's rules before code
  .claude/skills/verify             Format + analyze + tests, failures only
  .claude/skills/release            SemVer bump + changelog + local artifacts + store release notes
  .claude/skills/ship               Pre-merge gate: coverage, drive by hand, release, PR
  .claude/skills/handoff            Save where work stopped before clearing the chat
  .claude/agents/build-doctor.md    Long build logs → root cause, on Haiku
  .github/                          CI with version check, release on merge, PR template, Dependabot, @claude
stacks/flutter/files/               Overlay: Flutter CI, Android release, format hook, settings, STACK_NOTES.md
  .claude/skills/emulator           Drive the Android emulator as text (tool/emu.sh), snapshot before each test
  .claude/skills/l10n-add           One JSON file → a message in every ARB file (tool/add_messages.dart)
  .claude/skills/coverage           Only the missed lines in the files a branch changed (tool/coverage_gaps.dart)
  tool/check_permissions.sh         RUN-2 gate: the release build declares exactly the allowed permissions
```

## Start a new app

Ask Claude, from anywhere:

> start a new app from the starter kit

The `/new-app` skill asks what you're building and which platforms v1 targets, picks the stack from that, creates the project, moves into it and runs `/kickoff` — which asks for the rest (principles, stores, store ID, public or private, the competitor to study). Install it once with:

```powershell
Copy-Item -Recurse -Force .\skills\new-app "$env:USERPROFILE\.claude\skills\"
```

It's a personal skill rather than a project one because it has to be available before the project exists. Re-run that copy after pulling the kit to pick up changes to it.

### Or by hand

1. From this folder:
   ```powershell
   .\new-app.ps1 -Name habit-tracker -Stack flutter
   ```
   It resolves `template/` and the stack's `files/` into one set (the stack wins), copies it into `D:\Desktop\projects\habit-tracker`, runs `git init`, and writes `.kit-version` recording the kit commit and every path the kit owns. Use `-Stack none` for a stack the kit doesn't cover yet, `-DryRun` to print what would be copied without writing, and `-Existing` to adopt the kit into a repo that already exists (below).
2. Open Claude Code in the new folder and run `/kickoff`. It asks for the name, pitch, principles, platforms, and store ID; fills every placeholder; scaffolds the stack; makes the first commit; and creates the private GitHub repo.
3. Continue with [PLAYBOOK.md](PLAYBOOK.md) stage 2 (research).

## Placeholders

`/kickoff` replaces every `{{NAME}}` in the copied files and greps until none are left.

| Placeholder | Example |
|---|---|
| `APP_NAME` | Habit Tracker |
| `SLUG` | habit-tracker (file names, `dist/` artifacts) |
| `APP_ID` | com.habittracker.app (permanent; no personal names) |
| `PITCH` | One sentence: what it does and for whom |
| `PRINCIPLES` | no tracking, no account; data leaves the device only through user export |
| `STACK`, `FLUTTER_VERSION` | Flutter 3.47.4 / Dart 3.13.3 |
| `PLATFORMS`, `STORES` | Android, iOS, desktop / Google Play, the App Store |
| `GITHUB_OWNER`, `REPO` | your-github-handle, habit-tracker |
| `DATE`, `DATE_ISO` | 14 September 2026, 2026-09-14 |
| `CMD_*` | Commands from the stack's `docs/STACK_NOTES.md` → Fill-ins |

## Keep an established app's tooling current

For an app the kit never made, or one that wants the fixed tooling without the rest of the kit:

```powershell
.\new-app.ps1 -Name an-established-app -Stack flutter -Refresh -DryRun
.\new-app.ps1 -Name an-established-app -Stack flutter -Refresh
```

It looks only at kit files the repo **already has**, and adds nothing. No docs set, no CI workflow, no second roadmap. Differences land as `.kit-new` beside the file, with the same rule as below: **read both, then merge by hand**. Once none are left, run it again and `.kit-version` lands, so `-Update` works from then on.

This is usually what an established app wants. Adopting the kit into one that already has its own docs and workflows is the exception, not the default.

## Adopt the kit into an app that already exists

```powershell
.\new-app.ps1 -Name an-existing-app -Stack flutter -Existing -DryRun   # read this first
.\new-app.ps1 -Name an-existing-app -Stack flutter -Existing
```

It never overwrites a file the repo already has, and sorts every one of them:

| | |
|---|---|
| `added` | the repo didn't have it |
| `kept` | identical to the kit's already |
| `theirs` | differs, and the app fills this one in for itself (`CLAUDE.md`, `README.md`, a skill with commands in it) — expected |
| `differs` | differs, and the kit wrote every line of its own copy. The kit's version lands beside it as `.kit-new` |

**`differs` means read both, not replace.** The kit can only tell that its copy has no `{{PLACEHOLDER}}` in it. It cannot tell that yours holds settings of your own — and a file with no placeholder anywhere still can. Both of these were real, in one repo, on the first adoption:

- `scripts/version.sh` with `VERSION_FILE=${VERSION_FILE:-Hisscore/pubspec.yaml}`, because that app lives in a subdirectory. Overwriting points every version command at a file that isn't there.
- `.github/dependabot.yml` with `directory: /Hisscore` against the kit's `/`. Overwriting points Dependabot at a directory with no manifest.

So merge by hand, keep what is yours, and delete the `.kit-new`.

### When the difference is permanent: `.kit-ignore`

Both examples above are forever — that app's Flutter project is in a subdirectory and always will be. Without somewhere to say so, they'd be reported as an owed merge on every run and the stamp would never land, so the app could never reach `-Update` at all. A `.kit-ignore` in the app says it once:

```
# Files this app keeps its own version of.
scripts/version.sh        # VERSION_FILE points into a subdirectory: the app is not at the repo root
.github/dependabot.yml    # directory: matches, for the same reason
```

They're still listed on every run, with the reason, so a deliberate divergence stays visible. They just stop counting as work outstanding. **Anything not listed still holds the stamp back** — declaring one file doesn't excuse the rest. `-Update` honours the same list: when the kit changes a declared file, it says so and writes nothing.

**`.kit-version` is not written while anything is `differs`**, because a stamp would make `-Update` answer "already up to date" over exactly the files still waiting to be read. Once none are left, run `-Existing` again and the stamp lands.

An established app usually needs more than this. The kit assumes the app is at the repo root, and it adds docs (`docs/ROADMAP.md`, `docs/RELEASING.md`) that may duplicate ones the repo keeps elsewhere. Read the dry run and delete what you don't want before committing — or skip the additions entirely and take only the files you already have, which is often all an established app wants.

## Update an app the kit already made

A fix to the kit does nothing for the apps already built from it, so `.kit-version` records the commit each one came from:

```powershell
.\new-app.ps1 -Name habit-tracker -Update
```

It diffs the recorded commit against the kit's `HEAD` and touches only what changed since:

- Files the kit owns outright (`scripts/version.sh`, `tool/`, hooks, un-filled skills) are **copied over**.
- Files `/kickoff` filled in with the app's own name, commands and version are **never overwritten**. The kit's new version lands beside them as `<file>.kit-new` to merge by hand, then delete.
- Files named in `.kit-ignore` are **left alone**, and listed with their reason when the kit changed them.
- A file that is new in the kit is **added as it is**. If it still carries `{{PLACEHOLDERS}}`, the run says so: fill them in by hand from `CLAUDE.md` and `docs/STACK_NOTES.md`.
- `.kit-version` records the new commit at once. A `.kit-new` still on disk is reported on every later run until it is deleted, so a pending merge can't be forgotten. The stamp can't wait for the merge instead: nothing can tell a merged copy from an unread one, and waiting meant the same `.kit-new` was offered again on every run, for good.

Run it on a branch and read `git diff` before committing. `.kit-new` files are scratch: they belong in neither a commit nor the ignore file.

## Keep the kit alive

The kit began as a snapshot of the first app built this way. When a project teaches something (a CI trap, a test that proved nothing, a workflow rule, a tool that cost more than it saved), fix it here too, so the next app starts with it — then `-Update` the apps that already exist, so the fix reaches them as well. Keep it about the method: no app's name, data, or domain belongs in the kit.

To add a stack, create `stacks/<stack>/files/` with `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.claude/settings.json`, an optional format hook, and `docs/STACK_NOTES.md` (fill-ins, scaffold command, traps). `new-app.ps1` picks it up by folder name.
