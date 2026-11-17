import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import 'helpers/task_builders.dart';

void main() {
  group('TaskStats', () {
    test('computes completion from the planned tasks and focus metrics from the tracked time', () {
      final tasks = [buildTask(id: 1, isCompleted: true), buildTask(id: 2, priority: TaskPriority.medium), buildTask(id: 3, isCompleted: true, priority: TaskPriority.high)];
      const minute = Duration(minutes: 1);

      final stats = TaskStats.from(tasks: tasks, focusByTask: {1: minute * 45, 2: minute * 15, 3: minute * 30}, daysInRange: 2);

      expect(stats.totalTasks, 3);
      expect(stats.completedTasks, 2);
      expect(stats.completionScore, 66.7);
      expect(stats.totalFocusMinutes, 90);
      expect(stats.averageTaskDurationMinutes, 30);
      expect(stats.focusMinutesPerDay, 45);
    });

    test('counts focus time of tasks planned elsewhere or deleted', () {
      final stats = TaskStats.from(tasks: const [], focusByTask: {7: const Duration(minutes: 30), null: const Duration(minutes: 10)}, daysInRange: 1);

      expect(stats.totalTasks, 0);
      expect(stats.totalFocusMinutes, 40);
      expect(stats.averageTaskDurationMinutes, 20);
    });

    test('returns zeros for an empty range', () {
      final stats = TaskStats.from(tasks: const [], focusByTask: const {}, daysInRange: 7);

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
