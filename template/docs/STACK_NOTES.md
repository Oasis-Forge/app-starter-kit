# Stack notes: {{STACK}}

Read on demand: the fill-ins `/kickoff` uses, and the traps this stack has cost time on.

A stack the kit already covers replaces this file wholesale (`stacks/<stack>/files/docs/STACK_NOTES.md`). This skeleton is what a project on a stack the kit doesn't cover yet starts from: fill it in during `/kickoff`, and when it has earned its keep, move it into `stacks/<stack>/files/` in the kit so the next app on this stack starts with it.

## Fill-ins

Every `CMD_*` placeholder in the copied files comes from here. Use the quiet forms: the output lands in the conversation.

| Placeholder | Value |
|---|---|
| `STACK` | name and version, e.g. `Flutter 3.47.4 / Dart 3.13.3` |
| `CMD_INSTALL` | fetch dependencies |
| `CMD_ANALYZE` | the linter or type checker |
| `CMD_FORMAT` | format the source |
| `CMD_FORMAT_CHECK` | fail if anything is unformatted, without writing |
| `CMD_TEST_FILE` | run one test file |
| `CMD_TEST_ALL` | run every test, failures only |
| `CMD_COVERAGE` | run the tests with coverage |
| `CMD_BUILD_RELEASE` | build the release artifact, and where it lands |
| `CMD_RUN` | run the app |

SDK: where the toolchain lives if it isn't on `PATH`, and the version CI pins.

## Scaffold

The command that creates the project **into an existing directory**, so it doesn't overwrite the kit's files. Then the one-time edits:

- Where the version lives, set to `0.1.0` (`0.1.0+1` where a store needs a build number). `scripts/version.sh` reads `pubspec.yaml`, `package.json` or `VERSION`; set `VERSION_FILE` if it's somewhere else.
- The application/bundle identifier set to `{{APP_ID}}` exactly, everywhere it appears.
- `.gitignore`: add `/dist/`, `/coverage/`, `/store/`, and any signing material.
- Strict lints, and whatever the release build needs signing.
- Fill in `.github/workflows/ci.yml` (it ships as a stub that fails on purpose) and `.github/dependabot.yml` with this ecosystem.

## Don't read

The generated and platform folders: reading them costs tokens and teaches nothing. List them here so `CLAUDE.md` → Token rules has something to point at.

## Architecture that worked

<!-- One line per folder, filled in as Phase 1 lands. -->

## Traps

<!-- What cost time once, and the rule that came out of it. One line each. -->

## Device drill

<!-- How to install and drive the built artifact by hand, as text rather than screenshots (`/ship` step 5). -->
