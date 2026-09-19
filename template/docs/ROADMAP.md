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
- [ ] **Start the store paperwork now, because it is measured in weeks while everything else is measured in days.** Create and verify the developer accounts, reserve `{{APP_ID}}` in each console, and create the app record. It is the only item here that cannot be hurried later: identity verification takes days, and a new personal Play account then needs a closed test running for 14 continuous days with at least 12 testers before it can even apply for production. Write the date that test must start to hit the launch you want, and put it here: <!-- closed test starts by: DATE -->
  Everything in Phase 4 depends on it. The one-time purchase can only be tested against a real product in a real console, on a build installed from a real track.

## Phase 1: Foundations
Groundwork every feature builds on. Settle everything that shapes stored data now, before real users have any.
- [ ] Strict lints (unawaited futures, declared return types, consistent quotes, const where possible).
- [ ] Inject the storage layer and every device service into the state layer, so tests use an in-memory database and no-op fakes.
- [ ] Migration scaffold: an ordered list of schema steps run on upgrade, with a test that upgrades the oldest schema.
- [ ] Reliable writes: write first, then change state; on failure roll back and show an error.
- [ ] Localization scaffolding: every UI string in the message files from the start, even with one language.
- [ ] Schema step: record rules on every table: UUIDs, timestamps, soft delete (REC-1, REC-2, DEL-1).
- [ ] The stored shapes that can't change once users have data: integer money in thousandths if the app handles money (MONEY-1), a picked date as a local calendar date that survives a time-zone change (DATE-1), and built-in items stored by ID with translatable labels rather than stored text (DATA-1).
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
- [ ] Privacy policy published, and updated for every feature that touches user data. Decide how it is served: GitHub Pages needs the repo to be public, or a paid plan (`docs/RELEASING.md` → Privacy policy).
- [ ] `LICENSE` decided and committed. With no file the code is "all rights reserved", which is a choice worth making rather than defaulting into — and a store that redistributes the build, Flathub among them, needs one that permits it.
- [ ] The release build declares only the permissions the store listing admits to; the release workflow dumps the built artifact's permissions and fails on any it doesn't expect (RUN-2). Write the list against a real build, not from memory, and check both directions: a permission the app needs and lost is as much a bug as one a plugin added.
- [ ] Desktop packaging, if targeted: macOS sandbox entitlements, Windows MSIX, Linux Flatpak.

## Phase 4: Before release
<!-- Scope added after Phase 2, each item with its decision date. Languages come first, so every later PR adds all languages as it goes. The first-run walkthrough comes last, so it shows finished features. -->
- [ ] **Languages** (LANG-1–LANG-6)
- [ ] **Ads and the purchase that removes them** (ADS-1–ADS-9, PAY-1–PAY-6): banners, interstitials, and "Remove ads". The item that turns an offline app online, so do it after everything else has settled. It brings the network permission with it and rewrites the privacy policy, the data-safety form, the privacy labels, the first-run privacy page and the store listing in the same release (ADS-6). Ships with the one-time purchase, which needs a product in both consoles and can only be tested on an internal track — so this item is blocked on the Phase 0 store-paperwork item, not on anything in Phase 5. If the accounts aren't verified by the time you reach this, the code is finished and untestable.
- [ ] **First-run setup and walkthrough** (RUN-3, RUN-4): last.

## Phase 5: Google Play
<!-- One phase per store, in the order they ship, so one store's paperwork and review never hold up another. Delete the phases for stores {{APP_NAME}} doesn't target. -->
- [ ] Finish the Android one-time setup in `docs/RELEASING.md`: signing, contact details, payments profile, secrets. The account itself and the app record were done in Phase 0.
- [ ] Internal testing from a release, including in-app products bought by licence testers.
- [ ] Closed test finished and production access applied for. It should already be running: the 14 continuous days with at least 12 testers started in Phase 0, and the application asks what the testers did and what changed as a result, not just how many there were.
- [ ] Store listing in every language from `store/play/` (text, screenshots, feature graphic, icon), privacy policy URL, data safety form, and `app-ads.txt`.
- [ ] EU trader status, then apply for production and promote the release.

## Phase 6: Desktop stores
- [ ] Microsoft Store and Flathub, if targeted (`docs/RELEASING.md`).

## Phase 7: Apple
- [ ] iOS and macOS together: TestFlight from a release, App Store privacy labels, listings in every language, then App Review.

## Phase 8: After launch
Shipping is where an app starts costing attention rather than work. These recur; date each one as it is done, and treat a missed deadline as a bug.
- [ ] Each release: read the store's crash and performance figures and the new reviews, before starting the next item. `docs/RELEASING.md` → When a release is bad.
- [ ] **Target API level**, annually. Play stops showing an app to new devices when it falls behind, and the deadline is the same date every year for everyone. Put the date here: <!-- target API deadline: DATE -->
- [ ] Declarations that expire or go stale: the data-safety form, the privacy labels, EU trader status, and the ad network's account details. Re-check each at the same time as the target API bump, and whenever a feature changes what is collected (ADS-6).
- [ ] The support address is read by someone. Both stores publish one, so it receives mail whether or not it is watched.

## After v1
<!-- Ideas deliberately left out of v1, one line. -->

## Known bugs
<!-- Found and not fixed yet: what, where, and the rule it breaks. -->
