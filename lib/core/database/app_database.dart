import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:focused_task/core/database/tables/tasks_table.dart';
import 'package:focused_task/core/database/tables/task_todos_table.dart';

part 'app_database.g.dart';

class TaskWithTodos {
  TaskWithTodos(this.task, this.todos);
  final Task task;
  final List<TaskTodo> todos;
}

@DriftDatabase(tables: [Tasks, TaskTodos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
      },
      beforeOpen: (details) async {
        // Essential for SQLite to respect onDelete: KeyAction.cascade
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  DateTime _startOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  DateTime _endOfDay(DateTime day) {
    return _startOfDay(day).add(const Duration(days: 1));
  }

  Expression<bool> _isInDay(Tasks table, DateTime day) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);
    return table.assignedDate.isBiggerOrEqualValue(start) & table.assignedDate.isSmallerThanValue(end);
  }

  Stream<List<TaskWithTodos>> watchTasksForDay(DateTime day) {
    final query = select(tasks).join([leftOuterJoin(taskTodos, taskTodos.taskId.equalsExp(tasks.id))])
      ..where(_isInDay(tasks, day))
      ..orderBy([OrderingTerm.asc(tasks.sortOrder), OrderingTerm.asc(taskTodos.sortOrder)]);

    return query.watch().map((rows) {
      final groupedTasks = <Task, List<TaskTodo>>{};
      for (final row in rows) {
        final task = row.readTable(tasks);
        final todo = row.readTableOrNull(taskTodos);
        groupedTasks.putIfAbsent(task, () => []);
        if (todo != null) {
          groupedTasks[task]!.add(todo);
        }
      }

      return groupedTasks.entries.map((entry) => TaskWithTodos(entry.key, entry.value)).toList();
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
      result.add(TaskWithTodos(task, todos));
    }
    return result;
  }

  Future<List<Task>> getTasksInRange({required DateTime start, required DateTime end}) {
    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(_startOfDay(start)) & task.assignedDate.isSmallerThanValue(_endOfDay(end)))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)]);

    return query.get();
  }

  Future<TaskWithTodos?> getTaskById(int taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return null;

    final todos = await (select(taskTodos)..where((t) => t.taskId.equals(taskId))).get();
    return TaskWithTodos(task, todos);
  }

  Future<Task?> getNextIncompleteTaskForDay(DateTime day) {
    final query = select(tasks)
      ..where((task) => _isInDay(task, day) & task.isCompleted.equals(false))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<int> createTask(TasksCompanion companion) async {
    final normalizedAssignedDate = _startOfDay(companion.assignedDate.value);
    return into(tasks).insert(companion.copyWith(assignedDate: Value(normalizedAssignedDate)));
  }

  Future<int> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes}) {
    return (update(
      tasks,
    )..where((t) => t.id.equals(taskId))).write(TasksCompanion(title: Value(title), description: Value(description), targetDurationMinutes: Value(targetDurationMinutes)));
  }

  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(sortOrder: Value(sortOrder)));
  }

  Future<void> setTaskCompletion({required int taskId, required bool isCompleted}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(isCompleted: Value(isCompleted)));
  }

  Future<void> startTaskSession({required int taskId, required DateTime startedAt}) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(TasksCompanion(latestStart: Value(startedAt)));
  }

  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt}) async {
    final taskData = await getTaskById(taskId);
    if (taskData == null || taskData.task.latestStart == null) {
      return;
    }

    final task = taskData.task;
    final elapsed = pausedAt.difference(task.latestStart!).inMilliseconds;
    final clampedElapsed = elapsed < 0 ? 0 : elapsed;

    await (update(tasks)..where((row) => row.id.equals(taskId))).write(TasksCompanion(timeSpent: Value(task.timeSpent + clampedElapsed), latestStart: const Value(null)));
  }

  Future<void> completeTask({required int taskId, required DateTime completedAt}) async {
    await pauseTaskSession(taskId: taskId, pausedAt: completedAt);
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(const TasksCompanion(isCompleted: Value(true)));
  }

  Future<void> discardUnfinishedSession(int taskId) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(const TasksCompanion(latestStart: Value(null)));
  }

  Future<List<Task>> getRecoverableSessions() {
    final query = select(tasks)
      ..where((task) => task.latestStart.isNotNull())
      ..where((task) => task.isCompleted.equals(false));
    return query.get();
  }

  Future<int> deleteTask(int taskId) {
    return (delete(tasks)..where((t) => t.id.equals(taskId))).go();
  }

  Future<int> deleteCompletedTasksBefore(DateTime cutoffDay) {
    final cutoff = _startOfDay(cutoffDay);
    final query = delete(tasks)..where((task) => task.isCompleted.equals(true) & task.latestStart.isNull() & task.assignedDate.isSmallerThanValue(cutoff));
    return query.go();
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'focused_task.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
