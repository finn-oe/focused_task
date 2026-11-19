# Focused Task

**Plan your day, focus on one task at a time, and see where your time really goes.**

Focused Task is a simple, local-first calendar + planner with a built-in focus mode.
You put tasks on days, start a focus session, and the app walks you through your
tasks one by one while it tracks your time. Statistics then show how your plans
compared to reality – so you can get a little more dedicated every day.

> Status: early development (v1.x). Every merged change is released – see [Releases](https://github.com/finn-oe/focused_task/releases) and the [changelog](CHANGELOG.md). See the [roadmap](#roadmap) and the
> [open issues](https://github.com/finn-oe/focused_task/issues) for what is planned.

## Features

### Available today

- **Navigation** – bottom bar on phones, rail on tablets, sidebar on wide windows. Switch days with ‹ ›, the date
  picker, a swipe or `Alt+←/→`; the day is part of the URL (`/plan?date=2026-11-17`). `Ctrl/Cmd+N` adds a task.
- **Plan mode** – tasks per day with description, sub-tasks (checklist) and an optional target duration.
  Reorder by drag & drop, mark as done or duplicate. Unfinished tasks of past days can be moved to today (or any day,
  with undo) – their tracked time and session history stay on the days they were worked – or copied.
- **Categories** – group tasks into categories (e.g. "Work", "Study") with one of ten colours, managed in
  Settings → Categories (add, rename, colour, reorder, archive, delete). Pick a category in the task form. The plan
  list shows a coloured dot per task and filter chips; the **board** (toggle in the plan's app bar) groups the day's
  tasks by category in columns (wide) or sections (phone) – drag a task by its handle to change its category.
  "Focus on <category>" from the filter or a board header works through that category's open tasks only, and the
  statistics show the focus time per category. Without categories the plan looks exactly as before.
- **Calendar** – week and month views (`/calendar?view=month&date=2026-11-17`). The week shows each day's tasks
  (7 columns on wide windows – long-press and drag a task to another day; an agenda with "Move to…" on phones). The
  month grid shows done/total tasks and a bar for the focus time of each day. Tap a day to open it in the plan.
- **Daily rollover** – on the first start of a day, the app offers to move the open tasks of the last 7 days to
  today (can be turned off in Settings → Planning).
- **Focus mode** – works through today's open tasks in order. Shows the time spent on the current task
  (or the time remaining until the target), the overall session time, and the sub-task progress.
- **Breaks (intervals)** – optional Pomodoro-style cycles, off by default: work 25 min, then a 5 min break, and a
  15 min break after every 4 intervals (all adjustable in the settings). Focus shows when the next break comes; the
  break screen counts down and offers "Skip break", then asks "Ready? Continue with …" (or continues on its own).
  Notifications announce the break and its end in the background. Break time is recorded but never counts as focus
  time; the statistics show it separately.
- **Target alarm** – rings when a task's target duration is reached (native alarm on Android/iOS, sound and system
  notification on desktop and web). Notification permission is asked the first time you enter focus mode; Settings
  has a test notification.
- **Distraction guard** – optionally pauses the session when the app is minimised or the screen is locked,
  and can keep the screen awake while focusing.
- **Session log** – every focus interval is recorded, so time counts on the day you actually worked (also across midnight).
  Missing time can be added by hand in the task form ("Add time").
- **Session recovery** – if the app was closed during a session, you are asked whether to keep the tracked time.
- **Statistics** – day, week, month or year, with ‹ › to browse past periods: focus time (total, per elapsed day,
  sessions), completed tasks, a bar chart of focus time per hour / day / month, planned vs. tracked time with the median
  estimation accuracy, a weekday × hour heatmap of your best focus hours and the top 5 tasks.
- **Daily focus goal & streaks** – an optional goal (30 min … 8 h) for your working days (Mon–Fri by default). A small
  ring next to the date in the plan shows today's progress (tap → statistics); the statistics show the current and
  longest streak of working days that reached the goal and the goal days per month; "finished for today" sums up the
  day. Days off neither break nor extend a streak, and today only counts once the goal is reached. Past days are judged
  by the current goal. While you focus, a notification says when the goal is reached (once a day).
- **Languages** – English and German; follows the system language or can be chosen in the settings.
- **Settings** – light/dark/system theme, language, the daily rollover prompt, data retention, focus-mode behaviour,
  daily focus goal and working days, work/break intervals.

### Planned

Distraction tracking, recurring tasks, data export and full support for every Flutter platform.
See [Roadmap](#roadmap).

## Platforms

The goal is to support **all platforms Flutter offers**:

| Platform | Status |
|---|---|
| Android | ✅ main target |
| iOS | ✅ builds (alarm via `alarm` package) |
| Windows | ✅ builds and runs |
| macOS / Linux | ⚠️ should build, not regularly tested |
| Web | ✅ builds in CI; data is stored in the browser (IndexedDB or OPFS) |

### Web

On the web the database runs as SQLite compiled to WebAssembly (via `drift_flutter`). Two files in `web/` must match the
locked package versions – CI fails if they don't:

| File | Matches | Source |
|---|---|---|
| `web/sqlite3.wasm` | `sqlite3` 3.9.1 (see `pubspec.lock`) | `sqlite3.wasm` from the [sqlite3.dart release `sqlite3-<version>`](https://github.com/simolus3/sqlite3.dart/releases) |
| `web/drift_worker.js` | `drift` / `sqlite3` in `pubspec.lock` | compiled from `tool/drift_worker.dart` |

After upgrading `drift` or `sqlite3`:

```bash
dart compile js -O4 --no-source-maps tool/drift_worker.dart -o web/drift_worker.js && rm web/drift_worker.js.deps
curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<version>/sqlite3.wasm
```

The worker is compiled locally instead of taken from the drift release, because the release build targets a different
`sqlite3` version than the one we resolve, and mismatching files fail at runtime (`LinkError` on `WebAssembly.instantiate`).

## Getting started

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) 3.50.0 (stable, Dart 3.14) – the version CI uses.

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
│   ├── ui/charts/          # reusable BarChart and HeatmapChart (CustomPainter, no chart package)
│   ├── ui/category_palette.dart # the ten category colours (seeded ColorSchemes, light & dark)
│   ├── ui/themes/          # light & dark Material 3 themes
│   └── utils/              # formatting, fractional indexing, lifecycle observer
└── features/
    ├── breaks/             # work/break cycles: IntervalSettings, IntervalPlanner (pure state machine)
    ├── categories/         # task categories: TaskCategory, ICategoryRepository, management screen
    ├── goals/              # daily focus goal: FocusGoal, StreakCalculator, progress ring
    ├── settings/           # preferences (shared_preferences)
    └── tasks/
        ├── data/           # TaskRepositoryImpl (Drift)
        ├── domain/         # TaskEntity, ITaskRepository, stats/ (StatsCalculator → StatsReport)
        └── presentation/
            ├── plan_mode/  # day list, task form
            ├── focus_mode/ # focus, pause, break and "finished for today" screens
            └── stats/      # statistics screen
```

How the pieces fit together:

- **Ordering** uses fractional indexing (`sort_order` strings), so moving a task only updates one row.
- **Time tracking:** every focus (or break) interval is a row in `focus_sessions`; `tasks.time_spent` caches the sum
  of a task's closed focus sessions. A task's elapsed time = `time_spent + (now − start of its open session)`.
- **Breaks:** the pure `IntervalPlanner` decides the phase (work → short break → … → long break). When a work interval
  ends, its focus session ends (`end_reason = 'interval'`) and a `kind = 'break'` session starts.
- **Categories:** `categories` table; `tasks.category_id` is set to `NULL` when a category is deleted. A category
  stores an index into the fixed palette, never a raw colour.
- **Routes:** `/plan` (home), `/task-form`, `/focus?day=…&task=…&category=…`, `/pause`, `/break`, `/finished-for-today`, `/stats`,
  `/settings`, `/settings/categories`.

More detail and the rules for contributors are in [CLAUDE.md](CLAUDE.md).

## Roadmap

The order of all planned work is tracked in **[#38 – Roadmap: implementation order](https://github.com/finn-oe/focused_task/issues/38)**, grouped into [milestones](https://github.com/finn-oe/focused_task/milestones):

1. **Stability** ✅ – time-tracking and date bugs, tests, CI (PR #34).
2. **Foundations** – Riverpod Notifier API (#18), localisation (#32), web (#30), focus-session log (#19),
   navigation shell (#9), notifications (#35), integration tests (#36).
3. **Core planner** – task form (#25), focus queue (#26), calendar views (#22), rollover (#23),
   statistics (#20), goals & streaks (#21).
4. **Categories, focus & habits** – categories (#2), breaks (#27), distraction tracking (#28),
   due dates & reminders (#10), recurring tasks (#24).
5. **Platforms & release** – desktop mini timer (#29), responsive & accessible layout (#31),
   Android app blocker (#7), export/backup (#33), release pipeline (#37).

## Contributing

Issues and pull requests are welcome. Pick the next issue from the [roadmap (#38)](https://github.com/finn-oe/focused_task/issues/38) and read [CLAUDE.md](CLAUDE.md) first – it describes the
product idea, the architecture rules and the quality bar (`flutter analyze` clean, tests passing,
works on all platforms).
