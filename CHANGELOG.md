# Changelog

All notable changes to Focused Task. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).
Every merged pull request is released as its own version (see "Releases" in `CLAUDE.md`).

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
