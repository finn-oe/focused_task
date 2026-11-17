import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';

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
      final stats = await TaskRepositoryImpl(database).getTaskStats(start: day, end: day);
      expect(stats.totalFocusMinutes, 40, reason: 'totals stay the same');
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
}
