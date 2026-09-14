# Releasing

Every PR merged to `main` is a release. The app version is the source of truth: `x.y.z` follows [Semantic Versioning](https://semver.org) (major for breaking changes, minor for new features, patch for fixes and everything else). Mobile stores also need a build number `N` (`x.y.z+N`) that grows by one with every release. `bash scripts/version.sh name` and `build` read them.

1. **Before merging**, bump the version on the branch with `/release [major|minor|patch]`, or by hand: edit the version and add a `## [x.y.z] - YYYY-MM-DD` entry to `CHANGELOG.md`. CI fails if the version isn't above the latest `vX.Y.Z` tag or has no changelog entry. Dependabot PRs are exempt and ship with the next release.
2. **On merge**, `release.yml` builds the release artifacts, tags the merge commit `vX.Y.Z`, and attaches them to a **draft** GitHub Release with the changelog entry as notes. A merge whose version is already tagged releases nothing.

Tags pushed by CI don't start other workflows, so any other platform's release workflow is run by hand from the Actions tab, or with `gh workflow run <workflow>.yml --ref vX.Y.Z`. Each checks that the tag matches the version.

<!-- Delete the sections below for platforms {{APP_NAME}} doesn't target. -->

## GitHub secrets and variables

Add them in GitHub → Settings → Secrets and variables → Actions, or with `gh secret set NAME` (it prompts for the value).

| Name | Kind | Used by | Value |
|---|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | secret | `claude.yml` | Output of `claude setup-token` |
| `ANDROID_KEYSTORE_BASE64` | secret | `release.yml` | Base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | secret | `release.yml` | Keystore password |
| `ANDROID_KEY_ALIAS` | secret | `release.yml` | Key alias, e.g. `upload` |
| `ANDROID_KEY_PASSWORD` | secret | `release.yml` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | `release.yml` | Google Cloud service-account JSON key with Play Console release access |
| `IOS_DIST_CERT_P12_BASE64` | secret | iOS release | Base64 of the Apple Distribution certificate (`.p12`) |
| `IOS_DIST_CERT_PASSWORD` | secret | iOS release | Password of the `.p12` |
| `APPSTORE_ISSUER_ID` | secret | iOS release | App Store Connect API issuer ID |
| `APPSTORE_KEY_ID` | secret | iOS release | App Store Connect API key ID |
| `APPSTORE_PRIVATE_KEY` | secret | iOS release | Full contents of the `.p8` API key |
| `APPLE_TEAM_ID` | variable | iOS release | 10-character Apple team ID |

## Protect `main`

Settings → Rules → Rulesets → New branch ruleset, target `main`:
- Require a pull request before merging.
- Require status checks to pass: the CI job names. Run CI on one PR first so the names show up in the picker.
- Block force pushes and deletion.
- Bypass list: Repository admin.

## Public repository

- **Secrets stay safe:** GitHub masks secret values in logs, and the workflows never print them. CI uses `pull_request`, not `pull_request_target`, so PRs from forks run without secrets. `claude.yml` runs only for `{{GITHUB_OWNER}}`.
- **Releases are drafts**, so nobody can download an artifact until you publish it.
- **Fork PRs:** Settings → Actions → General → "Approval for running fork pull request workflows" → "Require approval for all external contributors".
- **Commit emails are public.** Use the noreply address from GitHub → Settings → Emails: `git config user.email "<id>+{{GITHUB_OWNER}}@users.noreply.github.com"`.
- **License:** with no `LICENSE` file the code is "all rights reserved". Flathub and similar stores need a license that allows redistribution.
- A public repo gets free GitHub-hosted runners, macOS included, so CI can compile iOS on every PR.

## Privacy policy

Both mobile stores require a public privacy policy URL.
1. Settings → Pages → Deploy from a branch → `main` / `/docs`.
2. The policy is then live at `https://{{GITHUB_OWNER}}.github.io/{{REPO}}/privacy-policy`. Its contact is the GitHub Issues page, so no email address is published.

Every file in `docs/` gets published.

## One-time setup: Android

1. Create the upload keystore and back it up with its passwords. Losing it means asking Google for an upload-key reset.
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Base64 it into the clipboard for `ANDROID_KEYSTORE_BASE64` (PowerShell):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
   ```
3. Optional, for signed local builds: keep the keystore and a `key.properties` in the Android project, both gitignored.
4. In Play Console, create the app with package `{{APP_ID}}` and keep Play App Signing enabled.
5. **Upload the first AAB by hand** in Play Console → Testing → Internal testing. The API can't create an app's first release.
6. In Google Cloud, create a service account and a JSON key. In Play Console → Users and permissions, invite it with release permissions for this app. Save the JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
7. New personal developer accounts need a closed test with at least 12 testers for 14 days before production access. Confirm the current rule and start early.

Without the signing secrets, CI signs each APK with a throwaway debug key, which can't update an installed copy: back up in the app, uninstall, install, restore.

## One-time setup: iOS

1. Enroll in the Apple Developer Program.
2. Register the App ID `{{APP_ID}}` and create the app record in App Store Connect.
3. Create an Apple Distribution certificate. Without a Mac, use OpenSSL (it ships with Git for Windows):
   ```bash
   openssl genrsa -out dist.key 2048
   openssl req -new -key dist.key -out dist.csr -subj "/emailAddress=you@example.com/CN={{APP_NAME}}/C=US"
   ```
   Upload `dist.csr` at developer.apple.com → Certificates → Apple Distribution, download `distribution.cer`, and convert it:
   ```bash
   openssl x509 -inform DER -in distribution.cer -out dist.pem
   openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out dist.p12
   ```
4. Create an **App Store** provisioning profile for the App ID. Every extension (widget, share sheet) is a separate target: it needs its own App ID, its own profile, and an App Group on both App IDs if it reads the app's data.
5. In App Store Connect → Users and Access → Integrations, create an API key with the App Manager role.
6. Set `APPLE_TEAM_ID`, then run the iOS release workflow by hand with upload on before tagging a real release.

## One-time setup: Claude GitHub Action

Run `/install-github-app` from a `claude` terminal, or install the Claude GitHub app on the repo and add `CLAUDE_CODE_OAUTH_TOKEN`. Then comment `@claude <request>` on an issue or PR. Only `{{GITHUB_OWNER}}` can trigger it, and each run is capped at 15 turns.

## One-time setup: desktop stores

- **Microsoft Store:** reserve the name "{{APP_NAME}}" in Partner Center, and copy Product identity → Package/Identity/Name, Publisher, and PublisherDisplayName into the MSIX build variables. Upload the MSIX in a submission; the Store signs it.
- **Flathub:** the app ID must be a domain you control. `io.github.<org>.<App>` verified through a GitHub organization avoids a personal name or domain. Add a license, screenshots, and a `<release>` to the metainfo, then submit the manifest as a PR to `flathub/flathub`.
- **Mac App Store:** the app is sandboxed and reads or writes only files people pick. It needs Mac App Distribution and Mac Installer Distribution certificates and a Mac App Store profile.

## App icon and splash screen

Draw them from one committed source, generate the platform files with the stack's tools, and commit the results. The commands are in `docs/STACK_NOTES.md`.
