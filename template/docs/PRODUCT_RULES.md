# Product rules

_{{DATE}}._

This file defines how {{APP_NAME}} behaves: the calculations, defaults, and edge cases behind each screen. Where a competitor was studied (see `docs/research/competitor-analysis.md`), a section says what they do, what we take from it, and our rule: we learn from their app; we don't copy its rules. Where none was, a section starts from the user need instead.

- Rule IDs (`DATA-1`) are stable: never renumber or reuse one. A dropped rule stays, struck through, with its date and reason. Tests, code comments, PRs, and roadmap items reference them.
- A rule is testable: a number, a default, an order, an edge case. "Entry is fast" isn't a rule; "a basic entry takes about four taps" is.
- "Not verified" marks competitor behavior we saw only partly.
- Every rule keeps the product principles in `CLAUDE.md`: {{PRINCIPLES}}.

## Section shape

`/spec <area>` writes a section in this shape:

> ## N. Area
>
> **They do:** what the competitor does, in our words. Parts we couldn't check: not verified.
>
> **Learn:** the user need behind it, and where they fall short.
>
> - **AREA-1** Our rule.

With no competitor studied (`docs/research/competitor-analysis.md` records that, dated), a section has no **They do** and opens with **Learn**, written from the user need itself. Never write a **They do** from what a competitor is assumed to do: the rules below it would then cite a guess as observed fact.

The sections below are starter rules that held up in an earlier app. Keep, change, or delete each one, and record the choice under Decisions.

## 1. Data foundations

**Learn:** undo, trash, backup merge, sync, and translations all depend on these being right before any user data exists.

- **REC-1** Every record has `created_at` and `updated_at`.
- **REC-2** Every record ID is a UUID v4, so records from a backup or another device never collide. Built-in defaults use fixed IDs instead, so the same default matches across devices.
- **DEL-1** Deleting sets `deleted_at`; it doesn't remove the row. Deleted records count nowhere: totals, charts, search, or export.
- **DEL-2** Delete needs no confirmation. A snackbar offers Undo for about 5 seconds. Deleted items stay in the trash for 30 days, then get purged on app start.
- **DATA-1** User-facing names of built-in items (default categories, default accounts) are translatable labels referenced by ID, never stored text.
- **MONEY-1** If the app handles money: amounts are integers in thousandths of a unit (`12.50` → `12500`), so sums never drift and every ISO currency fits. The record's type carries the sign.
- **DATE-1** A date the user picks is a local calendar date. It stays on that date if the device's time zone changes later.

## 2. Backup and export

**Learn:** a raw database file breaks across schema versions, and defaults that send data off the device cost trust.

- **BAK-1** A backup is a file with the app version and the schema version, saved or shared only when the user chooses to.
- **BAK-2** Before a restore replaces or merges anything, the app saves an automatic backup of the current data.
- **BAK-3** Merge matches records by ID (REC-2); the later `updated_at` wins, deletions included (DEL-1). The app then shows how many records were added, updated, and unchanged.
- **BAK-4** A backup from a newer schema is refused with a message to update the app. Older backups are migrated with the app's own schema steps.
- **BAK-5** Exported files use ISO dates and plain decimals with a `.`, whatever the language. Spreadsheet text starting with `=`, `+`, `-`, or `@` gets a leading apostrophe.

## 3. First run and trust

**Learn:** asking for an account, permissions, or cloud backup up front costs trust before the app has earned any.

- **RUN-1** An empty screen explains itself with one clear first action.
- **RUN-2** The release build declares no permission a shipped feature doesn't need, so the store's data-safety answers stay true. The release workflow checks it.
- **RUN-3** The first launch asks only what the device can't tell (for example the language and currency) on one page, preselected from the locale. Permissions are requested when the feature that needs them is first used, and everything else works if they're refused.
- **RUN-4** A walkthrough of up to four pages follows setup. Every page has Skip, it respects reduce motion, it can be replayed from Settings, and it shows once. An update on a device that already has data skips setup and the walkthrough.

## 4. Languages

**Learn:** a translated app only feels native when numbers, dates, plurals, search, and layout direction are right too. A cut-off label looks broken.

- **LANG-1** The app follows the device language and falls back to English. Settings offers "System default" and each language in its own name. A change applies without a restart.
- **LANG-2** Every user-facing text comes from the message files, including notifications, widgets, and generated files. Plurals and variable parts are ICU messages, never pieced-together strings. CI fails on a missing message or mismatched placeholders.
- **LANG-3** Dates, numbers, and amounts follow the chosen language's format. Files the app writes don't (BAK-5).
- **LANG-4** Search ignores case and accents in every language, including the Turkish dotted and dotless i.
- **LANG-5** Right-to-left languages mirror the layout: navigation, lists, swipe actions, arrows. Amounts, numbers, and expressions stay left to right inside them.
- **LANG-6** Translations are machine-made in the same PR that adds or changes the English message. Widget tests render the main screens in every language on a phone-size screen at 1.3× text size, and fail on overflow.

## 5. App lock

**Learn:** private data needs a lock, but a forgotten app PIN locks people out of their own records.

- **LOCK-1** App lock is off by default and uses the device's own biometrics or screen lock, so the app never stores a PIN. Turning it on or off asks for authentication first.
- **LOCK-2** With app lock on, the app asks at launch and after at least a minute in the background, and hides its content until unlocked. Notifications and widgets show no private data.
- **LOCK-3** If the device no longer has biometrics or a screen lock, app lock turns itself off instead of locking the data away.

## 6. Ads and paying
<!-- Every app is free and carries ads: banners and interstitials, with a one-time purchase that removes them. Name the screens and the natural breaks when you /spec this section. -->

**Learn:** ads pay for a free app, but a banner that covers a row, moves a button under a finger, or an interstitial that interrupts an entry is what makes a free app feel cheap — and the money only comes if people keep the app. A subscription to *not* see something is resented; what is sold must already work.

- **ADS-1** Two formats: banners (ADS-2, ADS-3) and interstitials (ADS-9). No app-open ads, no pop-ups, no rewarded video, and no ad of any kind on the entry forms, the walkthrough, setup, dialogs, widgets, or generated files.
- **ADS-2** A slot reserves its height before it asks for an ad, so an arriving ad never shifts what is under a finger, and an empty slot shows nothing at all: no frame, no placeholder.
- **ADS-3** A slot sits outside the scrolling content and above the system navigation bar. Put it in the screen's bottom bar rather than at the end of the body, and the rule holds by construction instead of by padding.
- **ADS-4** No ad is requested until setup and the walkthrough are finished (RUN-3, RUN-4) and consent has been answered, so the first minutes of the app belong to the app. None loads while the app is locked (LOCK-2).
- **ADS-5** Where the law asks for it (the EEA, the UK, Switzerland), the network's own consent form appears before the first request, and Settings keeps a row to change the answer later. Refusing means non-personalised ads, never a nag or a feature withheld. A consent lookup that fails leaves the user unasked and requests nothing.
- **ADS-6** What the ad SDK collects is declared in the store data-safety form, the privacy labels, and the privacy policy, in the same plain words as the rest. The release that adds ads rewrites all of them, and the first-run privacy page, together.
- **ADS-7** The ad SDK is handed nothing from the app: no user records, and no keywords derived from them. One place in the code decides whether any ad shows, banner or interstitial, so an ad-free build and a paid ad-free app are the same code path.
- **ADS-8** Only a release build asks with the real ad units; every other build uses the network's test units. Serving live ads from a development build is how an ad account gets suspended. IDs are not secrets — they ship in the binary — so they live in the repo, and a test fails if the copies in the code and the platform manifests drift apart.
- **ADS-9** An interstitial shows only at a natural break the rules name, after a task is finished: never at launch, on resume, mid-entry, on back navigation, or between a tap and what it asked for. It is capped (at most one every few minutes, and none in the first session), loaded ahead so it never delays the next screen, and skipped if it isn't ready. Closing it lands exactly where the user was going.
- **PAY-1** Ads are bought away by a one-time purchase ("Remove ads"), not a subscription, and it removes banners and interstitials alike. It follows the store account, "Restore purchases" sits beside the price, and the app asks the store what is owned at each launch, so a refund or a family-shared purchase lands without a reinstall.
- **PAY-2** Prices come from the store, in the buyer's currency. Never hard-coded, and nothing to do with any currency setting in the app.
- **PAY-3** Nothing is sold before it exists. A tier that isn't finished is shown as "coming soon", with no price and no button.
- **PAY-4** Nothing that already works moves behind a payment. Paying removes ads and adds what is new.
- **PAY-5** Selling is quiet: one row in Settings and one small target on the slot itself. No interstitial upsell, no countdown, no trial that lapses into a charge.
- **PAY-6** A purchase that fails or is left pending never charges twice and never leaves the app half-paid: the app finishes every purchase with the store whatever the outcome, and the slots stay as they were until it is confirmed. A store with no such product configured is a real state — show "nothing to sell yet" rather than a button that only fails.

## Decisions
<!-- Numbered and dated answers to open questions, citing the rules they settle. -->
1. ({{DATE}}) <!-- e.g. "Title stays, as an optional field (ADD-1)." -->

## Roadmap impact
<!-- Rules that change the data model or the build order, and where they land in docs/ROADMAP.md. Schema changes go in Phase 1. -->
