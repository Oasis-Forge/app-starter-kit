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
| `ANDROID_KEY_ALIAS` | variable | `release.yml` | Key alias, e.g. `upload` (the default). A *secret* here would be worse than useless: GitHub masks a secret’s value everywhere it appears in a log, so `upload` turns `upload-keystore.jks` into `***-keystore.jks` |
| `ANDROID_KEY_PASSWORD` | secret | `release.yml` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | `release.yml` | Google Cloud service-account JSON key with Play Console release access |
| `IOS_DIST_CERT_P12_BASE64` | secret | iOS release | Base64 of the Apple Distribution certificate (`.p12`) |
| `IOS_DIST_CERT_PASSWORD` | secret | iOS release | Password of the `.p12` |
| `APPSTORE_ISSUER_ID` | secret | iOS release | App Store Connect API issuer ID |
| `APPSTORE_KEY_ID` | secret | iOS release | App Store Connect API key ID |
| `APPSTORE_PRIVATE_KEY` | secret | iOS release | Full contents of the `.p8` API key |
| `APPLE_TEAM_ID` | variable | iOS release | 10-character Apple team ID |

The release workflow is the one job that decodes the keystore and holds the Play key, so the third-party actions in it are pinned to a commit SHA with the version in a trailing comment (Dependabot still bumps them). A major-version tag is mutable: whoever controls the action can move it onto new code, and that code would run with those secrets. Actions under `actions/` stay on their major tag — same trust as the runner itself.

## Protect `main`

Settings → Rules → Rulesets → New branch ruleset, target `main`:
- Require a pull request before merging.
- Require status checks to pass: the CI job names. Run CI on one PR first so the names show up in the picker.
- Block force pushes and deletion.
- Bypass list: empty, so even the admin merges through a PR, or Repository admin if you want an emergency override.

Check it with `gh api repos/{{GITHUB_OWNER}}/{{REPO}}/rulesets`. The classic branch-protection endpoint answers 404 for a branch protected only by a ruleset, which looks like no protection at all.

## Public repository

- **Secrets stay safe:** GitHub masks secret values in logs, and the workflows never print them. CI uses `pull_request`, not `pull_request_target`, so PRs from forks run without secrets. `claude.yml` runs only for `{{GITHUB_OWNER}}`.
- **Releases are drafts**, so nobody can download an artifact until you publish it.
- **Fork PRs:** Settings → Actions → General → "Approval for running fork pull request workflows" → "Require approval for all external contributors".
- **Commit emails are public.** Use the noreply address from GitHub → Settings → Emails: `git config user.email "<id>+{{GITHUB_OWNER}}@users.noreply.github.com"`.
- **License:** with no `LICENSE` file the code is "all rights reserved". Flathub and similar stores need a license that allows redistribution.
- A public repo gets free GitHub-hosted runners, macOS included, so CI can compile iOS on every PR.

## Privacy policy

Both mobile stores require a public privacy policy URL.
1. Settings → Pages → Deploy from a branch → `main` / `/docs`. **Pages on a private repository needs a paid plan.** `/kickoff` makes the repo private by default, so before the store needs the URL, either make the repo public (read "Public repository" above first) or host the policy somewhere else and put that URL in the listing. Deciding this late is what turns it into a blocker.
2. The policy is then live at `https://{{GITHUB_OWNER}}.github.io/{{REPO}}/privacy-policy`.
3. **Ads:** the ad network reads `app-ads.txt` from the **root** of the domain in the store listing's Website field, not from the repo's path. Serve it from the organization's own Pages repo (`{{GITHUB_OWNER}}/{{GITHUB_OWNER}}.github.io`): one line per ad account, shared by every app. AdMob can only verify it once the app is public.

**Pages publishes every file in `docs/`**, on the same domain the store listing points at — the roadmap, the product rules, this runbook and the competitor research included. `docs/_config.yml` excludes them, and CI runs `scripts/check_public_docs.sh` so a doc added later can't quietly go up with them. Add each new file there as either excluded or public; nothing is published by default.

## One-time setup: Android

1. Create the upload keystore and back it up with its passwords. Losing it means asking Google for an upload-key reset.
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Base64 it into the clipboard for `ANDROID_KEYSTORE_BASE64` (PowerShell):
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
   ```
3. Wire the signing config into the Android build (`docs/STACK_NOTES.md` → Scaffold). The scaffold does not generate one, so without it the release build is debug-signed even with every secret set, and Play rejects the upload for not matching the upload certificate. The release workflow reads the built bundle's own certificate and fails on a debug one, rather than trusting that the secrets were used. For signed local builds, keep the keystore and a `key.properties` in the Android project too, both gitignored.
4. In Play Console, create the app with package `{{APP_ID}}` and keep Play App Signing enabled.
5. **Upload the first AAB by hand** in Play Console → Testing → Internal testing. The API can't create an app's first release.
6. In Google Cloud, create a service account and a JSON key. In Play Console → Users and permissions, invite it with release permissions for this app. Save the JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
7. **Production access** for a new personal developer account is an application, not a counter. At least 12 testers opted in for 14 continuous days is the entry condition, but the form also asks what the testers did, what they said, and what changed as a result — so run the closed test as a real test and keep the notes. Confirm the current rule in Play Console, and start it before the features are finished: this is the longest-lead item in the whole roadmap.
8. **Contact details.** Play shows two public emails: the store listing's support email (App support) and the developer account's email (About the developer, on every app). Give both one dedicated support address, and keep the Play Console login private. A personal account also shows its legal name and country there; only an organization account (it needs a D-U-N-S number) shows the brand instead.
9. **Payments profile → Public merchant profile:** the merchant name is the publisher, never a personal name, with the same support email.
10. **In-app products:** a one-time product needs a purchase option (type Buy). Add the testers' Google accounts under Settings → Licence testing (account level, not per app), so their test purchases cost nothing. Products only show in a build installed from a Play testing track, once the product is Active.
11. **EU trader status** (Digital Services Act): an app with ads or purchases makes you a trader, and Play then shows your address, phone and email to EU users. Declare it before applying for production; a virtual office address keeps a home address private. Apple asks the same for the EU App Store.
12. **Release notes** for every release come from `/release`, in `store/play/release-notes/X.Y.Z.txt`. All store listing material lives in `store/` (gitignored).

Without the signing secrets, CI signs each APK with a throwaway debug key, which can't update an installed copy: back up in the app, uninstall, install, restore.

## One-time setup: iOS

**The kit ships no iOS release workflow.** CI compiles iOS unsigned on every PR, and that is all. The steps below are the account and certificate work, which takes weeks and is worth starting early; the six `IOS_*`/`APPSTORE_*` secrets in the table above are what a workflow will need once you write one, not settings something already reads. Until then, archive and upload from a Mac or from App Store Connect by hand.

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
6. Set `APPLE_TEAM_ID`. When there is an iOS release workflow, run it by hand with upload on once, before it is trusted with a real release.

## One-time setup: Claude GitHub Action

Run `/install-github-app` from a `claude` terminal, or install the Claude GitHub app on the repo and add `CLAUDE_CODE_OAUTH_TOKEN`. Then comment `@claude <request>` on an issue or PR. Only `{{GITHUB_OWNER}}` can trigger it, and each run is capped at 15 turns.

## One-time setup: desktop stores

- **Microsoft Store:** reserve the name "{{APP_NAME}}" in Partner Center, and copy Product identity → Package/Identity/Name, Publisher, and PublisherDisplayName into the MSIX build variables. Upload the MSIX in a submission; the Store signs it.
- **Flathub:** the app ID must be a domain you control. `io.github.<org>.<App>` verified through a GitHub organization avoids a personal name or domain. Add a license, screenshots, and a `<release>` to the metainfo, then submit the manifest as a PR to `flathub/flathub`.
- **Mac App Store:** the app is sandboxed and reads or writes only files people pick. It needs Mac App Distribution and Mac Installer Distribution certificates and a Mac App Store profile.

## App icon and splash screen

Draw them from one committed source, generate the platform files with the stack's tools, and commit the results. The commands are in `docs/STACK_NOTES.md`.
