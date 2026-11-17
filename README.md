# Focused Task

**Plan your day, focus on one task at a time, and see where your time really goes.**

Focused Task is a simple, local-first calendar + planner with a built-in focus mode.
You put tasks on days, start a focus session, and the app walks you through your
tasks one by one while it tracks your time. Statistics then show how your plans
compared to reality – so you can get a little more dedicated every day.

> Status: early development (v1.0.x). See the [roadmap](#roadmap) and the
> [open issues](https://github.com/finn-oe/focused_task/issues) for what is planned.

## Features

### Available today

- **Plan mode** – tasks per day with description, sub-tasks (checklist) and an optional target duration.
  Reorder by drag & drop, mark as done, duplicate, or copy unfinished tasks from past days to today.
- **Focus mode** – works through today's open tasks in order. Shows the time spent on the current task
  (or the time remaining until the target), the overall session time, and the sub-task progress.
- **Target alarm** – rings when a task's target duration is reached (native alarm on Android/iOS, sound on desktop).
- **Distraction guard** – optionally pauses the session when the app is minimised or the screen is locked,
  and can keep the screen awake while focusing.
- **Session recovery** – if the app was closed during a session, you are asked whether to keep the tracked time.
- **Statistics** – completion rate, total focus time, average task duration and focus time per day for the
  current day, week or month.
- **Settings** – light/dark/system theme, data retention, focus-mode behaviour.

### Planned

Calendar week/month views, a proper focus-session log, breaks (Pomodoro), distraction tracking,
charts, goals & streaks, recurring tasks, data export and full support for every Flutter platform.
See [Roadmap](#roadmap).

## Platforms

The goal is to support **all platforms Flutter offers**:

| Platform | Status |
|---|---|
| Android | ✅ main target |
| iOS | ✅ builds (alarm via `alarm` package) |
| Windows | ✅ builds and runs |
| macOS / Linux | ⚠️ should build, not regularly tested |
| Web | ❌ not yet – the app uses `dart:io` and native SQLite (tracked in the issues) |

## Getting started

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (stable channel, Dart ≥ 3.12).

```bash
git clone https://github.com/finn-oe/focused_task.git
cd focused_task
flutter pub get
flutter run                # pick a device, e.g. -d windows or -d android
```

Useful commands:

```bash
flutter analyze                                             # static analysis (should report no issues)
flutter test                                                # unit & widget tests
dart format .                                               # format code
dart run build_runner build --delete-conflicting-outputs    # regenerate Drift code after table changes
dart run flutter_launcher_icons                             # regenerate app icons
```

## Architecture

Feature-first clean architecture with Riverpod, go_router and Drift (SQLite):

```text
lib/
├── main.dart               # app bootstrap (alarm init, settings, launch cleanup)
├── core/
│   ├── database/           # Drift database, tables, migrations
│   ├── providers/          # Riverpod providers (DI)
│   ├── routing/            # go_router routes
│   ├── services/           # platform services (alarm)
│   ├── ui/themes/          # light & dark Material 3 themes
│   └── utils/              # formatting, fractional indexing, lifecycle observer
└── features/
    ├── settings/           # preferences (shared_preferences)
    └── tasks/
        ├── data/           # TaskRepositoryImpl (Drift)
        ├── domain/         # TaskEntity, TaskStats, ITaskRepository
        └── presentation/
            ├── plan_mode/  # day list, task form
            ├── focus_mode/ # focus, pause and "finished for today" screens
            └── stats/      # statistics screen
```

How the pieces fit together:

- **Ordering** uses fractional indexing (`sort_order` strings), so moving a task only updates one row.
- **Time tracking:** a task stores its accumulated `time_spent` (ms) and `latest_start` while it is running.
  Elapsed time = `time_spent + (now − latest_start)`.
- **Routes:** `/plan` (home), `/task-form`, `/focus`, `/pause`, `/finished-for-today`, `/stats`, `/settings`.

More detail and the rules for contributors are in [CLAUDE.md](CLAUDE.md).

## Roadmap

Work is grouped into [milestones](https://github.com/finn-oe/focused_task/milestones):

1. **Stability** – date/DST bug (#11), timer & alarm bugs (#12, #13, #15, #16), retention deleting history (#14),
   test suite + CI (#17), code cleanup (#18).
2. **Time tracking & statistics** – focus-session log (#19), charts & planned vs. actual (#20, #4), goals & streaks (#21).
3. **Calendar & planning** – week/month views (#22, #9), rollover of unfinished tasks (#23), recurring tasks (#24),
   task form (#25), categories (#2), due dates (#10).
4. **Focus & distractions** – choose/skip tasks (#26), breaks (#27), distraction tracking (#28),
   desktop mini timer (#29), Android app blocker (#7).
5. **All platforms & polish** – web support (#30), responsive layout & accessibility (#31), localisation (#32),
   export/backup (#33).

## Contributing

Issues and pull requests are welcome. Please read [CLAUDE.md](CLAUDE.md) first – it describes the
product idea, the architecture rules and the quality bar (`flutter analyze` clean, tests passing,
works on all platforms).
