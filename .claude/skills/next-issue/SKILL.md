---
name: next-issue
description: Implement the next issue of the Focused Task roadmap (#38) end to end - release the last merged PR (signed bundle, tag, GitHub Release) and report it with the Play Store texts, pick the next issue, implement it with tests, fix or file what you find on the way, bump the version, write the CHANGELOG and the Play Store release notes, and open the PR. Use when asked to "continue with the roadmap", "do the next issue", "work on my issues", /next-issue, or when the user says a roadmap PR was merged ("I've merged it") or asks for the release / Play Store files.
---

# Next roadmap issue

Implements one issue from the roadmap in #38, from picking it to an open PR that is ready to release. Read `CLAUDE.md` first. It is the source of truth; this skill only says in what order to do things. One issue per run, one issue per PR.

## 0. Release the last merged PR and report (always first)

Run this at the start of every run, and on its own when the owner says a roadmap PR was merged or asks for the release files. Its job is to release what was merged and give the owner everything for Play Console **without being asked**, in the fixed report below. The owner has asked for this to happen automatically: when the checks in step 0.1 pass, tag and publish without asking again.

### 0.1 Check that it is ready to release

```bash
git checkout main && git pull && git fetch --tags
grep '^version' pubspec.yaml          # e.g. 1.15.0+25 -> X.Y.Z = 1.15.0, versionCode N = 25
git tag -l "vX.Y.Z"                   # empty = merged but not released yet: continue; otherwise skip to step 1
gh pr list --state merged --limit 1 --json number,title,mergedAt,mergeCommit   # the PR that brought X.Y.Z
gh pr checks <pr>                                                               # every check of the PR passed
gh run list --branch main --limit 3 --json headSha,status,conclusion,workflowName  # the run on the merge commit
```

- The PR must be **merged**, every PR check must have **passed**, and the CI run on the merge commit on `main` must be **completed with success**. If that run is still running, wait for it (`gh run watch <id>` in the background). If anything failed, don't release: say what failed in the report (section 3) and fix it first.
- **Signing:** check only that `android/key.properties` exists (`test -f`). Never read, print or copy it or the keystore. If it is missing, stop and tell the owner; never build or publish an unsigned or debug-signed release.

### 0.2 Build, tag and publish

1. **Build** both in the background (a few minutes each): `flutter build appbundle --release` and `flutter build apk --release`. Copy them to the repo root as `focused_task-X.Y.Z.aab` and `focused_task-X.Y.Z.apk` (gitignored).
2. **Check the signatures** without printing certificate details:
   - AAB: `keytool -printcert -jarfile focused_task-X.Y.Z.aab` has an `Owner:` line that is not `CN=Android Debug`.
   - APK: `apksigner verify --print-certs` from the SDK's `build-tools` (on Windows run the `.bat` through `cmd //c`). `keytool` can't read v2 signatures. The signer DN must not be `CN=Android Debug`.
3. **Tag** the merge commit: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
4. **GitHub Release:** extract the "GitHub Release notes" section of `release-notes/vX.Y.Z.md` into a temp file in the scratchpad, then `gh release create vX.Y.Z focused_task-X.Y.Z.apk focused_task-X.Y.Z.aab --title "vX.Y.Z" --notes-file <file>`.
5. **Verify the release:** `gh release view vX.Y.Z --json url,tagName,isDraft,assets`, plus `gh release list --limit 1` (it must be *Latest*). Check that it isn't a draft, both assets are there with their sizes, and the tag points to the merge commit.
6. **Tick the issue in #38** (`- [x] **n.** #<issue> (PR #<pr>, vX.Y.Z)`).

Only release the **latest** version, even if older ones were never released; mention those in section 5 instead.

### 0.3 Report to the owner

End with exactly these five sections, in this order, in the reply itself (not just file paths):

1. **Release file**: a clickable link to the local `focused_task-X.Y.Z.aab` with its size and the Play Console release name `X.Y.Z (N)`. Below it, the direct download link of the `.aab` asset from the GitHub Release.
2. **Release text** for Play Console's "Release notes" field, in **one** code block, in exactly this format (the texts of `android/fastlane/metadata/android/{en-US,de-DE}/changelogs/N.txt`, unchanged), with the character count of each language below the block (at most 500):

   ```
   <en-US>
   • …
   </en-US>
   <de-DE>
   • …
   </de-DE>
   ```

   If `release-notes/vX.Y.Z.md` says the store listing changed, add the changed `full_description.txt` / `short_description.txt` per language in further code blocks under this section.
3. **Summary**: a few plain bullets about what changed for the user, from the CHANGELOG section. Then a confirmation with the real facts: the PR (link) was merged into `main` (merge commit), the number of PR checks that passed, the result of the CI run on `main` (link), and the local test numbers from the PR. Anything that did not pass goes here, plainly.
4. **GitHub Release**: confirm it with the facts from step 0.2.5: the release URL, the tag and its commit, *Latest*, not a draft, both assets with their sizes, the notes taken from the CHANGELOG, and both files signed with the release key.
5. **Next**: what else may need doing, for example:
   - upload the `.aab` and paste the texts in Play Console, then delete the local `.apk`/`.aab`;
   - versions that were merged but never released;
   - uncommitted changes (and where they will go);
   - follow-up issues created in this run;
   - owner actions from issues (secrets, settings);
   - the next roadmap issue and whether something blocks it.

Then go on with step 1, unless the owner only asked for the release.

## 1. Pick the issue

```bash
gh issue view 38
gh pr list --state open
```

- Take the **first unchecked** roadmap entry. Read its *Order* section (`gh issue view <n>`): every *Depends on* issue must be closed.
- **An open roadmap PR blocks you** if the next issue depends on it, or if both change the database schema (each bumps `schemaVersion`). Then stop. Tell the user which PR must be merged and released first, and give them the post-merge commands from step 8. Only issues listed under "Can run in parallel" in #38 may go ahead. Even then, base the version bump on the higher version, so the two PRs don't release the same number.
- If the user named an issue, take that one, but still check its dependencies.

## 2. Understand before you write

- Read the whole issue: *Context*, *Tasks*, *Acceptance criteria*, *Definition of done*.
- Read the code the issue touches, plus the shared test fakes in `test/helpers/`, before you design anything. Check what already exists, for example columns, enums, notification channels or ids the spec says to "add". Earlier issues often prepared them.
- Decide the open questions yourself with the product principles in `CLAUDE.md` (simple, local-first, trustworthy time data, calm UI). Write each decision in the PR body. Ask the user only if a decision would change data irreversibly or contradicts the spec.

## 3. Implement

```bash
git checkout main && git pull
git checkout -b issue-<number>-<slug>
```

Follow `CLAUDE.md` strictly. The points people miss most:

- Pure domain logic (no Flutter or Drift imports), notifiers take their dependencies through `ref.watch` in `build()`, and time comes from `clock.now()`.
- New settings belong in `SettingsState` and `SettingsNotifier` (persisted with `shared_preferences`), and behind a small provider that tests can override (like `focusGoalProvider` and `intervalSettingsProvider`). When a notifier reads a new provider, existing tests that build it without preferences break. Add the override there.
- Every string goes into **both** `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, then run `flutter gen-l10n`.
- Schema change: bump `schemaVersion`, add a migration step and a migration test, run `dart run build_runner build --delete-conflicting-outputs`. A doc comment on a Drift column is copied into `app_database.g.dart`, so regenerate after changing one too.
- Notification ids live in `NotificationIds`. Routes use `AppRoutes` constants.
- A new repository goes into `FakeTaskRepository` too, and its provider override next to every `categoryRepositoryProvider.overrideWithValue(...)` in the tests (one `sed` does it); otherwise widget tests open a real database.
- New screens need a 360 px phone layout and `PopScope`. Closing a desktop window during focus must close open sessions.

## 4. Test

- **Unit tests** for domain logic and the repository (`AppDatabase(NativeDatabase.memory())`).
- **Notifier tests** in `fakeAsync` with the shared fakes. Cover every acceptance criterion by name.
- **Widget tests** for every new screen or section (`localizedApp` / `localizedRouterApp`).
- **Extend `integration_test/app_test.dart`** for UI changes.
- Every bug fix comes with a regression test.

## 5. Verify

Start the slow integration run in the background first, then run the rest:

```bash
flutter test integration_test -d windows        # background, takes a few minutes
dart format $(git ls-files -co --exclude-standard 'lib/*.dart' 'test/*.dart' 'integration_test/*.dart' 'tool/*.dart' | grep -v -e '\.g\.dart$' -e '^lib/l10n/generated/')
flutter analyze                                  # must report 0 issues
flutter test                                     # must pass
```

If platform code changed, also build the affected targets (`flutter build web`, `flutter build windows`). Report the real numbers in the PR, for example "238 tests passed".

## 6. Things you find on the way

The user wants these handled, not just mentioned:

- **Small and related** (a stale doc, a hard-coded route, a missing test, a wrong comment): fix it in this PR and list it under "Also" in the PR body.
- **Bigger or unrelated**: open an issue in the same format as the roadmap issues, then add it to #38 in the right phase. Don't tick or reorder the existing entries.

  ```bash
  gh issue create --title "<title>" --label "agent-ready,<area>" --milestone "<milestone>" --body-file <file>
  ```

  The body has *Order* (depends on / blocks / step in #38), *Context*, *Tasks*, *Acceptance criteria* and the standard *Definition of done* (copy it from an existing issue).
- **Your work changes a later issue's spec** (new state, a screen it must respect, a done prerequisite): edit that issue's body (`gh issue view <n> --json body -q .body`, then edit and `gh issue edit <n> --body-file`).
- Update `README.md` (features, architecture, routes) and `CLAUDE.md` when behaviour or architecture changed.

## 7. Prepare the release (in the PR)

1. **Version** in `pubspec.yaml`: feature → minor, fix/docs/tech debt → patch, incompatible data change → major. **Always add 1 to the build number after `+`**; it is the Android `versionCode`.
2. **`CHANGELOG.md`**: a new `## [x.y.z] - YYYY-MM-DD` section at the top with *Added / Changed / Fixed / Removed* and the issue number on every line.
3. **Play Store "What's new"**, one file per language, named after the **versionCode** (fastlane layout, so #37 can upload them automatically later):
   - `android/fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`
   - `android/fastlane/metadata/android/de-DE/changelogs/<versionCode>.txt`

   Write for users, not developers: no issue numbers, file names or jargon. Use 2–5 short lines starting with "• ", the most useful change first, natural German (not a word-for-word translation). **At most 500 characters each.** Check the length:

   ```bash
   for f in android/fastlane/metadata/android/*/changelogs/<versionCode>.txt; do echo "$(wc -m < "$f") $f"; done
   ```
4. **Store listing**: if a feature changes what the app does, update `full_description.txt` (at most 4000 characters) and, if needed, `short_description.txt` (at most 80) in both locale folders. `title.txt` stays "Focused Task".
5. **Release sheet** `release-notes/vX.Y.Z.md`, the one file the owner works from. Use this template:

   ````markdown
   # Focused Task vX.Y.Z (versionCode N)

   Issue: #<n> · PR: #<pr> · Date: YYYY-MM-DD

   ## Upload to Google Play
   - App bundle: `focused_task-X.Y.Z.aab` (from `flutter build appbundle --release`)
   - Release name: `X.Y.Z (N)`
   - Store listing changed: yes/no (which files)

   ### What's new – en-US
   <copy of the en-US changelog file>

   ### What's new – de-DE
   <copy of the de-DE changelog file>

   ## GitHub Release notes
   <the CHANGELOG section, without its heading>

   ## After merging
   ```bash
   git checkout main && git pull
   git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z
   flutter build apk --release
   flutter build appbundle --release
   cp build/app/outputs/flutter-apk/app-release.apk focused_task-X.Y.Z.apk
   cp build/app/outputs/bundle/release/app-release.aab focused_task-X.Y.Z.aab
   gh release create vX.Y.Z focused_task-X.Y.Z.apk focused_task-X.Y.Z.aab --title "vX.Y.Z" --notes-file <(sed -n '/## GitHub Release notes/,/## After merging/p' release-notes/vX.Y.Z.md | sed '1d;$d')
   ```
   Upload the `.aab` in Play Console, paste the "What's new" texts, then delete the copied `.apk`/`.aab` and tick #<n> in #38.
   ````

## 8. Open the PR and hand over

```bash
git add -A && git commit      # message: summary line, bullet points, "Fixes #<n>", attribution trailer
git push -u origin issue-<number>-<slug>
gh pr create --title "<Feature> (#<n>)" --body-file <file>
```

- The PR body has `Fixes #<n>`, *What* (with the decisions from step 2), *Also* (step 6), *Tests* (with the real numbers) and *Release* (version and a link to the release sheet).
- In the desktop app, bind the PR (`ccd_pr` tools) and turn on Auto-fix if the user wants it. Don't poll CI yourself.
- **Never merge yourself.** The owner merges; the next run (or "I've merged it") releases it with step 0. A merge is a release, and release builds are signed with `android/key.properties` and the keystore, which exist only on the owner's machine. Never print, generate or commit them. Tell the user that the PR is ready, that the Play Store texts are in `release-notes/vX.Y.Z.md`, that saying "I've merged it" (or running `/next-issue`) releases it and brings the full report, and which issue comes next.
