import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import '../../../helpers/fake_target_alarm.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/task_builders.dart';

/// Runs [body] in fake time; the clock starts at a fixed date so tests are deterministic.
void _runFocus(List<TaskEntity> tasks, void Function(FakeAsync async, FocusModeNotifier notifier, FakeTaskRepository repository, FakeTargetAlarm alarm) body) {
  fakeAsync((async) {
    final repository = FakeTaskRepository(tasks: tasks);
    final alarm = FakeTargetAlarm();
    final notifier = FocusModeNotifier(repository, alarm);
    body(async, notifier, repository, alarm);
    notifier.dispose();
  }, initialTime: DateTime(2026, 11, 17, 9));
}

final _today = DateTime(2026, 11, 17);

void main() {
  group('FocusModeNotifier target alarm', () {
    test('schedules the alarm for the remaining target time when focus starts', () {
      _runFocus([buildTask(assignedDate: _today, targetDurationMinutes: 30, timeSpent: const Duration(minutes: 10).inMilliseconds)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        expect(notifier.state.currentTask?.id, 1);
        expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 20)));
      });
    });

    test('pause cancels the alarm and resume reschedules it with the remaining time', () {
      _runFocus([buildTask(assignedDate: _today, targetDurationMinutes: 30)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 10));
        notifier.pauseSession();
        async.flushMicrotasks();
        expect(alarm.scheduledAt, isNull);
        expect(repository.task(1).timeSpent, const Duration(minutes: 10).inMilliseconds);

        async.elapse(const Duration(minutes: 5)); // paused time must not count
        notifier.resumeSession();
        async.flushMicrotasks();
        expect(alarm.scheduledAt, clock.now().add(const Duration(minutes: 20)));
      });
    });

    test('exiting focus cancels the pending alarm', () {
      _runFocus([buildTask(assignedDate: _today, targetDurationMinutes: 30)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        notifier.exitFocus();
        async.flushMicrotasks();

        expect(alarm.scheduledAt, isNull);
        expect(notifier.state.currentTask, isNull);
        expect(repository.task(1).isRunning, isFalse);
      });
    });

    test('completing the task cancels its alarm and starts the next task', () {
      _runFocus([buildTask(id: 1, assignedDate: _today, sortOrder: 'a0', targetDurationMinutes: 30), buildTask(id: 2, assignedDate: _today, sortOrder: 'a1')], (
        async,
        notifier,
        repository,
        alarm,
      ) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        notifier.completeCurrentTask();
        async.flushMicrotasks();

        expect(repository.task(1).isCompleted, isTrue);
        expect(notifier.state.currentTask?.id, 2);
        expect(alarm.scheduledAt, isNull, reason: 'task 2 has no target');
      });
    });

    test('a task already over its target does not ring again when focus is re-entered', () {
      _runFocus([buildTask(assignedDate: _today, targetDurationMinutes: 30, timeSpent: const Duration(minutes: 45).inMilliseconds)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(alarm.scheduleCount, 0);
        expect(notifier.state.shouldShowAlarm, isFalse);
      });
    });

    test('shows the in-app alarm exactly once when the target is reached', () {
      _runFocus([buildTask(assignedDate: _today, targetDurationMinutes: 1)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 59));
        expect(notifier.state.shouldShowAlarm, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(notifier.state.shouldShowAlarm, isTrue);

        notifier.dismissAlarm();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));
        expect(notifier.state.shouldShowAlarm, isFalse);
      });
    });
  });

  group('FocusModeNotifier session flow', () {
    test('signals finished-for-today when no open task is left', () {
      _runFocus([buildTask(assignedDate: _today, isCompleted: true)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        expect(notifier.state.shouldShowFinishedForToday, isTrue);
        expect(notifier.state.currentTask, isNull);
      });
    });

    test('session time excludes paused time', () {
      _runFocus([buildTask(assignedDate: _today)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 10));
        notifier.pauseSession();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 30));
        notifier.resumeSession();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));

        expect(notifier.state.totalSessionDuration, const Duration(minutes: 15));
        expect(notifier.state.currentTaskDuration, const Duration(minutes: 15));
      });
    });
  });
}
