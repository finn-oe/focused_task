import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:focused_task/core/database/tables/focus_sessions_table.dart';
import 'package:focused_task/core/database/tables/tasks_table.dart';
import 'package:focused_task/core/database/tables/task_todos_table.dart';
import 'package:focused_task/core/utils/date_utils.dart';

part 'app_database.g.dart';

class TaskWithTodos {
  TaskWithTodos(this.task, this.todos, [this.openSession]);
  final Task task;
  final List<TaskTodo> todos;

  /// The task's running (or never closed) focus session.
  final FocusSessionRow? openSession;
}

/// A session with the title of its task (if the task still exists).
class SessionWithTitle {
  SessionWithTitle(this.session, this.taskTitle);
  final FocusSessionRow session;
  final String? taskTitle;
}

@DriftDatabase(tables: [Tasks, TaskTodos, FocusSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(tasks, tasks.targetDurationMinutes);
        }
        if (from < 3) {
          await m.createTable(taskTodos);
        }
        if (from < 4) {
          // Heartbeat column of schema 4; moved to `focus_sessions` in schema 5.
          await customStatement('ALTER TABLE tasks ADD COLUMN last_seen_at INTEGER NULL');
        }
        if (from < 5) {
          await _migrateToSessionLog(m);
        }
      },
      beforeOpen: (details) async {
        // Essential for SQLite to respect onDelete: KeyAction.cascade
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// v4 → v5: tracked time and running sessions move from `tasks` into `focus_sessions`.
  ///
  /// Each task with tracked time gets one closed session on its assigned day at 12:00 local time; a running session
  /// stays open (and recoverable). Foreign keys are still off here (they are enabled in `beforeOpen`), so rebuilding
  /// `tasks` doesn't cascade to the sub-tasks.
  Future<void> _migrateToSessionLog(Migrator m) async {
    await m.createTable(focusSessions);
    await m.createIndex(focusSessionsStartedAt);

    final legacy = await customSelect('SELECT id, assigned_date, time_spent, latest_start, last_seen_at FROM tasks').get();
    for (final row in legacy) {
      final taskId = row.read<int>('id');
      final timeSpent = row.read<int>('time_spent');
      if (timeSpent > 0) {
        final day = row.read<DateTime>('assigned_date');
        final start = DateTime(day.year, day.month, day.day, 12);
        final end = start.add(Duration(milliseconds: timeSpent));
        await into(
          focusSessions,
        ).insert(FocusSessionsCompanion.insert(taskId: Value(taskId), startedAt: start, endedAt: Value(end), lastSeenAt: end, endReason: const Value('migrated')));
      }
      final latestStart = row.readNullable<DateTime>('latest_start');
      if (latestStart != null) {
        final lastSeen = row.readNullable<DateTime>('last_seen_at') ?? latestStart;
        await into(focusSessions).insert(FocusSessionsCompanion.insert(taskId: Value(taskId), startedAt: latestStart, lastSeenAt: lastSeen));
      }
    }

    await m.alterTable(TableMigration(tasks));
  }

  Expression<bool> _isInDay(Tasks table, DateTime day) {
    return table.assignedDate.isBiggerOrEqualValue(day.dateOnly) & table.assignedDate.isSmallerThanValue(day.nextDay);
  }

  Stream<List<TaskWithTodos>> watchTasksForDay(DateTime day) {
    final query =
        select(tasks).join([
            leftOuterJoin(taskTodos, taskTodos.taskId.equalsExp(tasks.id)),
            leftOuterJoin(focusSessions, focusSessions.taskId.equalsExp(tasks.id) & focusSessions.endedAt.isNull()),
          ])
          ..where(_isInDay(tasks, day))
          ..orderBy([OrderingTerm.asc(tasks.sortOrder), OrderingTerm.asc(taskTodos.sortOrder)]);

    return query.watch().map((rows) {
      final groupedTasks = <Task, List<TaskTodo>>{};
      final openSessions = <int, FocusSessionRow>{};
      for (final row in rows) {
        final task = row.readTable(tasks);
        final todo = row.readTableOrNull(taskTodos);
        final session = row.readTableOrNull(focusSessions);
        groupedTasks.putIfAbsent(task, () => []);
        if (todo != null) {
          groupedTasks[task]!.add(todo);
        }
        if (session != null) {
          openSessions[task.id] = session;
        }
      }

      return groupedTasks.entries.map((entry) => TaskWithTodos(entry.key, entry.value, openSessions[entry.key.id])).toList();
    });
  }

  Future<List<TaskWithTodos>> getTasksForDay(DateTime day) async {
    final tasksList =
        await (select(tasks)
              ..where((task) => _isInDay(task, day))
              ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)]))
            .get();

    final result = <TaskWithTodos>[];
    for (final task in tasksList) {
      final todos = await (select(taskTodos)..where((t) => t.taskId.equals(task.id))).get();
      result.add(TaskWithTodos(task, todos, await _openSessionOf(task.id)));
    }
    return result;
  }

  Future<FocusSessionRow?> _openSessionOf(int taskId) {
    return (select(focusSessions)
          ..where((session) => session.taskId.equals(taskId) & session.endedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<Task>> getTasksInRange({required DateTime start, required DateTime end}) {
    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(start.dateOnly) & task.assignedDate.isSmallerThanValue(end.nextDay))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)]);

    return query.get();
  }

  Future<TaskWithTodos?> getTaskById(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return null;

    final todos = await (select(taskTodos)..where((t) => t.taskId.equals(taskId))).get();
    return TaskWithTodos(task, todos, await _openSessionOf(taskId));
  }

  Future<Task?> getNextIncompleteTaskForDay(DateTime day) {
    final query = select(tasks)
      ..where((task) => _isInDay(task, day) & task.isCompleted.equals(false))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<int> createTask(TasksCompanion companion) async {
    final normalizedAssignedDate = companion.assignedDate.value.dateOnly;
    return into(tasks).insert(companion.copyWith(assignedDate: Value(normalizedAssignedDate)));
  }

  Future<int> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate}) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        title: Value(title),
        description: Value(description),
        targetDurationMinutes: Value(targetDurationMinutes),
        assignedDate: assignedDate != null ? Value(assignedDate.dateOnly) : const Value.absent(),
      ),
    );
  }

  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(sortOrder: Value(sortOrder)));
  }

  /// Marks a task as (in)complete. Completing a task also closes a running session, so its timer
  /// never keeps counting after the task is done.
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted, DateTime? at}) async {
    if (isCompleted) {
      return completeTask(taskId: taskId, completedAt: at ?? DateTime.now());
    }
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(const TasksCompanion(isCompleted: Value(false)));
  }

  /// Marks [taskId] as completed and closes its open session at [completedAt].
  Future<void> completeTask({required int taskId, required DateTime completedAt}) {
    return transaction(() async {
      final open = await _openSessionOf(taskId);
      if (open != null) {
        await endSession(open.id, completedAt, 'completed');
      }
      await (update(tasks)..where((task) => task.id.equals(taskId))).write(const TasksCompanion(isCompleted: Value(true)));
    });
  }

  // --- Focus sessions -------------------------------------------------------------------------------------------

  Future<FocusSessionRow?> getOpenSession() {
    return (select(focusSessions)
          ..where((session) => session.endedAt.isNull())
          ..orderBy([(session) => OrderingTerm.desc(session.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Starts a session. A session that is still open is closed at its last heartbeat first (at most one open session).
  Future<FocusSessionRow> startSession({int? taskId, required String kind, required DateTime at}) {
    return transaction(() async {
      for (final open in await (select(focusSessions)..where((session) => session.endedAt.isNull())).get()) {
        final lastActivity = open.lastSeenAt.isAfter(open.startedAt) ? open.lastSeenAt : open.startedAt;
        await endSession(open.id, lastActivity, 'recovered');
      }
      final id = await into(focusSessions).insert(FocusSessionsCompanion.insert(taskId: Value(taskId), kind: Value(kind), startedAt: at, lastSeenAt: at));
      return (select(focusSessions)..where((session) => session.id.equals(id))).getSingle();
    });
  }

  Future<void> sessionHeartbeat(int id, DateTime at) async {
    await (update(focusSessions)..where((session) => session.id.equals(id) & session.endedAt.isNull())).write(FocusSessionsCompanion(lastSeenAt: Value(at)));
  }

  /// Closes session [id] at [at] and adds its focus time to the task's cached total. `discarded` drops the time.
  Future<void> endSession(int id, DateTime at, String reason) {
    return transaction(() async {
      final session = await (select(focusSessions)..where((row) => row.id.equals(id))).getSingleOrNull();
      if (session == null || session.endedAt != null) {
        return;
      }
      final end = reason == 'discarded' || at.isBefore(session.startedAt) ? session.startedAt : at;
      await (update(focusSessions)..where((row) => row.id.equals(id))).write(FocusSessionsCompanion(endedAt: Value(end), endReason: Value(reason)));
      await _addTrackedTime(session.taskId, session.kind, end.difference(session.startedAt));
    });
  }

  Future<void> _addTrackedTime(int? taskId, String kind, Duration duration) async {
    if (taskId == null || kind != 'focus' || duration <= Duration.zero) {
      return;
    }
    await customUpdate(
      'UPDATE tasks SET time_spent = time_spent + ? WHERE id = ?',
      variables: [Variable.withInt(duration.inMilliseconds), Variable.withInt(taskId)],
      updates: {tasks},
      updateKind: UpdateKind.update,
    );
  }

  /// Adds a closed session of [duration] starting at [start] (manual correction).
  Future<void> addManualSession({required int taskId, required DateTime start, required Duration duration}) {
    return transaction(() async {
      final end = start.add(duration);
      await into(
        focusSessions,
      ).insert(FocusSessionsCompanion.insert(taskId: Value(taskId), startedAt: start, endedAt: Value(end), lastSeenAt: end, endReason: const Value('manual')));
      await _addTrackedTime(taskId, 'focus', duration);
    });
  }

  /// Sessions that were never closed, with their task titles.
  Future<List<SessionWithTitle>> getUnfinishedSessions() async {
    final query = select(focusSessions).join([leftOuterJoin(tasks, tasks.id.equalsExp(focusSessions.taskId))])
      ..where(focusSessions.endedAt.isNull())
      ..orderBy([OrderingTerm.asc(focusSessions.startedAt)]);
    final rows = await query.get();
    return rows.map((row) => SessionWithTitle(row.readTable(focusSessions), row.readTableOrNull(tasks)?.title)).toList();
  }

  SimpleSelectStatement<$FocusSessionsTable, FocusSessionRow> _overlapping(DateTime start, DateTime endExclusive) {
    return select(focusSessions)
      ..where((session) => session.startedAt.isSmallerThanValue(endExclusive) & (session.endedAt.isNull() | session.endedAt.isBiggerThanValue(start)))
      ..orderBy([(session) => OrderingTerm.asc(session.startedAt)]);
  }

  Future<List<FocusSessionRow>> getSessionsOverlapping(DateTime start, DateTime endExclusive) => _overlapping(start, endExclusive).get();

  Stream<List<FocusSessionRow>> watchSessionsOverlapping(DateTime start, DateTime endExclusive) => _overlapping(start, endExclusive).watch();

  Future<int> deleteTask(int taskId) {
    return (delete(tasks)..where((t) => t.id.equals(taskId))).go();
  }

  /// Completed tasks before [cutoffDay] without an open session (an unfinished session must stay recoverable).
  Expression<bool> _isCleanupCandidate(Tasks task, DateTime cutoffDay) {
    final openSession = select(focusSessions)..where((session) => session.taskId.equalsExp(task.id) & session.endedAt.isNull());
    return task.isCompleted.equals(true) & task.assignedDate.isSmallerThanValue(cutoffDay.dateOnly) & notExistsQuery(openSession);
  }

  Future<int> deleteCompletedTasksBefore(DateTime cutoffDay) {
    return (delete(tasks)..where((task) => _isCleanupCandidate(task, cutoffDay))).go();
  }

  Future<int> countCompletedTasksBefore(DateTime cutoffDay) {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([count])
      ..where(_isCleanupCandidate(tasks, cutoffDay));
    return query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<void> setTodoCompletion({required int todoId, required bool isCompleted}) async {
    await (update(taskTodos)..where((todo) => todo.id.equals(todoId))).write(TaskTodosCompanion(isCompleted: Value(isCompleted)));
  }

  Future<void> replaceTaskTodos(int taskId, List<TaskTodo> newTodos) {
    return transaction(() async {
      await (delete(taskTodos)..where((t) => t.taskId.equals(taskId))).go();
      for (final todo in newTodos) {
        await into(taskTodos).insert(TaskTodosCompanion.insert(taskId: taskId, title: todo.title, isCompleted: Value(todo.isCompleted), sortOrder: todo.sortOrder));
      }
    });
  }
}

/// File name (without `.sqlite`) of the database.
///
/// Native: `<application documents>/focused_task.sqlite` – the path used since the first release, so existing data is
/// kept. Web: stored in OPFS or IndexedDB, depending on what the browser supports.
const databaseName = 'focused_task';

QueryExecutor _openConnection() {
  return driftDatabase(
    name: databaseName,
    native: const DriftNativeOptions(databaseDirectory: getApplicationDocumentsDirectory),
    web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
  );
}
