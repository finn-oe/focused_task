# Changelog

All notable changes to Focused Task. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).
Every merged pull request is released as its own version (see "Releases" in `CLAUDE.md`).

## [1.7.0] - 2026-11-17

### Added
- Priority (Low / Medium / High) in the task form; Medium and High show a flag in the plan. (#25)
- Target duration chips (15 / 25 / 45 / 60 / 90 min), "Custom" up to 12 hours, and "None". (#25)
- Sub-tasks are added inline: type and press Enter for the next one; edit in place, swipe or tap to delete, drag to reorder. (#25)

### Changed
- The task form shows the date as a field, asks before deleting (naming the tracked time) and before discarding unsaved changes, and tells you when the title is missing. (#25)
- Past tasks can be edited (tap the task or the edit button); "Copy to Today" is still there. (#25)

## [1.6.1] - 2026-11-17

### Added
- End-to-end tests of the main flows (plan, focus, day navigation, settings, session log), run in CI on Linux. (#36)

## [1.6.0] - 2026-11-17

### Added
- System notification "Time is up" on Windows, macOS, Linux and the web when a task reaches its target. (#35)
- Settings → Notifications: a hint (with "Ask again") if notifications were refused, and a test notification. (#35)

### Changed
- Notification permission is asked the first time you enter focus mode instead of never. (#35)
- Android: compiles against API 37 (required by the notification plugin); the target API level is unchanged. (#35)
## [1.5.0] - 2026-11-17

### Added
- Navigation between Plan, Calendar (coming soon), Statistics and Settings: bottom bar on phones, rail on tablets, sidebar on wide windows. Each view keeps its state. (#9)
- Day navigation in the plan: previous / next day, date picker, "Today", swipe left/right, `Alt+←/→`; `Ctrl/Cmd+N` adds a task. The day is in the URL (`/plan?date=…`), so browser back and links work. (#9)

### Changed
- The plan's top bar only shows the day navigation and the "Start focus" button. (#9)

## [1.4.0] - 2026-11-17

### Added
- Every focus interval is recorded in a session log. (#19)
- "Add time" in the task form to add time worked without the app. (#19)

### Changed
- Statistics count focus time on the day it was actually worked (a session over midnight is split), no longer on the task's planned day. Task counts still use the planned day. (#19)
- Deleting a task keeps its tracked time in the statistics. (#19)
- Existing tracked time is moved into the log on update (one entry per task at noon of its planned day); a session that was running when the app closed can still be recovered. (#19)

## [1.3.0] - 2026-11-17

### Added
- The app runs in the browser (web). Tasks are stored locally in the browser. (#30)

### Changed
- The database is opened through `drift_flutter`; on Android, iOS and desktop it stays in the same file, so existing data is kept. (#30)

## [1.2.0] - 2026-11-17

### Added
- German translation. Choose the language in Settings (System / English / Deutsch); it switches immediately and is remembered. (#32)
- Dates are shown in the format of the selected language, and the statistics week starts on the locale's first weekday (e.g. Sunday in US English, Monday in German). (#32)

### Changed
- Alarm notifications use the app language. (#32)
- Sub-task edit and delete buttons have tooltips. (#32)

## [1.1.0] - 2026-11-17

### Changed
- Settings are available immediately on start (no loading spinner in the settings screen). (#18)
- Statistics and crash recovery load their data through app state instead of the screens. (#18)
- Upgraded to Flutter 3.50 (`material_ui`), Riverpod 3 and go_router 18; Android build tooling updated (Gradle 9.5, AGP 9.3.1, Kotlin 2.4.20). (#18)
- Android: the code namespace is now `com.techreload.taskfocus` (the app id is unchanged, existing installs update normally). (#18)

## [1.0.5] and earlier

See the Git history.
