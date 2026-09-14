# Product rules

_{{DATE}}._

This file defines how {{APP_NAME}} behaves: the calculations, defaults, and edge cases behind each screen. Each section says what the competitor does (see `docs/research/competitor-analysis.md`), what we take from it, and our rule. We learn from their app; we don't copy its rules.

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

## Decisions
<!-- Numbered and dated answers to open questions, citing the rules they settle. -->
1. ({{DATE}}) <!-- e.g. "Title stays, as an optional field (ADD-1)." -->

## Roadmap impact
<!-- Rules that change the data model or the build order, and where they land in docs/ROADMAP.md. Schema changes go in Phase 1. -->
