import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/data/category_repository_impl.dart';
import 'package:focused_task/features/inbox/data/inbox_repository_impl.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

const _tasksV3 = '''CREATE TABLE tasks (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NULL,
    assigned_date INTEGER NOT NULL,
    sort_order TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    priority INTEGER NOT NULL DEFAULT 0,
    time_spent INTEGER NOT NULL DEFAULT 0,
    latest_start INTEGER NULL,
    target_duration_minutes INTEGER NULL
  )''';

const _todos = '''CREATE TABLE task_todos (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    sort_order TEXT NOT NULL
  )''';

/// Schema of version 4 (time and running session stored on `tasks`), as created by app versions up to 1.3.0.
const _tasksV4 = '''CREATE TABLE tasks (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NULL,
    assigned_date INTEGER NOT NULL,
    sort_order TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    priority INTEGER NOT NULL DEFAULT 0,
    time_spent INTEGER NOT NULL DEFAULT 0,
    latest_start INTEGER NULL,
    target_duration_minutes INTEGER NULL,
    last_seen_at INTEGER NULL
  )''';

/// Schema of version 5 (session log, no categories), as created by app versions 1.4.0 – 1.12.0.
const _tasksV5 = '''CREATE TABLE tasks (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NULL,
    assigned_date INTEGER NOT NULL,
    sort_order TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    priority INTEGER NOT NULL DEFAULT 0,
    time_spent INTEGER NOT NULL DEFAULT 0,
    target_duration_minutes INTEGER NULL
  )''';

const _sessionsV5 = '''CREATE TABLE focus_sessions (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NULL REFERENCES tasks (id) ON DELETE SET NULL,
    kind TEXT NOT NULL DEFAULT 'focus',
    started_at INTEGER NOT NULL,
    ended_at INTEGER NULL,
    last_seen_at INTEGER NOT NULL,
    end_reason TEXT NULL,
    interruptions INTEGER NOT NULL DEFAULT 0
  )''';

/// Schema of version 6 (categories, no inbox), as created by app versions 1.13.0 – 1.14.0.
const _tasksV6 = '''CREATE TABLE tasks (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NULL,
    assigned_date INTEGER NOT NULL,
    sort_order TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    priority INTEGER NOT NULL DEFAULT 0,
    time_spent INTEGER NOT NULL DEFAULT 0,
    target_duration_minutes INTEGER NULL,
    category_id INTEGER NULL REFERENCES categories (id) ON DELETE SET NULL
  )''';

const _categoriesV6 = '''CREATE TABLE categories (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    color INTEGER NOT NULL,
    icon TEXT NULL,
    sort_order TEXT NOT NULL,
    archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))
  )''';

/// Inbox of version 7 (#28), as created by app versions 1.15.0 – 1.17.0.
const _inboxV7 = '''CREATE TABLE inbox_items (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    session_id INTEGER NULL REFERENCES focus_sessions (id) ON DELETE SET NULL,
    resolved_at INTEGER NULL
  )''';

/// Drift stores `DateTime` as Unix seconds.
int _seconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

AppDatabase _open(List<String> statements) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in statements) {
          raw.execute(statement);
        }
      },
    ),
  );
}

void main() {
  test('migrates v3 databases to the current version and keeps existing data', () async {
    final database = _open([
      _tasksV3,
      _todos,
      "INSERT INTO tasks (title, assigned_date, sort_order, time_spent, latest_start) VALUES ('legacy', 1767222000, 'a0', 600000, 1767225600)",
      'PRAGMA user_version = 3',
    ]);
    addTearDown(database.close);

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'legacy');
    expect(task.timeSpent, 600000);

    final open = (await FocusSessionRepositoryImpl(database).unfinishedSessions()).single;
    expect(open.taskId, task.id);
    expect(open.startedAt, DateTime.fromMillisecondsSinceEpoch(1767225600 * 1000));
    expect(open.lastActivityAt, open.startedAt, reason: 'legacy sessions have no heartbeat');

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, database.schemaVersion);
    expect(task.categoryId, isNull, reason: 'the rebuilt tasks table already has category_id');
    expect(await database.select(database.categories).get(), isEmpty);
  });

  group('v4 → v5 (session log)', () {
    final day = DateTime(2026, 11, 10);
    final runningSince = DateTime(2026, 11, 17, 8);
    final lastSeen = DateTime(2026, 11, 17, 8, 40);

    late AppDatabase database;

    setUp(() {
      database = _open([
        _tasksV4,
        _todos,
        "INSERT INTO tasks (id, title, assigned_date, sort_order, is_completed, time_spent) VALUES (1, 'done', ${_seconds(day)}, 'a0', 1, 1800000)",
        "INSERT INTO tasks (id, title, assigned_date, sort_order, time_spent, latest_start, last_seen_at) VALUES (2, 'running', ${_seconds(day)}, 'a1', 600000, ${_seconds(runningSince)}, ${_seconds(lastSeen)})",
        "INSERT INTO tasks (id, title, assigned_date, sort_order, target_duration_minutes) VALUES (3, 'untouched', ${_seconds(day)}, 'a2', 25)",
        "INSERT INTO task_todos (task_id, title, sort_order) VALUES (1, 'sub-task', 'a0')",
        'PRAGMA user_version = 4',
      ]);
    });
    tearDown(() => database.close());

    test('keeps tasks, totals and sub-tasks', () async {
      final tasks = TaskRepositoryImpl(database);

      final all = await tasks.getTasksForDay(day);
      expect(all.map((task) => (task.title, task.timeSpent, task.isCompleted)), [('done', 1800000, true), ('running', 600000, false), ('untouched', 0, false)]);
      expect(all.first.todos.single.title, 'sub-task');
      expect(all.last.targetDurationMinutes, 25);

      final columns = await database.customSelect('PRAGMA table_info(tasks)').get();
      expect(columns.map((column) => column.read<String>('name')), isNot(contains('latest_start')));
      expect(columns.map((column) => column.read<String>('name')), isNot(contains('last_seen_at')));
    });

    test('moves tracked time into closed sessions at noon of the assigned day', () async {
      final sessions = await database.select(database.focusSessions).get();
      final migrated = sessions.where((session) => session.endReason == 'migrated').toList();

      expect(migrated.map((session) => (session.taskId, session.startedAt, session.endedAt!.difference(session.startedAt))), [
        (1, DateTime(2026, 11, 10, 12), const Duration(minutes: 30)),
        (2, DateTime(2026, 11, 10, 12), const Duration(minutes: 10)),
      ]);
      final stats = await TaskRepositoryImpl(database).getStatsReport(StatsQuery(range: DateRange(day, day), granularity: StatsGranularity.day));
      expect(stats.focusTotal, const Duration(minutes: 40), reason: 'totals stay the same');
    });

    test('a running session stays recoverable with its heartbeat', () async {
      final open = (await FocusSessionRepositoryImpl(database).unfinishedSessions()).single;

      expect((open.taskId, open.taskTitle, open.startedAt, open.lastActivityAt), (2, 'running', runningSince, lastSeen));
      expect((await TaskRepositoryImpl(database).getTaskById(2))!.isRunning, isTrue);
    });

    test('foreign keys still work after rebuilding the tasks table', () async {
      await TaskRepositoryImpl(database).deleteTask(1);

      expect(await database.select(database.taskTodos).get(), isEmpty, reason: 'sub-tasks cascade');
      final sessions = await database.select(database.focusSessions).get();
      expect(sessions.where((session) => session.taskId == null), hasLength(1), reason: 'sessions are kept');
      expect((await FocusSessionRepositoryImpl(database).focusTimeByDay(DateRange(day, day)))[day], const Duration(minutes: 40));
    });
  });

  group('v5 → v6 (categories)', () {
    final day = DateTime(2026, 11, 10);
    late AppDatabase database;

    setUp(() {
      database = _open([
        _tasksV5,
        _todos,
        _sessionsV5,
        'CREATE INDEX focus_sessions_started_at ON focus_sessions (started_at)',
        "INSERT INTO tasks (id, title, assigned_date, sort_order, is_completed, time_spent, target_duration_minutes) VALUES (1, 'done', ${_seconds(day)}, 'a0', 1, 1800000, 25)",
        "INSERT INTO tasks (id, title, assigned_date, sort_order, priority) VALUES (2, 'open', ${_seconds(day)}, 'a1', 2)",
        "INSERT INTO task_todos (task_id, title, sort_order) VALUES (1, 'sub-task', 'a0')",
        "INSERT INTO focus_sessions (task_id, started_at, ended_at, last_seen_at, end_reason) VALUES (1, ${_seconds(day.add(const Duration(hours: 9)))}, ${_seconds(day.add(const Duration(hours: 9, minutes: 30)))}, ${_seconds(day.add(const Duration(hours: 9, minutes: 30)))}, 'completed')",
        'INSERT INTO focus_sessions (task_id, started_at, last_seen_at) VALUES (2, ${_seconds(day.add(const Duration(hours: 10)))}, ${_seconds(day.add(const Duration(hours: 10, minutes: 5)))})',
        'PRAGMA user_version = 5',
      ]);
    });
    tearDown(() => database.close());

    test('keeps tasks, sub-tasks, sessions and tracked time; tasks have no category', () async {
      final tasks = TaskRepositoryImpl(database);

      final all = await tasks.getTasksForDay(day);
      expect(all.map((task) => (task.title, task.timeSpent, task.isCompleted, task.categoryId)), [('done', 1800000, true, null), ('open', 0, false, null)]);
      expect(all.first.todos.single.title, 'sub-task');
      expect(all.first.targetDurationMinutes, 25);
      expect(all.last.isRunning, isTrue, reason: 'the open session stays recoverable');
      expect(await database.select(database.focusSessions).get(), hasLength(2));

      final stats = await tasks.getStatsReport(StatsQuery(range: DateRange(day, day), granularity: StatsGranularity.day));
      expect(stats.focusTotal, const Duration(minutes: 35));
      expect(stats.hasCategorizedFocus, isFalse);

      final version = await database.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, database.schemaVersion);
    });

    test('tasks can get a category; deleting it leaves them uncategorised', () async {
      final categories = CategoryRepositoryImpl(database);
      final tasks = TaskRepositoryImpl(database);
      final work = await categories.createCategory(name: 'Work', colorIndex: 3);
      await categories.setTaskCategory(taskId: 1, categoryId: work);
      expect((await tasks.getTaskById(1))!.categoryId, work);

      await categories.deleteCategory(work);

      final task = (await tasks.getTaskById(1))!;
      expect((task.title, task.categoryId, task.timeSpent), ('done', null, 1800000));
      expect(await database.select(database.taskTodos).get(), hasLength(1), reason: 'nothing cascades from a category');
    });
  });

  group('v6 → v7 (distraction inbox)', () {
    final day = DateTime(2026, 11, 10);
    late AppDatabase database;

    setUp(() {
      database = _open([
        _tasksV6,
        _todos,
        _sessionsV5,
        _categoriesV6,
        'CREATE INDEX focus_sessions_started_at ON focus_sessions (started_at)',
        "INSERT INTO categories (id, name, color, sort_order) VALUES (1, 'Work', 2, 'a0')",
        "INSERT INTO tasks (id, title, assigned_date, sort_order, time_spent, category_id) VALUES (1, 'report', ${_seconds(day)}, 'a0', 1800000, 1)",
        "INSERT INTO focus_sessions (task_id, started_at, ended_at, last_seen_at, end_reason, interruptions) VALUES (1, ${_seconds(day.add(const Duration(hours: 9)))}, ${_seconds(day.add(const Duration(hours: 9, minutes: 30)))}, ${_seconds(day.add(const Duration(hours: 9, minutes: 30)))}, 'paused', 2)",
        'PRAGMA user_version = 6',
      ]);
    });
    tearDown(() => database.close());

    test('keeps tasks, categories and sessions; the inbox starts empty', () async {
      final task = (await TaskRepositoryImpl(database).getTaskById(1))!;
      expect((task.title, task.timeSpent, task.categoryId), ('report', 1800000, 1));
      expect((await database.select(database.focusSessions).getSingle()).interruptions, 2);
      expect(await database.select(database.inboxItems).get(), isEmpty);

      final version = await database.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, database.schemaVersion);
    });

    test('items can be parked; deleting their session keeps them', () async {
      final inbox = InboxRepositoryImpl(database);
      await inbox.addInboxItem(text: '  call the bank ', at: day.add(const Duration(hours: 9, minutes: 10)), sessionId: 1);
      final item = (await inbox.watchOpenInboxItems().first).single;
      expect((item.text, item.sessionId), ('call the bank', 1));

      await database.customStatement('DELETE FROM focus_sessions');
      final kept = await database.select(database.inboxItems).getSingle();
      expect((kept.content, kept.sessionId), ('call the bank', null), reason: 'ON DELETE SET NULL');
    });
  });

  group('v7 → v8 (start/due times, #10)', () {
    final day = DateTime(2026, 11, 10);
    late AppDatabase database;

    setUp(() {
      database = _open([
        _tasksV6,
        _todos,
        _sessionsV5,
        _categoriesV6,
        _inboxV7,
        'CREATE INDEX focus_sessions_started_at ON focus_sessions (started_at)',
        "INSERT INTO tasks (id, title, assigned_date, sort_order, time_spent, target_duration_minutes) VALUES (1, 'report', ${_seconds(day)}, 'a0', 1800000, 60)",
        "INSERT INTO inbox_items (text, created_at) VALUES ('call the bank', ${_seconds(day)})",
        'PRAGMA user_version = 7',
      ]);
    });
    tearDown(() => database.close());

    test('existing tasks keep their data and have no times and no reminder', () async {
      final task = (await TaskRepositoryImpl(database).getTaskById(1))!;
      expect((task.title, task.timeSpent, task.targetDurationMinutes), ('report', 1800000, 60));
      expect(task.schedule, TaskSchedule.none);
      expect(await database.select(database.inboxItems).get(), hasLength(1));

      final version = await database.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, database.schemaVersion);
    });

    test('times can be set afterwards', () async {
      final tasks = TaskRepositoryImpl(database);
      await tasks.updateTaskDetails(
        taskId: 1,
        title: 'report',
        categoryId: null,
        schedule: TaskSchedule(startMinute: 540, dueDate: day),
      );
      expect((await tasks.getTaskById(1))!.schedule, TaskSchedule(startMinute: 540, dueDate: day));
    });
  });
}
