import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';
import 'package:focused_task/main.dart';

void main() {
  testWidgets('App boots into plan mode shell', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [taskRepositoryProvider.overrideWithValue(_FakeTaskRepository())], child: const MaterialApp(home: PlanScreen())));
    await tester.pump();

    expect(find.text('Plan Mode'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
  });

  testWidgets('Tapping the completion flag toggles a task to completed', (WidgetTester tester) async {
    final repository = _FakeTaskRepository(
      tasks: [
        TaskEntity(
          id: 1,
          title: 'Write tests',
          description: 'Add coverage',
          assignedDate: DateTime(2024, 1, 1),
          sortOrder: 'a',
          isCompleted: false,
          priority: TaskPriority.low,
          timeSpent: 0,
          latestStart: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Write tests'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pump();

    expect(repository.lastCompletedTaskId, 1);
    expect(repository.lastCompletedValue, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository({List<TaskEntity>? tasks}) : _tasks = tasks ?? const [] {
    _controller.add(_tasks);
  }

  final List<TaskEntity> _tasks;
  final StreamController<List<TaskEntity>> _controller = StreamController<List<TaskEntity>>.broadcast();
  int? lastCompletedTaskId;
  bool? lastCompletedValue;
  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) async => 0;

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) async {}

  @override
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted}) async {
    lastCompletedTaskId = taskId;
    lastCompletedValue = isCompleted;
    final updatedTasks = _tasks.map((task) => task.id == taskId ? task.copyWith(isCompleted: isCompleted) : task).toList(growable: false);
    _controller.add(updatedTasks);
  }

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
  Future<List<TaskEntity>> getTasksForDay(DateTime day) async => _tasks;

  @override
  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt}) async {}

  @override
  Future<void> startTaskSession({required int taskId, required DateTime startedAt}) async {}

  @override
  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {}

  @override
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day) {
    return Stream.value(_tasks);
  }
}
