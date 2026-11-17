import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';

void main() {
  group('AppDatabase day filtering', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('focus query only returns tasks for the selected day', () async {
      final today = DateTime(2026, 8, 8);
      final tomorrow = today.add(const Duration(days: 1));

      await database.createTask(TasksCompanion.insert(title: 'today task', assignedDate: today, sortOrder: 'a0'));

      await database.createTask(TasksCompanion.insert(title: 'tomorrow task', assignedDate: tomorrow, sortOrder: 'a1'));

      final next = await database.getNextIncompleteTaskForDay(today);

      expect(next, isNotNull);
      expect(next!.title, 'today task');
      expect(DateTime(next.assignedDate.year, next.assignedDate.month, next.assignedDate.day), today);
    });

    test('retention cleanup only deletes completed old tasks', () async {
      final now = DateTime.now();
      final fortyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 40));
      final tenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 10));

      await database.createTask(TasksCompanion.insert(title: 'old completed', assignedDate: fortyDaysAgo, sortOrder: 'a0', isCompleted: const drift.Value(true)));

      await database.createTask(TasksCompanion.insert(title: 'old incomplete', assignedDate: fortyDaysAgo, sortOrder: 'a1', isCompleted: const drift.Value(false)));

      await database.createTask(TasksCompanion.insert(title: 'recent completed', assignedDate: tenDaysAgo, sortOrder: 'a2', isCompleted: const drift.Value(true)));

      final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final deleted = await database.deleteCompletedTasksBefore(cutoff);

      expect(deleted, 1);

      final oldDayTasks = await database.getTasksForDay(fortyDaysAgo);
      expect(oldDayTasks.length, 1);
      expect(oldDayTasks.first.task.title, 'old incomplete');

      final recentDayTasks = await database.getTasksForDay(tenDaysAgo);
      expect(recentDayTasks.length, 1);
      expect(recentDayTasks.first.task.title, 'recent completed');
    });

    test('retention cleanup never deletes running or recoverable sessions', () async {
      final now = DateTime.now();
      final fortyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 40));

      await database.createTask(
        TasksCompanion.insert(
          title: 'old completed but running session',
          assignedDate: fortyDaysAgo,
          sortOrder: 'a0',
          isCompleted: const drift.Value(true),
          latestStart: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final deleted = await database.deleteCompletedTasksBefore(cutoff);
      expect(deleted, 0);

      final tasks = await database.getTasksForDay(fortyDaysAgo);
      expect(tasks.length, 1);
      expect(tasks.first.task.title, 'old completed but running session');
      expect(tasks.first.task.latestStart, isNotNull);
    });
  });
}
