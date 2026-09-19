---
name: new-app
description: Start a new app from the app starter kit. Asks what the app is and which platforms it targets, creates the project under the projects root, and runs /kickoff inside it. Use when the user wants to start a new app or project, or says to use the starter kit.
argument-hint: "[what the app is]"
---

What the user said it is: $ARGUMENTS

The kit lives at `D:\Desktop\projects\app-starter-kit`. If it isn't there, stop and say so rather than guessing: everything below depends on it.

1. **Check the kit is there and current.** `git -C "D:\Desktop\projects\app-starter-kit" status --short` and `log --oneline -1`. If it has uncommitted changes, say which and ask whether to use it as it stands — the new app is copied from the working tree, not from a commit, and `.kit-version` will record a commit that doesn't match what was copied.

2. **Ask what you can't infer**, in one `AskUserQuestion` round (never more than 4 questions), skipping anything `$ARGUMENTS` already answered:
   - **What is it?** One sentence: what it does and for whom. This becomes the pitch, so keep the user's own words.
   - **Platforms for v1?** Android and iOS / Android first, iOS later / iOS only / mobile plus desktop. This picks the stack and gets reused in step 6, so don't ask it again later.
   - **Project name.** Propose a kebab-case folder name derived from what they said and let them correct it: it becomes the folder, the repo name and `SLUG`, so it's awkward to change afterwards. Check `D:\Desktop\projects\<name>` doesn't already exist before proposing it.

3. **Pick the stack from the platforms, don't ask about it separately.** List what exists: `Get-ChildItem "D:\Desktop\projects\app-starter-kit\stacks" -Directory`. Mobile targets mean the `flutter` stack while it's the only one. If the platforms don't fit any stack the kit has, use `-Stack none` and say plainly that the app starts with the shared template only: the CI workflow is a stub that fails until it's filled in, and `docs/STACK_NOTES.md` is a skeleton to complete during `/kickoff`.

4. **Show what will happen, then do it.** Run the copy with `-DryRun` first and report the count, not the file list. Then:
   ```powershell
   D:\Desktop\projects\app-starter-kit\new-app.ps1 -Name <name> -Stack <stack>
   ```
   It writes `.kit-version` (the kit commit and every path the kit owns, so `-Update` can bring later fixes down) and runs `git init`. Adopting the kit into a repo that already exists is `-Existing` instead, which keeps every file that repo already has.

5. **Move into the new project.** Use this client's directory-change tool if it has one — in the desktop app it is a deferred tool, so search the tool list before concluding there isn't one. Failing that, tell the user to open `D:\Desktop\projects\<name>` and run `/kickoff` there, and stop. Don't run the rest from the kit's folder: `/kickoff` fills placeholders relative to the working directory, and pointed at the kit it would rewrite the kit itself.

6. **Run `/kickoff`.** It is the kit's own skill and now lives in the new project. It fills every placeholder, scaffolds the stack, makes the first commit and creates the GitHub repo. Tell it what you already collected — the pitch, the platforms and the name — so it asks only for what's left: principles, target stores, the store ID, public or private, and the competitor to study.

Report in at most 4 lines: where the project is, which stack, which kit commit, and that `/kickoff` is running or waiting to be run there.
