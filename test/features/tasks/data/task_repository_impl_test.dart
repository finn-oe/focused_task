import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';

void main() {
  late AppDatabase database;
  late TaskRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TaskRepositoryImpl(database);
  });

  tearDown(() => database.close());

  Future<int> createTask({DateTime? day}) => repository.createTask(title: 'Task', assignedDate: day ?? DateTime.now(), sortOrder: 'a0');

  group('setTaskCompletion', () {
    test('closes a running session so the timer stops counting', () async {
      final id = await createTask();
      await repository.startTaskSession(taskId: id, startedAt: DateTime.now().subtract(const Duration(hours: 1)));

      await repository.setTaskCompletion(taskId: id, isCompleted: true);

      final task = (await repository.getTaskById(id))!;
      expect(task.isCompleted, isTrue);
      expect(task.latestStart, isNull);
      expect(Duration(milliseconds: task.timeSpent).inMinutes, 60);

      final later = task.elapsedAt(DateTime.now().add(const Duration(hours: 5)));
      expect(later.inMinutes, 60, reason: 'elapsed time must not grow after completion');
    });

    test('un-completing does not restart the timer', () async {
      final id = await createTask();
      await repository.setTaskCompletion(taskId: id, isCompleted: true);
      await repository.setTaskCompletion(taskId: id, isCompleted: false);

      final task = (await repository.getTaskById(id))!;
      expect(task.isCompleted, isFalse);
      expect(task.isRunning, isFalse);
    });
  });

  group('getRecoverableSessions', () {
    test('includes completed tasks whose session was never closed (legacy data)', () async {
      final id = await createTask();
      await database.startTaskSession(taskId: id, startedAt: DateTime.now());
      // Simulate a row written by an older version: completed, but session still open.
      await database.customStatement('UPDATE tasks SET is_completed = 1 WHERE id = $id');

      final sessions = await repository.getRecoverableSessions();
      expect(sessions.map((task) => task.id), [id]);
    });
  });

  test('countCompletedTasksOlderThanDays matches what cleanup deletes', () async {
    final old = DateTime.now().subtract(const Duration(days: 40));
    final done = await createTask(day: old);
    await repository.setTaskCompletion(taskId: done, isCompleted: true);
    await createTask(day: old); // not completed
    await repository.setTaskCompletion(taskId: await createTask(), isCompleted: true); // recent

    expect(await repository.countCompletedTasksOlderThanDays(30), 1);
    expect(await repository.deleteCompletedTasksOlderThanDays(30), 1);
    expect(await repository.countCompletedTasksOlderThanDays(30), 0);
  });
}
