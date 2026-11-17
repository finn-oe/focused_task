# CLAUDE.md

Guidance for Claude (and any other contributor) working in this repository.

## Product vision

**Focused Task** is a simple but complete **calendar + planner with a built-in focus mode**.
It should help one person to:

1. **Plan** – put tasks on days, order them, break them into sub-tasks, estimate how long they take.
2. **Focus** – work through the day's tasks one at a time in a distraction-reduced focus mode.
3. **Track time** – every minute of focused work is recorded reliably (also across crashes, app switches and restarts).
4. **Reflect** – statistics show where time went, how plans compared to reality, and how dedication develops over time (goals, streaks, distractions).
5. **Reduce distractions** – the app nudges the user back to the task instead of becoming a distraction itself.

Guiding principles:

- **Simple over feature-rich.** Every new feature must serve plan → focus → track → reflect. If it doesn't, it doesn't belong.
- **Local-first & private.** All data stays on the device (SQLite via Drift). No account, no telemetry. Export/backup is the user's choice.
- **Trustworthy data.** Tracked time and statistics must never silently disappear or be wrong. Treat time-tracking bugs as high priority.
- **Calm UI.** Material 3, light/dark themes, few colours, no gamified noise.

## Platforms

The app must build and run on **every platform Flutter supports**: Android, iOS, Web, Windows, macOS and Linux.

Rules that follow from this:

- **Never** import `dart:io` (or call `Platform.*`) from shared code. Put platform-specific code behind an interface in `lib/core/services/` and select the implementation with conditional imports (`if (dart.library.io)` / `if (dart.library.js_interop)`) or `kIsWeb` + `defaultTargetPlatform`.
- Every plugin added to `pubspec.yaml` must support all six platforms, or be wrapped so the app degrades gracefully where it is missing (feature hidden, not a crash).
- The database must work on web too (Drift WASM / `drift_flutter`), so keep database setup in one place (`lib/core/database/`).
- Layouts must work from a 360 px phone up to a wide desktop window. Prefer adaptive layouts (`LayoutBuilder`, `NavigationRail` on wide screens) over fixed sizes.
- Respect platform conventions: back gesture/button on Android (`PopScope`), keyboard shortcuts and window focus on desktop, safe areas on mobile.
- Before calling a change done, at minimum run `flutter analyze` and `flutter test`; if platform code was touched, also build the affected targets (e.g. `flutter build web`, `flutter build windows`).

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter, Material 3 via `package:material_ui` (`lib/core/ui/themes/`) |
| State | `flutter_riverpod` 3, `Notifier`/`NotifierProvider` only (providers in `lib/core/providers/app_providers.dart`) |
| Routing | `go_router` (`lib/core/routing/app_router.dart`) |
| Persistence | Drift / SQLite (`lib/core/database/`), `shared_preferences` for settings (loaded in `main()`, exposed via `sharedPreferencesProvider`) |
| Ordering | Fractional indexing (`lib/core/utils/fractional_indexer.dart`) |
| Alarms | `TargetAlarm` in `lib/core/services/target_alarm.dart`: `alarm` (mobile), timer + `audioplayers` (desktop/web) |

## Architecture

Feature-first clean architecture:

```text
lib/
├── core/                    # shared: database, providers, routing, services, themes, utils
└── features/<feature>/
    ├── data/                # repository implementations (talk to Drift)
    ├── domain/              # entities + repository interfaces (pure Dart, no Flutter/Drift imports)
    └── presentation/        # screens, widgets, notifiers/state
```

Rules:

- **Dependency direction:** `presentation → domain ← data`. Presentation code depends on repository *interfaces* (`ITaskRepository`), never on `AppDatabase` or Drift row classes.
- **Domain is pure Dart.** Entities are immutable, have `copyWith`, and contain no Flutter or Drift imports.
- **Business logic lives in notifiers/domain**, not in widgets. Widgets render state and forward user intent.
- **Notifiers** extend `Notifier` and get their dependencies with `ref.watch(...)` in `build()`, never via constructors. Widgets never read `taskRepositoryProvider` directly; data a screen loads goes through a provider (e.g. `taskStatsProvider`) or a notifier method.
- **Time is injected.** Use `clock.now()` from `package:clock` instead of `DateTime.now()` in logic, so tests can control time with `fakeAsync` / `withClock`.
- **Dates:** a task's day is a calendar date. Compute day boundaries with `DateTime(y, m, d + 1)`, never `+ Duration(days: 1)` (breaks on DST switches).
- **Database changes** require bumping `schemaVersion`, a migration step in `AppDatabase.migration`, and a migration test. Regenerate code with `dart run build_runner build --delete-conflicting-outputs`; commit the generated `*.g.dart`.

## Code quality

- Code must pass `flutter analyze` with **zero** issues and be formatted with `dart format` (page width 180 is set in `analysis_options.yaml`; generated `*.g.dart` files are excluded).
- Prefer small, focused widgets over large `build` methods; extract private widgets instead of helper methods returning widgets.
- No hard-coded colours – use `Theme.of(context).colorScheme`. No duplicated helpers – shared formatting lives in `lib/core/utils/`.
- Use strong types; avoid `dynamic`.
- User-facing strings should be easy to localise later (keep them in one place per screen; no string concatenation of sentences).
- Destructive actions (delete, cleanup) need a confirmation or undo.
- Do not add dependencies casually. Remove unused ones.

## Testing

- `flutter test` must pass before every commit.
- Repository/database logic: test against `AppDatabase(NativeDatabase.memory())`.
- Notifiers/widgets: use the shared fakes in `test/helpers/` (`FakeTaskRepository`, `FakeTargetAlarm`, `fakePreferences()`, `buildTask()`); extend them when the interface grows.
- Notifiers: `ProviderContainer(overrides: [...])` (or `ProviderContainer.test`). Widgets: `ProviderScope(overrides: [...])` with fakes. Anything that reads settings needs `sharedPreferencesProvider.overrideWithValue(await fakePreferences())`.
- Every bug fix comes with a regression test.

## Toolchain

Flutter **3.50.0** (stable, Dart 3.14), pinned in `.github/workflows/ci.yml` (`FLUTTER_VERSION`). Use the same version locally.

Import Material widgets from `package:material_ui/material_ui.dart`; `package:flutter/material.dart` is deprecated since Flutter 3.47.

## Common commands

```bash
flutter pub get
flutter analyze
flutter test
dart format .
dart run build_runner build --delete-conflicting-outputs   # after changing Drift tables
flutter run -d windows   # or chrome, macos, linux, android, ios
```

## Workflow

- **Start with the roadmap issue #38.** It lists the open issues in the order they should be done, which ones can run in parallel, and the rules for picking one up.
- Every `agent-ready` issue has *Order* (depends on / blocks), *Context*, *Tasks*, *Acceptance criteria* and a *Definition of done*. Follow it, and update the spec of later issues if your work changes them.
- Branch `issue-<number>-<slug>` from `main`, one issue per PR, `Fixes #<number>` in the PR body, tick the box in #38 after merging.
- Never develop two database schema changes at the same time (each bumps `schemaVersion`).
- Update `README.md` / `docs/` when behaviour or architecture changes.
