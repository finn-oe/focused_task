import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:focused_task/core/database/tables/categories_table.dart';
import 'package:focused_task/core/database/tables/focus_sessions_table.dart';
import 'package:focused_task/core/database/tables/inbox_items_table.dart';
import 'package:focused_task/core/database/tables/recurrence_rules_table.dart';
import 'package:focused_task/core/database/tables/tasks_table.dart';
import 'package:focused_task/core/database/tables/task_todos_table.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';

part 'app_database.g.dart';

class TaskWithTodos {
  TaskWithTodos(this.task, this.todos, [this.openSession]);
  final Task task;
  final List<TaskTodo> todos;

  /// The task's running (or never closed) focus session.
  final FocusSessionRow? openSession;
}

/// A session with the title and category of its task (if the task still exists).
class SessionWithTitle {
  SessionWithTitle(this.session, this.taskTitle, [this.categoryId]);
  final FocusSessionRow session;
  final String? taskTitle;
  final int? categoryId;
}

@DriftDatabase(tables: [Categories, RecurrenceRules, RecurrenceExceptions, Tasks, TaskTodos, FocusSessions, InboxItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

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
          // Rebuilds `tasks` in the current schema, so `category_id` (schema 6), the times (schema 8) and the recurrence
          // columns (schema 9) already exist afterwards.
          await _migrateToSessionLog(m);
        }
        if (from < 6) {
          await m.createTable(categories);
          if (from >= 5) await m.addColumn(tasks, tasks.categoryId);
        }
        if (from < 7) {
          await m.createTable(inboxItems);
        }
        // Start/due times and reminders (#10); existing tasks have none. Rebuilt databases (from < 5) have them already.
        if (from < 8 && from >= 5) {
          await m.addColumn(tasks, tasks.startMinute);
          await m.addColumn(tasks, tasks.dueDate);
          await m.addColumn(tasks, tasks.dueMinute);
          await m.addColumn(tasks, tasks.reminderMinutes);
          await m.addColumn(tasks, tasks.reminderOff);
        }
        // Recurring tasks (#24). Rebuilt databases (from < 5) have the task columns already.
        if (from < 9) {
          await m.createTable(recurrenceRules);
          await m.createTable(recurrenceExceptions);
          if (from >= 5) {
            await m.addColumn(tasks, tasks.recurrenceId);
            await m.addColumn(tasks, tasks.occurrenceDate);
          }
          await m.createIndex(tasksOccurrence);
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

    await m.alterTable(
      TableMigration(
        tasks,
        newColumns: [tasks.categoryId, tasks.startMinute, tasks.dueDate, tasks.dueMinute, tasks.reminderMinutes, tasks.reminderOff, tasks.recurrenceId, tasks.occurrenceDate],
      ),
    );
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

  /// Tasks assigned to `[start, end]` (inclusive dates), by day and then by sort order.
  Stream<List<Task>> watchTasksInRange({required DateTime start, required DateTime end}) {
    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(start.dateOnly) & task.assignedDate.isSmallerThanValue(end.nextDay))
      ..orderBy([(task) => OrderingTerm.asc(task.assignedDate), (task) => OrderingTerm.asc(task.sortOrder)]);

    return query.watch();
  }

  /// Number of tasks and of completed tasks per assigned day in `[start, end]`, in one grouped query.
  Future<List<({DateTime day, int total, int completed})>> countTasksByDay({required DateTime start, required DateTime end}) {
    final total = tasks.id.count();
    final completed = tasks.id.count(filter: tasks.isCompleted.equals(true));
    final query = selectOnly(tasks)
      ..addColumns([tasks.assignedDate, total, completed])
      ..where(tasks.assignedDate.isBiggerOrEqualValue(start.dateOnly) & tasks.assignedDate.isSmallerThanValue(end.nextDay))
      ..groupBy([tasks.assignedDate]);

    return query.map((row) => (day: row.read(tasks.assignedDate)!, total: row.read(total) ?? 0, completed: row.read(completed) ?? 0)).get();
  }

  /// Open tasks assigned to `[start, end]` (calendar dates, inclusive), by day and then plan order.
  Future<List<TaskWithTodos>> getOpenTasksInRange({required DateTime start, required DateTime end}) async {
    final tasksList =
        await (select(tasks)
              ..where((task) => task.assignedDate.isBiggerOrEqualValue(start.dateOnly) & task.assignedDate.isSmallerThanValue(end.nextDay) & task.isCompleted.equals(false))
              ..orderBy([(task) => OrderingTerm.asc(task.assignedDate), (task) => OrderingTerm.asc(task.sortOrder)]))
            .get();

    final result = <TaskWithTodos>[];
    for (final task in tasksList) {
      final todos = await (select(taskTodos)..where((t) => t.taskId.equals(task.id))).get();
      result.add(TaskWithTodos(task, todos, await _openSessionOf(task.id)));
    }
    return result;
  }

  /// Moves the open tasks among [taskIds] to the day [to], after the tasks already there and in the given order, in one
  /// transaction. Completed tasks and tasks already on [to] stay where they are. Sub-tasks and focus sessions belong to
  /// the task, so they move with it while the sessions keep the time they happened.
  ///
  /// Returns the ids of the moved tasks.
  Future<List<int>> moveTasks({required List<int> taskIds, required DateTime to}) {
    final day = to.dateOnly;
    return transaction(() async {
      final target =
          await (select(tasks)
                ..where((task) => _isInDay(task, day))
                ..orderBy([(task) => OrderingTerm.desc(task.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      var last = target?.sortOrder;
      final moved = <int>[];
      for (final id in taskIds) {
        final task = await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (task == null || task.isCompleted || task.assignedDate.isSameDate(day)) continue;
        last = FractionalIndexer.between(last, null);
        await (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(assignedDate: Value(day), sortOrder: Value(last)));
        moved.add(id);
      }
      return moved;
    });
  }

  /// Open tasks with a start time or a deadline (#10), without sub-tasks.
  Stream<List<Task>> watchScheduledOpenTasks() {
    return (select(tasks)
          ..where((task) => task.isCompleted.equals(false) & (task.startMinute.isNotNull() | task.dueDate.isNotNull()))
          ..orderBy([(task) => OrderingTerm.asc(task.assignedDate), (task) => OrderingTerm.asc(task.sortOrder)]))
        .watch();
  }

  Future<TaskWithTodos?> getTaskById(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return null;

    final todos = await (select(taskTodos)..where((t) => t.taskId.equals(taskId))).get();
    return TaskWithTodos(task, todos, await _openSessionOf(taskId));
  }

  Future<int> createTask(TasksCompanion companion) async {
    final normalizedAssignedDate = companion.assignedDate.value.dateOnly;
    return into(tasks).insert(companion.copyWith(assignedDate: Value(normalizedAssignedDate)));
  }

  Future<int> updateTaskDetails({
    required int taskId,
    required String title,
    String? description,
    int? targetDurationMinutes,
    DateTime? assignedDate,
    int? priority,
    required int? categoryId,
    TasksCompanion schedule = const TasksCompanion(),
  }) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        startMinute: schedule.startMinute,
        dueDate: schedule.dueDate,
        dueMinute: schedule.dueMinute,
        reminderMinutes: schedule.reminderMinutes,
        reminderOff: schedule.reminderOff,
        title: Value(title),
        categoryId: Value(categoryId),
        description: Value(description),
        targetDurationMinutes: Value(targetDurationMinutes),
        assignedDate: assignedDate != null ? Value(assignedDate.dateOnly) : const Value.absent(),
        priority: priority != null ? Value(priority) : const Value.absent(),
      ),
    );
  }

  Future<void> setTaskCategory({required int taskId, required int? categoryId}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(categoryId: Value(categoryId)));
  }

  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(sortOrder: Value(sortOrder)));
  }

  /// Marks a task as (in)complete. Completing a task also closes a running session, so its timer
  /// never keeps counting after the task is done.
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted, DateTime? at}) async {
    if (isCompleted) {
      return completeTask(taskId: taskId, completedAt: at ?? clock.now());
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

  /// Sessions overlapping `[start, endExclusive)` with the titles of their tasks (`null` for deleted tasks).
  Future<List<SessionWithTitle>> getSessionsWithTitlesOverlapping(DateTime start, DateTime endExclusive) async {
    final query = select(focusSessions).join([leftOuterJoin(tasks, tasks.id.equalsExp(focusSessions.taskId))])
      ..where(focusSessions.startedAt.isSmallerThanValue(endExclusive) & (focusSessions.endedAt.isNull() | focusSessions.endedAt.isBiggerThanValue(start)))
      ..orderBy([OrderingTerm.asc(focusSessions.startedAt)]);
    final rows = await query.get();
    return rows.map((row) {
      final task = row.readTableOrNull(tasks);
      return SessionWithTitle(row.readTable(focusSessions), task?.title, task?.categoryId);
    }).toList();
  }

  Stream<List<FocusSessionRow>> watchSessionsOverlapping(DateTime start, DateTime endExclusive) => _overlapping(start, endExclusive).watch();

  /// Counts one interruption (#28) on session [id], also if it has ended meanwhile.
  Future<void> addInterruption(int id) async {
    await customUpdate(
      'UPDATE focus_sessions SET interruptions = interruptions + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {focusSessions},
      updateKind: UpdateKind.update,
    );
  }

  // --- Distraction inbox ----------------------------------------------------------------------------------------

  Future<int> addInboxItem(InboxItemsCompanion companion) => into(inboxItems).insert(companion);

  /// Items still waiting for review, oldest first.
  Stream<List<InboxItemRow>> watchOpenInboxItems() {
    return (select(inboxItems)
          ..where((item) => item.resolvedAt.isNull())
          ..orderBy([(item) => OrderingTerm.asc(item.createdAt), (item) => OrderingTerm.asc(item.id)]))
        .watch();
  }

  /// Items parked in `[start, endExclusive)`, newest first, at most [limit].
  Stream<List<InboxItemRow>> watchInboxItemsCreated(DateTime start, DateTime endExclusive, {required int limit}) {
    return (select(inboxItems)
          ..where((item) => item.createdAt.isBiggerOrEqualValue(start) & item.createdAt.isSmallerThanValue(endExclusive))
          ..orderBy([(item) => OrderingTerm.desc(item.createdAt), (item) => OrderingTerm.desc(item.id)])
          ..limit(limit))
        .watch();
  }

  /// Marks item [id] as reviewed at [at], or as waiting again with `null`.
  Future<void> setInboxItemResolved(int id, DateTime? at) async {
    await (update(inboxItems)..where((item) => item.id.equals(id))).write(InboxItemsCompanion(resolvedAt: Value(at)));
  }

  // --- Recurring tasks (#24) ------------------------------------------------------------------------------------

  Future<RecurrenceRuleRow?> getRecurrenceRule(int id) => (select(recurrenceRules)..where((rule) => rule.id.equals(id))).getSingleOrNull();

  /// Rules that can have occurrences in `[start, end]` (inclusive dates).
  Future<List<RecurrenceRuleRow>> getRecurrenceRulesOverlapping(DateTime start, DateTime end) {
    return (select(recurrenceRules)
          ..where((rule) => rule.startDate.isSmallerThanValue(end.nextDay) & (rule.endDate.isNull() | rule.endDate.isBiggerOrEqualValue(start.dateOnly)))
          ..orderBy([(rule) => OrderingTerm.asc(rule.id)]))
        .get();
  }

  /// Deleted occurrences of [ruleIds] in `[start, end]`.
  Future<List<RecurrenceExceptionRow>> getRecurrenceExceptions(List<int> ruleIds, DateTime start, DateTime end) {
    return (select(
      recurrenceExceptions,
    )..where((exception) => exception.ruleId.isIn(ruleIds) & exception.date.isBiggerOrEqualValue(start.dateOnly) & exception.date.isSmallerThanValue(end.nextDay))).get();
  }

  /// `(rule, date)` of the occurrences of [ruleIds] that exist (as tasks) for dates in `[start, end]`.
  Future<Set<(int, DateTime)>> getExistingOccurrences(List<int> ruleIds, DateTime start, DateTime end) async {
    final rows = await (select(
      tasks,
    )..where((task) => task.recurrenceId.isIn(ruleIds) & task.occurrenceDate.isBiggerOrEqualValue(start.dateOnly) & task.occurrenceDate.isSmallerThanValue(end.nextDay))).get();
    return {for (final task in rows) (task.recurrenceId!, task.occurrenceDate!.dateOnly)};
  }

  /// Saves a rule. With [taskId], that task becomes the occurrence of the rule's start date.
  Future<int> createRecurrenceRule(RecurrenceRulesCompanion rule, {int? taskId}) {
    return transaction(() async {
      final id = await into(recurrenceRules).insert(rule);
      if (taskId != null) {
        await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(recurrenceId: Value(id), occurrenceDate: Value(rule.startDate.value.dateOnly)));
      }
      return id;
    });
  }

  /// Inserts occurrence [task] (with `recurrence_id` and `occurrence_date`) after the tasks of its day, with the
  /// sub-tasks [todoTitles], unless the rule already has one for that date. Returns whether it was inserted.
  Future<bool> insertOccurrence(TasksCompanion task, List<String> todoTitles) {
    return transaction(() async {
      final day = task.assignedDate.value.dateOnly;
      final last =
          await (select(tasks)
                ..where((t) => _isInDay(t, day))
                ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final row = task.copyWith(assignedDate: Value(day), sortOrder: Value(FractionalIndexer.between(last?.sortOrder, null)));
      // `INSERT OR IGNORE` on the unique (recurrence_id, occurrence_date) index: a second call adds nothing.
      await into(tasks).insert(row, mode: InsertMode.insertOrIgnore);
      final changes = await customSelect('SELECT changes() AS n, last_insert_rowid() AS id').getSingle();
      if (changes.read<int>('n') == 0) return false;
      final id = changes.read<int>('id');
      for (final (index, title) in todoTitles.indexed) {
        await into(taskTodos).insert(TaskTodosCompanion.insert(taskId: id, title: title, sortOrder: index.toString().padLeft(5, '0')));
      }
      return true;
    });
  }

  /// "This and future" (#24): rule [ruleId] ends the day before [from] (or is deleted if it starts on or after it) and
  /// [next] (if given) is saved from [from]. Task [taskId] moves to the new rule, becomes a one-off task, or is deleted
  /// with [deleteTask]. Later occurrences that are open, untracked and not running are removed; the others move to the
  /// new rule (or become one-off tasks). Returns the id of the new rule.
  Future<int?> splitRecurrenceRule({required int ruleId, required DateTime from, required int taskId, RecurrenceRulesCompanion? next, bool deleteTask = false}) {
    final day = from.dateOnly;
    return transaction(() async {
      final rule = await getRecurrenceRule(ruleId);
      if (rule == null) return null;
      final nextId = next == null ? null : await into(recurrenceRules).insert(next.copyWith(startDate: Value(day)));
      final later = await (select(tasks)..where((task) => task.recurrenceId.equals(ruleId) & task.occurrenceDate.isBiggerOrEqualValue(day) & task.id.equals(taskId).not())).get();
      for (final task in later) {
        final untouched = !task.isCompleted && task.timeSpent == 0 && await _openSessionOf(task.id) == null;
        if (untouched) {
          await (delete(tasks)..where((t) => t.id.equals(task.id))).go();
        } else {
          await (update(tasks)..where((t) => t.id.equals(task.id))).write(_linkTo(nextId));
        }
      }
      if (deleteTask) {
        await (delete(tasks)..where((t) => t.id.equals(taskId))).go();
      } else {
        await (update(tasks)..where((t) => t.id.equals(taskId))).write(_linkTo(nextId));
      }
      if (!rule.startDate.isBefore(day)) {
        await (delete(recurrenceRules)..where((r) => r.id.equals(ruleId))).go();
      } else {
        await (update(recurrenceRules)..where((r) => r.id.equals(ruleId))).write(RecurrenceRulesCompanion(endDate: Value(day.addDays(-1))));
        await (delete(recurrenceExceptions)..where((e) => e.ruleId.equals(ruleId) & e.date.isBiggerOrEqualValue(day))).go();
      }
      return nextId;
    });
  }

  /// Moves a task to rule [ruleId] (keeping its occurrence date); without one, it becomes a one-off task.
  static TasksCompanion _linkTo(int? ruleId) {
    return ruleId == null ? const TasksCompanion(recurrenceId: Value(null), occurrenceDate: Value(null)) : TasksCompanion(recurrenceId: Value(ruleId));
  }

  // --- Categories -----------------------------------------------------------------------------------------------

  /// All categories (also archived ones) in their order.
  Stream<List<CategoryRow>> watchCategories() {
    return (select(categories)..orderBy([(category) => OrderingTerm.asc(category.sortOrder), (category) => OrderingTerm.asc(category.id)])).watch();
  }

  Future<List<CategoryRow>> getCategories() {
    return (select(categories)..orderBy([(category) => OrderingTerm.asc(category.sortOrder), (category) => OrderingTerm.asc(category.id)])).get();
  }

  Future<int> createCategory(CategoriesCompanion companion) => into(categories).insert(companion);

  Future<void> updateCategory(int id, CategoriesCompanion companion) async {
    await (update(categories)..where((category) => category.id.equals(id))).write(companion);
  }

  /// Deletes the category; its tasks stay and become uncategorised (`ON DELETE SET NULL`).
  Future<void> deleteCategory(int id) async {
    await (delete(categories)..where((category) => category.id.equals(id))).go();
  }

  /// Deletes the task. An occurrence of a recurring task (#24) leaves an exception, so it isn't created again.
  Future<int> deleteTask(int taskId) {
    return transaction(() async {
      final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task != null) await _rememberDeletedOccurrence(task);
      return (delete(tasks)..where((t) => t.id.equals(taskId))).go();
    });
  }

  Future<void> _rememberDeletedOccurrence(Task task) async {
    final ruleId = task.recurrenceId;
    final date = task.occurrenceDate;
    if (ruleId == null || date == null) return;
    await into(recurrenceExceptions).insert(
      RecurrenceExceptionsCompanion.insert(ruleId: ruleId, date: date.dateOnly),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Completed tasks before [cutoffDay] without an open session (an unfinished session must stay recoverable).
  Expression<bool> _isCleanupCandidate(Tasks task, DateTime cutoffDay) {
    final openSession = select(focusSessions)..where((session) => session.taskId.equalsExp(task.id) & session.endedAt.isNull());
    return task.isCompleted.equals(true) & task.assignedDate.isSmallerThanValue(cutoffDay.dateOnly) & notExistsQuery(openSession);
  }

  /// Deletes old completed tasks; deleted occurrences of recurring tasks are remembered (see [deleteTask]).
  Future<int> deleteCompletedTasksBefore(DateTime cutoffDay) {
    return transaction(() async {
      final recurring = await (select(tasks)..where((task) => _isCleanupCandidate(task, cutoffDay) & task.recurrenceId.isNotNull())).get();
      for (final task in recurring) {
        await _rememberDeletedOccurrence(task);
      }
      return (delete(tasks)..where((task) => _isCleanupCandidate(task, cutoffDay))).go();
    });
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
