import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:focused_task/core/database/tables/tasks_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  DateTime _startOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  DateTime _endOfDay(DateTime day) {
    return _startOfDay(day).add(const Duration(days: 1));
  }

  Stream<List<Task>> watchTasksForDay(DateTime day) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);

    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(start))
      ..where((task) => task.assignedDate.isSmallerThanValue(end))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)]);

    return query.watch();
  }

  Future<List<Task>> getTasksForDay(DateTime day) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);

    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(start))
      ..where((task) => task.assignedDate.isSmallerThanValue(end))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)]);

    return query.get();
  }

  Future<Task?> getTaskById(int taskId) {
    final query = select(tasks)..where((task) => task.id.equals(taskId));
    return query.getSingleOrNull();
  }

  Future<Task?> getNextIncompleteTaskForDay(DateTime day) {
    final start = _startOfDay(day);
    final end = _endOfDay(day);

    final query = select(tasks)
      ..where((task) => task.assignedDate.isBiggerOrEqualValue(start))
      ..where((task) => task.assignedDate.isSmallerThanValue(end))
      ..where((task) => task.isCompleted.equals(false))
      ..orderBy([(task) => OrderingTerm.asc(task.sortOrder)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<void> createTask(TasksCompanion companion) async {
    await into(tasks).insert(companion);
  }

  Future<void> updateTaskOrder({
    required int taskId,
    required String sortOrder,
  }) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(
      TasksCompanion(sortOrder: Value(sortOrder)),
    );
  }

  Future<void> startTaskSession({
    required int taskId,
    required DateTime startedAt,
  }) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(
      TasksCompanion(latestStart: Value(startedAt)),
    );
  }

  Future<void> pauseTaskSession({
    required int taskId,
    required DateTime pausedAt,
  }) async {
    final task = await getTaskById(taskId);
    if (task == null || task.latestStart == null) {
      return;
    }

    final elapsed = pausedAt.difference(task.latestStart!).inMilliseconds;
    final clampedElapsed = elapsed < 0 ? 0 : elapsed;

    await (update(tasks)..where((row) => row.id.equals(taskId))).write(
      TasksCompanion(
        timeSpent: Value(task.timeSpent + clampedElapsed),
        latestStart: const Value(null),
      ),
    );
  }

  Future<void> completeTask({
    required int taskId,
    required DateTime completedAt,
  }) async {
    await pauseTaskSession(taskId: taskId, pausedAt: completedAt);

    await (update(tasks)..where((task) => task.id.equals(taskId))).write(
      const TasksCompanion(isCompleted: Value(true)),
    );
  }

  Future<void> discardUnfinishedSession(int taskId) async {
    await (update(tasks)..where((task) => task.id.equals(taskId))).write(
      const TasksCompanion(latestStart: Value(null)),
    );
  }

  Future<List<Task>> getRecoverableSessions() {
    final query = select(tasks)
      ..where((task) => task.latestStart.isNotNull())
      ..where((task) => task.isCompleted.equals(false));
    return query.get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'focused_task.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
