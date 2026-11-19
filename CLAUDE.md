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
- The database must work on web too (Drift WASM / `drift_flutter`), so keep database setup in one place (`lib/core/database/`). The native file is `<app documents>/focused_task.sqlite` – never change name or location (users would lose their data). After upgrading `drift` or `sqlite3`, update `web/drift_worker.js` and `web/sqlite3.wasm` (README → Web; CI checks them).
- Layouts must work from a 360 px phone up to a wide desktop window. Prefer adaptive layouts (`LayoutBuilder`, `NavigationRail` on wide screens) over fixed sizes.
- Respect platform conventions: back gesture/button on Android (`PopScope`), keyboard shortcuts and window focus on desktop, safe areas on mobile.
- Before calling a change done, at minimum run `flutter analyze` and `flutter test`; if platform code was touched, also build the affected targets (e.g. `flutter build web`, `flutter build windows`).

## Tech stack

| Concern | Choice |
|---|---|
| UI | Flutter, Material 3 via `package:material_ui` (`lib/core/ui/themes/`) |
| State | `flutter_riverpod` 3, `Notifier`/`NotifierProvider` only (providers in `lib/core/providers/app_providers.dart`) |
| Routing | `go_router` (`lib/core/routing/app_router.dart`): `StatefulShellRoute` for Plan / Calendar / Statistics / Settings (adaptive `AppShell` in `lib/core/ui/app_shell.dart`), full-screen routes for focus and the task form. Use the `AppRoutes` constants; state that belongs in the URL goes there (e.g. `/plan?date=YYYY-MM-DD`). |
| Persistence | Drift / SQLite (`lib/core/database/`), `shared_preferences` for settings (loaded in `main()`, exposed via `sharedPreferencesProvider`) |
| Ordering | Fractional indexing (`lib/core/utils/fractional_indexer.dart`) |
| Alarms | `TargetAlarm` in `lib/core/services/target_alarm.dart`: `alarm` (mobile), timer + `audioplayers` + notification (desktop/web) |
| Notifications | `NotificationService` in `lib/core/services/notification_service.dart` (`flutter_local_notifications`; web/Linux schedule in-app). Ids live in `NotificationIds`. Ask for permission when a feature first needs it (`SettingsNotifier.ensureNotificationPermission()`), never on app start. |

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
- **Tracked time lives in `focus_sessions`** (`lib/features/sessions/`, `IFocusSessionRepository`). Start/heartbeat/end sessions through the repository; never write `tasks.time_spent` directly – it is a cached total that `end()` / `addManualTime()` update in the same transaction. At most one session is open at a time. Statistics count focus time on the day it happened (`focusTimeByDay` splits at local midnight); all statistics numbers come from the pure `StatsCalculator` (`lib/features/tasks/domain/stats/`); goal progress and streaks from the pure `StreakCalculator` (`lib/features/goals/domain/`, fed by `focusTimeByDay`).
- **Breaks** (`lib/features/breaks/`): the pure `IntervalPlanner` is the work/break state machine; `FocusModeNotifier` drives it (`state.intervals`), ends the focus session with `EndReason.interval` and records the break as a `kind = 'break'` session without a task. Break time never counts as focus time.
- **Categories** (`lib/features/categories/`, `ICategoryRepository`, `categoriesNotifierProvider`) store a palette index (`CategoryColor` in `lib/core/ui/category_palette.dart`), never a colour. Deleting a category sets its tasks' `category_id` to `NULL`; archived ones are hidden from pickers, filters and the board.
- **Business logic lives in notifiers/domain**, not in widgets. Widgets render state and forward user intent.
- **Notifiers** extend `Notifier` and get their dependencies with `ref.watch(...)` in `build()`, never via constructors. Widgets never read `taskRepositoryProvider` directly; data a screen loads goes through a provider (e.g. `statsReportProvider`) or a notifier method.
- **Time is injected.** Use `clock.now()` from `package:clock` instead of `DateTime.now()` in logic, so tests can control time with `fakeAsync` / `withClock`.
- **Dates:** a task's day is a calendar date. Compute day boundaries with `DateTime(y, m, d + 1)`, never `+ Duration(days: 1)` (breaks on DST switches).
- **Database changes** require bumping `schemaVersion`, a migration step in `AppDatabase.migration`, and a migration test. Regenerate code with `dart run build_runner build --delete-conflicting-outputs`; commit the generated `*.g.dart`.

## Code quality

- Code must pass `flutter analyze` with **zero** issues and be formatted with `dart format` (page width 180 is set in `analysis_options.yaml`; generated `*.g.dart` and `lib/l10n/generated/` files are excluded).
- Prefer small, focused widgets over large `build` methods; extract private widgets instead of helper methods returning widgets.
- No hard-coded colours – use `Theme.of(context).colorScheme`. Charts: reuse `BarChart` / `HeatmapChart` from `lib/core/ui/charts/` (no chart package). No duplicated helpers – shared formatting lives in `lib/core/utils/`.
- Use strong types; avoid `dynamic`.
- No hard-coded user-facing strings – see *Strings*.
- Destructive actions (delete, cleanup) need a confirmation or undo.
- Do not add dependencies casually. Remove unused ones.

## Strings

- **Every user-facing string goes into `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`** (English is the template). Read them with `context.l10n.<key>` (`lib/core/l10n/l10n.dart`); outside the widget tree use `ref.read(appLocalizationsProvider)`.
- Keys are prefixed with the screen (`plan…`, `focus…`, `settings…`) or `common…`. Use placeholders and ICU plurals (`{count, plural, =1{1 task} other{{count} tasks}}`); never concatenate sentences or build them from fragments.
- Run `flutter gen-l10n` after editing ARB files and commit `lib/l10n/generated/` (CI checks it is up to date).
- `MaterialApp.localizationsDelegates` must be `appLocalizationsDelegates`, not the generated `AppLocalizations.localizationsDelegates` (that list references the deprecated SDK Material localizations).
- Dates: `DateFormat(..., locale)` / `relativeDayLabel`; weeks start on `firstDayOfWeek(context)`. Durations stay locale-independent (`HH:MM`, `duration_extensions.dart`).
- Tests pump widgets with `localizedApp(...)` / `localizedRouterApp(...)` from `test/helpers/localized_app.dart`.

## Testing

- `flutter test` must pass before every commit.
- Repository/database logic: test against `AppDatabase(NativeDatabase.memory())`.
- Notifiers/widgets: use the shared fakes in `test/helpers/` (`FakeTaskRepository`, `FakeTargetAlarm`, `FakeNotificationService`, `fakePreferences()`, `buildTask()`); extend them when the interface grows. `FakeTaskRepository` also implements `IFocusSessionRepository` and `ICategoryRepository`: override `taskRepositoryProvider`, `focusSessionRepositoryProvider` **and** `categoryRepositoryProvider` with the same instance.
- Notifiers: `ProviderContainer(overrides: [...])` (or `ProviderContainer.test`). Widgets: `ProviderScope(overrides: [...])` with fakes. Anything that reads settings needs `sharedPreferencesProvider.overrideWithValue(await fakePreferences())`.
- Every bug fix comes with a regression test.
- **UI changes extend `integration_test/`** (end-to-end flows on the real app; bootstrap in `integration_test/test_app.dart`). Run them with `flutter test integration_test -d windows` (or `macos` / `linux`); CI runs them on Linux.

## Toolchain

Flutter **3.50.0** (stable, Dart 3.14), pinned in `.github/workflows/ci.yml` (`FLUTTER_VERSION`). Use the same version locally.

Import Material widgets from `package:material_ui/material_ui.dart`; `package:flutter/material.dart` is deprecated since Flutter 3.47.

## Common commands

```bash
flutter pub get
flutter analyze
flutter test
flutter test integration_test -d windows   # end-to-end flows (or -d macos / -d linux)
# Format everything except generated code (CI compares *.g.dart and lib/l10n/generated with fresh generator output).
# Never `dart format .` or `dart format lib`.
dart format $(git ls-files -co --exclude-standard 'lib/*.dart' 'test/*.dart' 'integration_test/*.dart' 'tool/*.dart' | grep -v -e '\.g\.dart$' -e '^lib/l10n/generated/')
dart run build_runner build --delete-conflicting-outputs   # after changing Drift tables
flutter run -d windows   # or chrome, macos, linux, android, ios
```

## Workflow

- **Start with the roadmap issue #38.** It lists the open issues in the order they should be done, which ones can run in parallel, and the rules for picking one up.
- Every `agent-ready` issue has *Order* (depends on / blocks), *Context*, *Tasks*, *Acceptance criteria* and a *Definition of done*. Follow it, and update the spec of later issues if your work changes them.
- Branch `issue-<number>-<slug>` from `main`, one issue per PR, `Fixes #<number>` in the PR body, tick the box in #38 after merging.
- Never develop two database schema changes at the same time (each bumps `schemaVersion`).
- Update `README.md` / `docs/` when behaviour or architecture changes.
- Merge a PR only when CI is green (the `Build web` job may fail until #30). **Every merge is a release** (see below).

## Releases

Every merged PR ships as a new version: a Git tag, a GitHub Release and a signed Android build. Until #37 automates this, do it by hand:

1. **In the PR** (before merging):
   - Bump `version` in `pubspec.yaml` with SemVer: new feature → minor (`1.1.0` → `1.2.0`), fix / tech debt / docs → patch (`1.2.0` → `1.2.1`), incompatible data or behaviour change → major. **Always increase the build number** after `+` by one: it is the Android `versionCode` and must grow, or updates won't install.
   - Add a section `## [x.y.z] - YYYY-MM-DD` at the top of `CHANGELOG.md` (Keep a Changelog: *Added*, *Changed*, *Fixed*, *Removed*) with user-facing changes and the issue number.
2. **After merging** (on an up-to-date `main`):
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z
   flutter build apk --release
   flutter build appbundle --release
   cp build/app/outputs/flutter-apk/app-release.apk focused_task-X.Y.Z.apk
   cp build/app/outputs/bundle/release/app-release.aab focused_task-X.Y.Z.aab
   gh release create vX.Y.Z focused_task-X.Y.Z.apk focused_task-X.Y.Z.aab --title "vX.Y.Z" --notes "<the CHANGELOG section>"
   ```
   Release builds are signed with `android/key.properties` + keystore, which exist only on the owner's machine. **Never** commit, print or generate them; if they are missing, stop and ask. Delete the copied `.apk`/`.aab` afterwards (`*.apk`/`*.aab` must not be committed).
3. Tick the issue in #38.
