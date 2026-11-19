import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import '../../../helpers/fake_notification_service.dart';
import '../../../helpers/fake_target_alarm.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/task_builders.dart';

/// Runs [body] in fake time; the clock starts at a fixed date so tests are deterministic.
void _runFocus(
  List<TaskEntity> tasks,
  void Function(FakeAsync async, FocusModeNotifier notifier, FakeTaskRepository repository, FakeTargetAlarm alarm) body, {
  FocusGoal goal = FocusGoal.off,
  FakeNotificationService? notifications,
  DateTime? initialTime,
}) {
  fakeAsync((async) {
    final repository = FakeTaskRepository(tasks: tasks);
    final alarm = FakeTargetAlarm();
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        targetAlarmProvider.overrideWithValue(alarm),
        notificationServiceProvider.overrideWithValue(notifications ?? FakeNotificationService()),
        focusGoalProvider.overrideWithValue(goal),
        _english,
      ],
    );
    final notifier = container.read(focusModeNotifierProvider.notifier);
    body(async, notifier, repository, alarm);
    container.dispose();
  }, initialTime: initialTime ?? DateTime(2026, 11, 17, 9));
}

final _today = DateTime(2026, 11, 17);

final _english = appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en')));

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

  group('FocusModeNotifier queue', () {
    List<TaskEntity> threeTasks() => [
      buildTask(id: 1, title: 'First', assignedDate: _today, sortOrder: 'a0'),
      buildTask(id: 2, title: 'Second', assignedDate: _today, sortOrder: 'a1'),
      buildTask(id: 3, title: 'Third', assignedDate: _today, sortOrder: 'a2'),
    ];
    List<int> queueIds(FocusModeNotifier notifier) => notifier.state.queue.map((task) => task.id).toList();

    test('starts with the requested task and keeps the plan order after it', () {
      _runFocus(threeTasks(), (async, notifier, repository, alarm) {
        notifier.start(FocusRequest(_today, startTaskId: 2));
        async.flushMicrotasks();

        expect(notifier.state.currentTask?.title, 'Second');
        expect(queueIds(notifier), [2, 3, 1]);
        expect(notifier.state.upNext?.title, 'Third');
        expect(repository.task(2).isRunning, isTrue);
      });
    });

    test('skip moves the task to the end and keeps its time', () {
      _runFocus(threeTasks(), (async, notifier, repository, alarm) {
        notifier.start(FocusRequest(_today));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 10));

        notifier.skipCurrentTask();
        async.flushMicrotasks();

        expect(notifier.state.currentTask?.title, 'Second');
        expect(queueIds(notifier), [2, 3, 1]);
        expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(minutes: 10));
        expect(repository.sessions.first.endReason, EndReason.skipped);
        expect(repository.task(1).isCompleted, isFalse);
      });
    });

    test('completing the last task of the queue finishes for today', () {
      _runFocus(threeTasks(), (async, notifier, repository, alarm) {
        notifier.start(FocusRequest(_today, startTaskId: 3));
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          notifier.completeCurrentTask();
          async.flushMicrotasks();
        }

        expect(notifier.state.shouldShowFinishedForToday, isTrue);
        expect(repository.tasks.every((task) => task.isCompleted), isTrue);
      });
    });

    test('re-entering with the same request (after a pause) keeps the queue', () {
      _runFocus(threeTasks(), (async, notifier, repository, alarm) {
        final request = FocusRequest(_today);
        notifier.start(request);
        async.flushMicrotasks();
        notifier.skipCurrentTask();
        async.flushMicrotasks();

        notifier.start(request);
        async.flushMicrotasks();

        expect(queueIds(notifier), [2, 3, 1]);
      });
    });

    test('focuses on another day when asked to', () {
      final tomorrow = _today.addDays(1);
      _runFocus([buildTask(id: 1, title: 'Today', assignedDate: _today), buildTask(id: 2, title: 'Tomorrow', assignedDate: tomorrow)], (async, notifier, repository, alarm) {
        notifier.start(FocusRequest(tomorrow));
        async.flushMicrotasks();

        expect(notifier.state.currentTask?.title, 'Tomorrow');
        expect(notifier.state.upNext, isNull);
      });
    });

    test('a quick sub-task is added to the current task', () {
      _runFocus([buildTask(assignedDate: _today)], (async, notifier, repository, alarm) {
        notifier.start(FocusRequest(_today));
        async.flushMicrotasks();

        notifier.addSubTask('  Check numbers ');
        async.flushMicrotasks();

        expect(notifier.state.currentTask?.todos.map((todo) => todo.title), ['Check numbers']);
        expect(repository.task(1).todos, hasLength(1));
      });
    });
  });

  group('FocusModeNotifier crash recovery', () {
    test('loads the sessions that were left running', () {
      final running = buildTask(id: 1, assignedDate: _today, latestStart: DateTime(2026, 11, 17, 8));
      final idle = buildTask(id: 2, assignedDate: _today, sortOrder: 'a1');
      _runFocus([running, idle], (async, notifier, repository, alarm) {
        List<FocusSession>? sessions;
        notifier.loadRecoverableSessions().then((value) => sessions = value);
        async.flushMicrotasks();

        expect(sessions?.map((session) => session.taskId), [1]);
        expect(sessions?.single.taskTitle, 'Task');
      });
    });

    test('stops its ticker when the provider is disposed', () {
      fakeAsync((async) {
        final repository = FakeTaskRepository(tasks: [buildTask(assignedDate: _today)]);
        final container = ProviderContainer(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repository),
            focusSessionRepositoryProvider.overrideWithValue(repository),
            targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
            focusGoalProvider.overrideWithValue(FocusGoal.off),
            _english,
          ],
        );
        container.read(focusModeNotifierProvider.notifier).initializeForDay(_today);
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 1);

        container.dispose();

        expect(async.periodicTimerCount, 0);
      }, initialTime: DateTime(2026, 11, 17, 9));
    });

    test('records a heartbeat while a session runs', () {
      _runFocus([buildTask(assignedDate: _today)], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2, seconds: 5));

        final lastSeen = repository.task(1).lastSeenAt!;
        expect(clock.now().difference(lastSeen), lessThanOrEqualTo(FocusModeNotifier.heartbeatInterval));
      });
    });

    test('recovering until last activity ignores the time the app was closed', () {
      final start = DateTime(2026, 11, 16, 20);
      final session = buildTask(assignedDate: _today, latestStart: start).copyWith(lastSeenAt: start.add(const Duration(minutes: 40)));
      _runFocus([session], (async, notifier, repository, alarm) {
        notifier.recoverSessions(recovery: SessionRecovery.untilLastActivity, sessions: repository.sessions);
        async.flushMicrotasks();

        expect(repository.task(1).isRunning, isFalse);
        expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(minutes: 40));
      });
    });

    test('recovering until now and discarding', () {
      final start = DateTime(2026, 11, 17, 8);
      final first = buildTask(id: 1, assignedDate: _today, latestStart: start);
      final second = buildTask(id: 2, assignedDate: _today, sortOrder: 'a1', latestStart: start);
      _runFocus([first, second], (async, notifier, repository, alarm) {
        final [firstSession, secondSession] = repository.sessions;
        notifier.recoverSessions(recovery: SessionRecovery.untilNow, sessions: [firstSession]);
        notifier.recoverSessions(recovery: SessionRecovery.discard, sessions: [secondSession]);
        async.flushMicrotasks();

        expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(hours: 1));
        expect(repository.task(2).timeSpent, 0);
        expect(repository.task(2).isRunning, isFalse);
        expect(repository.sessions.map((session) => session.endReason), [EndReason.recovered, EndReason.discarded]);
      });
    });

    test('pausing, exiting and completing end sessions with their reason', () {
      _runFocus([buildTask(id: 1, assignedDate: _today), buildTask(id: 2, assignedDate: _today, sortOrder: 'a1')], (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 10));
        notifier.pauseSession();
        async.flushMicrotasks();
        notifier.resumeSession();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));
        notifier.completeCurrentTask();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));
        notifier.exitFocus();
        async.flushMicrotasks();

        expect(repository.sessions.map((session) => (session.taskId, session.endReason, session.duration)), [
          (1, EndReason.paused, const Duration(minutes: 10)),
          (1, EndReason.completed, const Duration(minutes: 5)),
          (2, EndReason.exited, const Duration(minutes: 1)),
        ]);
        expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(minutes: 15));
      });
    });
  });

  group('FocusModeNotifier goal notification', () {
    const goal = FocusGoal(daily: Duration(hours: 1));

    test('is scheduled for the moment the focus time of today reaches the goal', () {
      final notifications = FakeNotificationService();
      _runFocus([buildTask(assignedDate: _today)], goal: goal, notifications: notifications, (async, notifier, repository, alarm) {
        repository.addManualTime(taskId: 1, day: _today, duration: const Duration(minutes: 20));
        async.flushMicrotasks();
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        final (notification, at) = notifications.scheduled[NotificationIds.goalReached]!;
        expect(at, clock.now().add(const Duration(minutes: 40)));
        expect(notification.title, 'Daily goal reached');
        expect(notification.body, 'You focused for 1 h today.');
      });
    });

    test('pause cancels it and resume schedules it again for the remaining time', () {
      final notifications = FakeNotificationService();
      _runFocus([buildTask(assignedDate: _today)], goal: goal, notifications: notifications, (async, notifier, repository, alarm) {
        notifier.initializeForDay(_today);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 10));

        notifier.pauseSession();
        async.flushMicrotasks();
        expect(notifications.scheduled, isNot(contains(NotificationIds.goalReached)));

        async.elapse(const Duration(minutes: 5));
        notifier.resumeSession();
        async.flushMicrotasks();
        expect(notifications.scheduled[NotificationIds.goalReached]!.$2, clock.now().add(const Duration(minutes: 50)));
      });
    });

    test('comes at most once a day: nothing is scheduled once the goal is reached', () {
      final notifications = FakeNotificationService();
      _runFocus([buildTask(assignedDate: _today)], goal: goal, notifications: notifications, (async, notifier, repository, alarm) {
        repository.addManualTime(taskId: 1, day: _today, duration: const Duration(hours: 1));
        async.flushMicrotasks();
        notifier.initializeForDay(_today);
        async.flushMicrotasks();

        expect(notifications.scheduled, isEmpty);
      });
    });

    test('nothing without a goal, on days off, or when the goal would only be reached tomorrow', () {
      void expectNothing({required FocusGoal goal, required DateTime start}) {
        final notifications = FakeNotificationService();
        _runFocus([buildTask(assignedDate: start.dateOnly)], goal: goal, notifications: notifications, initialTime: start, (async, notifier, repository, alarm) {
          notifier.initializeForDay(start.dateOnly);
          async.flushMicrotasks();
          expect(notifications.scheduled, isEmpty, reason: '$goal at $start');
        });
      }

      expectNothing(goal: FocusGoal.off, start: DateTime(2026, 11, 17, 9));
      expectNothing(goal: goal, start: DateTime(2026, 11, 21, 9)); // Saturday
      expectNothing(goal: goal, start: DateTime(2026, 11, 17, 23, 30));
    });
  });
}
