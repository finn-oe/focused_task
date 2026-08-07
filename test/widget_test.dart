import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/main.dart';

void main() {
  testWidgets('App boots into plan mode shell', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [taskRepositoryProvider.overrideWithValue(_FakeTaskRepository())], child: const FocusedTaskApp()));
    await tester.pumpAndSettle();

    expect(find.text('Plan Mode'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
  });
}

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) async => 0;

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) async {}

  @override
  Future<void> createTask({
    required String title,
    String? description,
    required DateTime assignedDate,
    required String sortOrder,
    TaskPriority priority = TaskPriority.low,
  }) async {}

  @override
  Future<void> discardUnfinishedSession({required int taskId}) async {}

  @override
  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day) async => null;

  @override
  Future<List<TaskEntity>> getRecoverableSessions() async => const [];

  @override
  Future<TaskEntity?> getTaskById(int id) async => null;

  @override
  Future<List<TaskEntity>> getTasksForDay(DateTime day) async => const [];

  @override
  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt}) async {}

  @override
  Future<void> startTaskSession({required int taskId, required DateTime startedAt}) async {}

  @override
  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {}

  @override
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day) {
    return Stream.value(const <TaskEntity>[]);
  }
}
