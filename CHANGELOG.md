# Changelog

All notable changes to Focused Task. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).
Every merged pull request is released as its own version (see "Releases" in `CLAUDE.md`).

## [1.19.0] - 2026-11-20

### Added
- **Recurring tasks**: "Repeat" in the task form – every day, weekdays (Mon–Fri), weekly on chosen days, every N days or monthly on a day (the 31st falls back to the last day of shorter months), with an optional end date. Every occurrence is a normal task with its own completion, sub-tasks and tracked time. (#24)
- Occurrences appear when their day is shown in the plan, the calendar or focus mode, and a week ahead for reminders; past days are never filled in afterwards. Deleted occurrences don't come back. (#24)
- The start time, reminder and deadline (relative to the day, e.g. "the next day at 12:00") carry over to every occurrence, so their reminders work like those of any task. (#24)
- Editing or deleting an occurrence asks **Only this** or **This and future**; a changed repeat applies to this and the following days. Occurrences with tracked time are always kept. (#24)
- Recurring tasks show a ↻ icon in the plan and the calendar. (#24)

### Changed
- Database schema version 9 (new tables `recurrence_rules` and `recurrence_exceptions`, new optional columns on `tasks`). Existing data is kept. (#24)

## [1.18.0] - 2026-11-20

### Added
- **Start and due times** (optional): in the task form, "Schedule & reminder" opens a sub-page with a start time on the task's day, a due date with an optional time (default 17:00) and the reminder. Times never change the order of the plan; moving or rolling over a task keeps its start time and due date. (#10)
- **Task reminders**: before the start time, or – without one – before the deadline, early enough for the work still left on the estimate. Default 15 min (adjustable), per task 5–60 min or off; the sub-page previews when it comes. A reminder whose time has passed while the start or deadline is still ahead comes at once, only once. (#10)
- Task tiles show the start time and the deadline ("Due Fri", in the warning colour within a day and the error colour when overdue); today's plan shows "2 tasks overdue" with their list. (#10)
- **Reminders & dates** settings page: task reminders, default lead time and due time, an optional **"Plan your day"** reminder on working days without tasks, and an optional **inactivity reminder** during working hours ("Ready for the next focus block?" after 60 min without focus by default). (#10)

### Changed
- The task form shows the basics first: title, day, estimate, category, priority, sub-tasks, description; the times are one tap away. (#10)
- The notification settings (permission hint, test notification) moved to the new "Reminders & dates" page. (#10)
- Database schema version 8 (new optional columns on `tasks`). Existing data is kept. (#10)

## [1.17.0] - 2026-11-20

### Added
- **Collapse completed tasks** (Settings → Planning, off by default): the plan list shows the open tasks first and the completed ones in a "Completed (n)" section at the end that you can show or hide; each board group does the same. Completing a task moves it into the section, un-completing moves it back. The open tasks can still be reordered. (#58)

## [1.16.0] - 2026-11-20

### Added
- **Category board**: every category shows a completion ring in its colour ("2 of 5 tasks done (40%)" as tooltip, a check mark when all are done) and the time tracked on its tasks that day (`HH:MM`). (#57)

## [1.15.1] - 2026-11-20

### Added
- A *Save* button (check mark) in the task form's app bar, reachable while the keyboard is open. (#56)

### Fixed
- Tapping outside a text field now closes the on-screen keyboard everywhere in the app (task form, sub-tasks, duration, categories, focus mode). Before, after adding sub-tasks the keyboard stayed open and covered the *Save* button. (#56)
- Scrolling the task form or focus mode closes the keyboard. (#56)

## [1.15.0] - 2026-11-20

### Added
- **Distraction inbox**: "Park a thought…" in focus mode saves a stray thought without leaving the task. Afterwards "3 parked thoughts" on the plan and the finished screen opens a review to turn each thought into a task for today or tomorrow, or dismiss it (with undo). (#28)
- **Interruptions**: leaving focus for 2 seconds or more (window loses focus, app switch, screen lock) counts as one interruption per switch, and "I got distracted" in the focus app bar counts one by hand. Leaving during a break doesn't count. (#28)
- "You were away 4 min." when you come back to focus after a minute or more. (#28)
- **Minimal focus layout**: only the timer, the task and its main button, switched in focus mode or in the settings and remembered. (#28)
- Statistics show the interruptions per focus hour and the most recent parked thoughts. (#28)

### Changed
- Database schema version 7 (new `inbox_items` table). Existing data is kept. (#28)

### Fixed
- Snack bars from focus mode no longer cover the plan after leaving focus. (#28)
- Completing a task from the plan ended its session at the system time instead of the app clock (only visible in tests). (#28)

## [1.14.0] - 2026-11-19

### Added
- **Breaks**: optional Pomodoro-style work/break cycles in Settings → Focus Mode → "Work in intervals" (off by default): work 25 min, short break 5 min, long break 15 min after every 4 intervals, all adjustable. (#27)
- Focus mode shows when the next break comes. At the end of a work interval the **break screen** counts down with a hint to stand up and look away, and offers "Skip break" and "Exit Focus". (#27)
- After the break: "Ready? Continue with <task>" – or focus continues on its own with "Continue automatically after a break". (#27)
- Notifications "Time for a break" and "Break is over" (channel *Breaks*), also while the app is in the background. (#27)
- Statistics show break time next to the focus time; breaks never count as focus time, nor towards the daily goal and streaks. (#27)

### Changed
- A task's target alarm never rings at the same moment as a break: if the target falls at the end of a work interval, the alarm rings once after the break. (#27)
- A break left open by a crash is closed at its last activity on the next start, without asking. (#27)

## [1.13.0] - 2026-11-19

### Added
- **Task categories**: create categories with one of ten colours in Settings → Categories; rename, recolour, reorder, archive or delete them (deleting asks first and keeps the tasks, without a category). (#2)
- A category picker in the task form, with "None" and "+ New". (#2)
- The plan list shows a coloured dot per task and filter chips (All / each category). New tasks get the filtered category. (#2)
- **Board view**: switch the plan between list and board in the app bar. The board groups the day's tasks by category – columns on wide screens, sections on phones – and dragging a task to another group changes its category. The choice is remembered. (#2)
- **Category focus**: "Focus on <category>" from the filter or a board header works through only that category's open tasks. (#2)
- Statistics show the focus time per category. (#2)

### Changed
- Database schema version 6 (new `categories` table, `tasks.category_id`). Existing tasks, sub-tasks, sessions and tracked time are kept. (#2)

## [1.12.0] - 2026-11-19

### Added
- **Daily focus goal**: choose a goal (off, 30 min … 8 h) and your working days (Mon–Fri by default) in Settings → Goals. (#21)
- A small ring next to the date in the plan shows today's focus time against the goal; tap it to open the statistics. (#21)
- **Streaks** in the statistics: the current and longest run of working days that reached the goal, and the goal days per month. Days off neither break nor extend a streak; today counts once the goal is reached. Past days are judged by the current goal. (#21)
- A dashed goal line in the focus chart of a week or month. (#21)
- "Finished for today" sums up the day: focus time, tasks done, goal reached or not, and the streak. (#21)
- While you focus, a notification tells you when the daily goal is reached (once a day, only on working days). (#21)

## [1.11.0] - 2026-11-19

### Added
- Statistics for a day, week, month or **year**, with ‹ › to browse earlier and later periods and a button back to the current one. (#20)
- A bar chart of focus time per hour (day), per day (week, month) or per month (year); tap a bar to see its value. (#20)
- **Planned vs. actual**: target durations vs. tracked time, and how long completed tasks took compared to their target (median). (#20)
- **Best focus hours**: a weekday × hour heatmap, the top 5 tasks by focus time, number and average length of sessions. (#20)
- An empty state that explains how to get statistics. (#20)

### Changed
- The average per day only counts days that have already passed, and statistics update while you focus. The cards are laid out in two columns on wide screens. (#20)

## [1.10.0] - 2026-11-19

### Added
- Past open tasks can be **moved** instead of only copied: the menu on a past task offers *Move to today*, *Move to…* (any day) and *Copy to…*. A move keeps the task's sub-tasks, tracked time and session history, so the old day's completion rate no longer counts it; *Undo* puts it back. Completed tasks can only be copied. (#23)
- On the first start of a day the app offers to move the open tasks of the last 7 days to today (all checked; untick the ones to leave). Turn it off in Settings → Planning → "Ask to move unfinished tasks". (#23)

### Changed
- "Start focus" moves a past day's (or yesterday's) open tasks with the same move as the task menu. (#23)

## [1.9.0] - 2026-11-19

### Added
- Calendar with week and month views, ‹ › navigation and a "Today" button; the view and day are part of the URL. (#22)
- Week view: the tasks of each day (completed ones struck through). On wide windows, long-press and drag a task to another day; on phones, use "Move to…". (#22)
- Month view: a grid starting on your locale's first day of the week, with done/total tasks and a focus-time bar per day; today is highlighted. Tap a day to open it in the plan. (#22)

## [1.8.0] - 2026-11-17

### Added
- A play button on every open task starts focus with that task. (#26)
- Focus mode: **Skip** moves the current task to the end (its time is kept), an **Up next** card, and a quick "Add sub-task" field. (#26)

### Changed
- "Start focus" uses the day shown in the plan: asks before working ahead on a future day, offers to move a past day's open tasks to today, and offers yesterday's open tasks when today has nothing left. (#26)

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
