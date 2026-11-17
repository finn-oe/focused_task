# Changelog

All notable changes to Focused Task. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).
Every merged pull request is released as its own version (see "Releases" in `CLAUDE.md`).

## [1.1.0] - 2026-11-17

### Changed
- Settings are available immediately on start (no loading spinner in the settings screen). (#18)
- Statistics and crash recovery load their data through app state instead of the screens. (#18)
- Upgraded to Flutter 3.50 (`material_ui`), Riverpod 3 and go_router 18; Android build tooling updated (Gradle 9.5, AGP 9.3.1, Kotlin 2.4.20). (#18)
- Android: the code namespace is now `com.techreload.taskfocus` (the app id is unchanged, existing installs update normally). (#18)

## [1.0.5] and earlier

See the Git history.
