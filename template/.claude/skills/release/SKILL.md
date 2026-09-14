---
name: release
description: Bump the app version (SemVer, plus a build number where the stores need one) and add its CHANGELOG.md entry on the current feature branch, so merging the PR releases it. Use when finalizing a PR.
argument-hint: "[major|minor|patch]"
---

Version bump for this branch: $ARGUMENTS (default: choose from the changes).

Every PR merged to `main` is a release: `release.yml` tags `vX.Y.Z` and drafts a GitHub Release with the changelog entry and the artifacts. CI (`bash scripts/version.sh check`) fails a PR whose version isn't above the latest tag or has no changelog entry.

1. Stop if on `main`. Run `git fetch --tags --quiet`; the latest release is the first line of `git tag --list "v*" --sort=-v:refname`. Read the current version with `bash scripts/version.sh name` and `build`. With no tag yet, keep the version and only write its entry. If the branch is already above the tag, adjust the level if needed and update its entry.
2. Bump the tag's version per SemVer and reset the lower parts (`1.4.2` → `1.5.0`):
   - `major`: breaks existing users, e.g. data or backups that older versions can't read, or a removed feature.
   - `minor`: new user-facing features or behavior.
   - `patch`: fixes, and changes users don't notice (dependencies, docs, CI, refactors).
   With a build number (`x.y.z+N`), set `N` to the tag's build number + 1. Update every place the stack keeps the version (`docs/STACK_NOTES.md`).
3. In `CHANGELOG.md`, add `## [x.y.z] - YYYY-MM-DD` right below `## [Unreleased]`, and move anything listed under Unreleased into it. Write it from `git log --oneline origin/main..HEAD`: Added / Changed / Fixed, short, in words a user would use. Say what they can now do, not which class changed.
4. Commit `chore(release): vX.Y.Z` with the message in a file (`git commit -F`), and put the version in the PR title or description.
5. Build the release artifact in the background with `{{CMD_BUILD_RELEASE}}`, copy it to `dist/{{SLUG}}-X.Y.Z.<ext>` (gitignored), check the built version matches, and give the user the path. Rebuild it after any later app change on the branch.
