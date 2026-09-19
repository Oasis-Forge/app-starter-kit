---
name: kickoff
description: Turn a freshly copied app starter kit into this app's repo. Asks for the app's identity, fills every placeholder, scaffolds the stack, makes the first commit, and creates the GitHub repo. Use once, at the start of a new app or when adopting the kit into an existing repo.
---

Placeholders look like two opening braces, an UPPER_SNAKE name, and two closing braces. This file mentions them, so skip it in every search and replace.

1. Read `docs/STACK_NOTES.md` if it exists; it has the stack's fill-ins, scaffold command, and version location. Grep `\{\{[A-Z_]+\}\}` across the repo (files_with_matches, then content) to list what's left.
2. Infer what you can: `REPO` from the folder name, `GITHUB_OWNER` from `gh api user -q .login`, the dates from today (`DATE` as "14 September 2026", `DATE_ISO` as `2026-09-14`), and the stack versions from the toolchain. Ask the user the rest in one AskUserQuestion round, with free-text follow-ups where needed:
   - display name, one-sentence pitch, platforms in v1, target stores
   - product principles: three to five promises. Suggest the default set: free with banner and interstitial ads that never interrupt a task, and a one-time "Remove ads" purchase (`docs/PRODUCT_RULES.md` section 6); no analytics or tracking SDKs beyond the ad network; no account required; data leaves the device only through user-initiated export. Never offer "no ads" as a principle
   - store ID: reverse-DNS from the product, never the user's personal name (`com.<product>.app`). Say it's permanent after the first upload
   - public or private GitHub repo (default private)
   - the main competitor to study, if any
   Derive `SLUG` (kebab-case of the name).
3. Fill every placeholder with Edit. Command placeholders (`CMD_*`) come from `docs/STACK_NOTES.md` → Fill-ins; with no stack notes, ask. Add the stack's check commands to the allow list in `.claude/settings.json`. Delete what doesn't apply: `docs/RELEASING.md` sections and CI jobs for platforms that aren't targets, starter rules the user doesn't want. Grep again until nothing matches outside this file.
4. Scaffold the stack with the command in `docs/STACK_NOTES.md`, so it doesn't overwrite kit files. Set the version to `0.1.0` (`0.1.0+1` where there's a build number). Merge the stack's `.gitignore` with `/dist/`, `/coverage/`, `/store/`, signing files, and `.env*`.
5. Run the install command, then `/verify`. Fix what the scaffold broke.
6. Delete `.claude/skills/kickoff/`; it's done its job. Tick the finished Phase 0 items in `docs/ROADMAP.md`.
7. Commit on `main` with the message in a scratchpad file (`git commit -F`): `chore: start <name> from the app starter kit`. Create the repo: `gh repo create <REPO> --private --source=. --remote=origin --push` (`--public` if chosen). If `gh` isn't authenticated, run `git init` and `git remote add origin <url>`, and tell the user.
8. These are outward-facing, so ask before each and do only the approved ones: the `main` ruleset (`docs/RELEASING.md` → Protect `main`; it needs one CI run first so the check names exist), GitHub Pages from `/docs` for the privacy policy, and repo secrets.
9. Report in at most 5 lines: repo URL, what's ticked, and what's next: competitor research, `/spec` for the first areas, then Phase 1.
