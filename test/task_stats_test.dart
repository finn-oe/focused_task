import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

void main() {
  group('TaskStats', () {
    test('computes completion, focus, and duration metrics from tasks', () {
      final tasks = [
        TaskEntity(
          id: 1,
          title: 'Plan sprint',
          description: null,
          assignedDate: DateTime(2024, 1, 1),
          sortOrder: 'a',
          isCompleted: true,
          priority: TaskPriority.low,
          timeSpent: 45 * 60 * 1000,
          latestStart: null,
        ),
        TaskEntity(
          id: 2,
          title: 'Write docs',
          description: null,
          assignedDate: DateTime(2024, 1, 1),
          sortOrder: 'b',
          isCompleted: false,
          priority: TaskPriority.medium,
          timeSpent: 15 * 60 * 1000,
          latestStart: null,
        ),
        TaskEntity(
          id: 3,
          title: 'Review PR',
          description: null,
          assignedDate: DateTime(2024, 1, 2),
          sortOrder: 'c',
          isCompleted: true,
          priority: TaskPriority.high,
          timeSpent: 30 * 60 * 1000,
          latestStart: null,
        ),
      ];

      final stats = TaskStats.fromTasks(tasks, daysInRange: 2);

      expect(stats.totalTasks, 3);
      expect(stats.completedTasks, 2);
      expect(stats.completionScore, 66.7);
      expect(stats.totalFocusMinutes, 90);
      expect(stats.averageTaskDurationMinutes, 30);
      expect(stats.focusMinutesPerDay, 45);
    });

    test('includes in-progress task time in focus metrics', () {
      final tasks = [
        TaskEntity(
          id: 1,
          title: 'Plan sprint',
          description: null,
          assignedDate: DateTime(2024, 1, 1),
          sortOrder: 'a',
          isCompleted: false,
          priority: TaskPriority.low,
          timeSpent: 45 * 60 * 1000,
          latestStart: null,
        ),
      ];

      final stats = TaskStats.fromTasks(tasks, daysInRange: 1);

      expect(stats.totalFocusMinutes, 45);
      expect(stats.averageTaskDurationMinutes, 45);
      expect(stats.focusMinutesPerDay, 45);
    });
  });

  group('FocusModeState', () {
    test('clears the current task when requested', () {
      final state = FocusModeState.initial().copyWith(
        currentTask: TaskEntity(
          id: 1,
          title: 'Plan sprint',
          description: null,
          assignedDate: DateTime(2024, 1, 1),
          sortOrder: 'a',
          isCompleted: false,
          priority: TaskPriority.low,
          timeSpent: 0,
          latestStart: null,
        ),
      );

      final cleared = state.copyWith(currentTask: null, clearCurrentTask: true);

      expect(cleared.currentTask, isNull);
    });
  });
}
