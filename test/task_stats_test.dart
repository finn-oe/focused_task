import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import 'helpers/task_builders.dart';

void main() {
  group('TaskStats', () {
    test('computes completion, focus, and duration metrics from tasks', () {
      final tasks = [
        buildTask(id: 1, isCompleted: true, timeSpent: 45 * 60 * 1000),
        buildTask(id: 2, priority: TaskPriority.medium, timeSpent: 15 * 60 * 1000),
        buildTask(id: 3, isCompleted: true, priority: TaskPriority.high, timeSpent: 30 * 60 * 1000),
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
      final stats = TaskStats.fromTasks([buildTask(timeSpent: 45 * 60 * 1000)], daysInRange: 1);

      expect(stats.totalFocusMinutes, 45);
      expect(stats.averageTaskDurationMinutes, 45);
      expect(stats.focusMinutesPerDay, 45);
    });

    test('returns zeros for an empty range', () {
      final stats = TaskStats.fromTasks(const [], daysInRange: 7);

      expect(stats.totalTasks, 0);
      expect(stats.completionScore, 0);
      expect(stats.totalFocusMinutes, 0);
      expect(stats.averageTaskDurationMinutes, 0);
    });
  });

  group('FocusModeState', () {
    test('clears the current task when requested', () {
      final state = FocusModeState.initial().copyWith(currentTask: buildTask());

      final cleared = state.copyWith(clearCurrentTask: true);

      expect(cleared.currentTask, isNull);
    });
  });
}
