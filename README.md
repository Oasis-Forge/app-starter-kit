# App starter kit

The docs, Claude Code setup, and GitHub workflows that took Monthly Expenses from an empty repo to v1.4 in two days, generalized so every new app starts the same way. [PLAYBOOK.md](PLAYBOOK.md) explains the flow and why each piece exists.

## What's in it

```
PLAYBOOK.md                         The flow: kickoff → research → rules → roadmap → build loop → release
new-app.ps1                         Copies the kit into D:\Desktop\projects\<name>
template/                           Copied into every app
  CLAUDE.md                         Stack, commands, conventions, workflow, token rules, gotchas
  README.md  CHANGELOG.md           
  docs/ROADMAP.md                   Phases 0–5 with the items every app needs
  docs/PRODUCT_RULES.md             They do → Learn → rules with stable IDs; starter rules
  docs/RELEASING.md                 Versioning, secrets, branch protection, store one-time setup
  docs/privacy-policy.md            Store-ready policy, served by GitHub Pages
  docs/research/competitor-analysis.md
  scripts/version.sh                Version read, CI bump check, changelog notes (pubspec/package.json/VERSION)
  .claude/settings.json             Allow/deny lists
  .claude/skills/kickoff            Fill the placeholders, scaffold, first commit, GitHub repo (run once)
  .claude/skills/spec               Write a feature's rules before code
  .claude/skills/verify             Format + analyze + tests, failures only
  .claude/skills/release            SemVer bump + changelog + local artifact
  .claude/skills/ship               Pre-merge gate: coverage, drive by hand, release, PR
  .claude/skills/handoff            Save where work stopped before clearing the chat
  .claude/agents/build-doctor.md    Long build logs → root cause, on Haiku
  .github/                          CI with version check, release on merge, PR template, Dependabot, @claude
stacks/flutter/files/               Overlay: Flutter CI, Android release, format hook, settings, STACK_NOTES.md
```

## Start a new app

1. From this folder:
   ```powershell
   .\new-app.ps1 -Name habit-tracker -Stack flutter
   ```
   It copies `template/`, then the stack's `files/` over it, into `D:\Desktop\projects\habit-tracker` and runs `git init`. Use `-Stack none` for a stack the kit doesn't cover yet. For an existing repo, add `-Existing`: only files that don't exist yet are copied.
2. Open Claude Code in the new folder and run `/kickoff`. It asks for the name, pitch, principles, platforms, and store ID; fills every placeholder; scaffolds the stack; makes the first commit; and creates the private GitHub repo.
3. Continue with [PLAYBOOK.md](PLAYBOOK.md) stage 2 (research).

## Placeholders

`/kickoff` replaces every `{{NAME}}` in the copied files and greps until none are left.

| Placeholder | Example |
|---|---|
| `APP_NAME` | Monthly Expenses |
| `SLUG` | monthly-expenses (file names, `dist/` artifacts) |
| `APP_ID` | com.monthlyexpenses.app (permanent; no personal names) |
| `PITCH` | One sentence: what it does and for whom |
| `PRINCIPLES` | no ads, no tracking, no account; data leaves the device only through user export |
| `STACK`, `FLUTTER_VERSION` | Flutter 3.47.4 / Dart 3.13.3 |
| `PLATFORMS`, `STORES` | Android, iOS, desktop / Google Play, the App Store |
| `GITHUB_OWNER`, `REPO` | haskalach, habit-tracker |
| `DATE`, `DATE_ISO` | 14 September 2026, 2026-09-14 |
| `CMD_*` | Commands from the stack's `docs/STACK_NOTES.md` → Fill-ins |

## Keep the kit alive

The kit is a snapshot of monthly-expense-app on 14 September 2026. When a project teaches something (a CI trap, a test that proved nothing, a workflow rule), fix it here too, so the next app starts with it.

To add a stack, create `stacks/<stack>/files/` with `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.claude/settings.json`, an optional format hook, and `docs/STACK_NOTES.md` (fill-ins, scaffold command, traps). `new-app.ps1` picks it up by folder name.
