# Roadmap

Goal: build the full v1 feature set, then ship {{APP_NAME}} to {{STORES}}. Behavior is defined in `docs/PRODUCT_RULES.md`; items cite its rule IDs. Group related items into larger PRs; CI must pass. Tick items in the same PR that completes them, and date every decision that adds, moves, or drops one.

## Phase 0: Tooling
Set up before the first feature, while it's cheap.
- [ ] `CLAUDE.md`, `.claude/` settings, format hook, `/spec` `/verify` `/release` `/ship` `/handoff` skills, `build-doctor` agent (`/kickoff`)
- [ ] GitHub repo, Dependabot, CI (checks + a build for every mobile platform) green on a first PR
- [ ] `main` ruleset: PR required, the CI checks required, no force pushes or deletion (`docs/RELEASING.md`)
- [ ] Every merged PR is a release: the CI version check, then a tag and a draft GitHub Release on merge. `v0.1.0` is the first.
- [ ] The release workflow runs once by hand without secrets (unsigned artifacts, nothing published)
- [ ] Privacy policy draft served by GitHub Pages
- [ ] Competitor research (`docs/research/competitor-analysis.md`) and the first product rules (`docs/PRODUCT_RULES.md`)

## Phase 1: Foundations
Groundwork every feature builds on. Settle everything that shapes stored data now, before real users have any.
- [ ] Strict lints (unawaited futures, declared return types, consistent quotes, const where possible).
- [ ] Inject the storage layer and every device service into the state layer, so tests use an in-memory database and no-op fakes.
- [ ] Migration scaffold: an ordered list of schema steps run on upgrade, with a test that upgrades the oldest schema.
- [ ] Reliable writes: write first, then change state; on failure roll back and show an error.
- [ ] Localization scaffolding: every UI string in the message files from the start, even with one language.
- [ ] Schema step: record rules on every table: UUIDs, timestamps, soft delete (REC-1, REC-2, DEL-1).
- [ ] <!-- Schema steps from "Roadmap impact" in PRODUCT_RULES.md, each with its rule IDs. -->
- [ ] Tests: model round-trip, each migration step, the core calculation rules, widget tests for the main flows.
- [ ] Platform decision: which targets ship in v1 and which come after (dated).

## Phase 2: Features (in dependency order)
<!-- One bold-titled item per feature area, citing its rule IDs. Order them so each item's data exists before anything that reads it. -->
- [ ] **Settings:** <!-- theme, formats, the defaults other features read -->
- [ ] **<Feature>:** <!-- what, with rule IDs (ABC-1–ABC-4) -->
- [ ] **Delete, undo, trash** (DEL-1, DEL-2)
- [ ] **Backup, restore, export** (BAK-1–BAK-5): after the last schema step, so the format covers every table.
- [ ] **App lock**, if the data is private (LOCK-1–LOCK-3)
- [ ] **First run:** empty states with one clear first action (RUN-1)

## Phase 3: Store readiness
- [ ] Display name "{{APP_NAME}}" on every platform: launcher label, bundle names, window titles.
- [ ] Launcher icons and splash screen, generated from one committed source.
- [ ] Store IDs, permanent after the first upload and free of personal names: `{{APP_ID}}`.
- [ ] Privacy policy published, and updated for every feature that touches user data.
- [ ] The release build declares only the permissions the store listing admits to; the release workflow dumps the built artifact's permissions and fails on any it doesn't expect (RUN-2). Write the list against a real build, not from memory, and check both directions: a permission the app needs and lost is as much a bug as one a plugin added.
- [ ] Desktop packaging, if targeted: macOS sandbox entitlements, Windows MSIX, Linux Flatpak.

## Phase 4: Before release
<!-- Scope added after Phase 2, each item with its decision date. Languages come first, so every later PR adds all languages as it goes. The first-run walkthrough comes last, so it shows finished features. -->
- [ ] **Languages** (LANG-1–LANG-6)
- [ ] **Ads and the purchase that removes them** (ADS-1–ADS-8, PAY-1–PAY-6), if the app carries ads: the item that turns an offline app online, so do it after everything else has settled. It brings the network permission with it and rewrites the privacy policy, the data-safety form, the privacy labels, the first-run privacy page and the store listing in the same release (ADS-6). Ships with the one-time purchase, which needs a product in both consoles and can only be tested on an internal track — so the developer accounts have to exist first.
- [ ] **First-run setup and walkthrough** (RUN-3, RUN-4): last.

## Phase 5: Google Play
<!-- One phase per store, in the order they ship, so one store's paperwork and review never hold up another. Delete the phases for stores {{APP_NAME}} doesn't target. -->
- [ ] Finish the Android one-time setup in `docs/RELEASING.md`: signing, the developer account, contact details, payments profile, secrets.
- [ ] Internal testing from a release, including in-app products bought by licence testers.
- [ ] Closed test: new personal developer accounts need at least 12 testers for 14 days before production access. Confirm the current rule in Play Console and start early.
- [ ] Store listing in every language from `store/play/` (text, screenshots, feature graphic, icon), privacy policy URL, data safety form, and `app-ads.txt` if the app shows ads.
- [ ] EU trader status, then apply for production and promote the release.

## Phase 6: Desktop stores
- [ ] Microsoft Store and Flathub, if targeted (`docs/RELEASING.md`).

## Phase 7: Apple
- [ ] iOS and macOS together: TestFlight from a release, App Store privacy labels, listings in every language, then App Review.

## After v1
<!-- Ideas deliberately left out of v1, one line. -->

## Known bugs
<!-- Found and not fixed yet: what, where, and the rule it breaks. -->
