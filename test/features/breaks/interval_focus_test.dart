import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/breaks/domain/interval_planner.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';

final _today = DateTime(2026, 11, 17);
final _start = DateTime(2026, 11, 17, 9);
DateTime _at(int minutes) => _start.add(Duration(minutes: minutes));

const _intervals = IntervalSettings(isEnabled: true);

class _Focus {
  _Focus(this.repository, {IntervalSettings intervals = _intervals}) {
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        targetAlarmProvider.overrideWithValue(alarm),
        notificationServiceProvider.overrideWithValue(notifications),
        focusGoalProvider.overrideWithValue(FocusGoal.off),
        intervalSettingsProvider.overrideWithValue(intervals),
        appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
      ],
    );
  }

  final FakeTaskRepository repository;
  final alarm = FakeTargetAlarm();
  final notifications = FakeNotificationService();
  late final ProviderContainer container;

  FocusModeNotifier get notifier => container.read(focusModeNotifierProvider.notifier);
  FocusModeState get state => container.read(focusModeNotifierProvider);

  List<FocusSession> sessionsOf(SessionKind kind) => repository.sessions.where((session) => session.kind == kind).toList();
}

/// Runs [body] in fake time starting at 09:00, with intervals on (25 / 5 / 15 min, long break every 4).
void _run(List<TaskEntity> tasks, void Function(FakeAsync async, _Focus focus) body, {IntervalSettings intervals = _intervals}) {
  fakeAsync((async) {
    final focus = _Focus(FakeTaskRepository(tasks: tasks), intervals: intervals);
    body(async, focus);
    focus.container.dispose();
  }, initialTime: _start);
}

void main() {
  test('without intervals focus runs on and no break notification is scheduled', () {
    _run([buildTask(assignedDate: _today)], intervals: IntervalSettings.off, (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 40));

      expect(focus.state.intervals, isNull);
      expect(focus.state.isPaused, isFalse);
      expect(focus.notifications.scheduled.containsKey(NotificationIds.breakStarts), isFalse);
    });
  });

  test('a work interval ends in a break: the focus session ends at the interval end and a break session starts', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      expect(focus.state.intervals?.endsAt, _at(25));
      expect(focus.notifications.scheduled[NotificationIds.breakStarts]?.$2, _at(25));
      expect(focus.notifications.scheduled[NotificationIds.breakStarts]?.$1.channel, NotificationChannel.breaks);

      async.elapse(const Duration(minutes: 25, seconds: 3));

      expect(focus.state.isOnBreak, isTrue);
      expect(focus.state.isPaused, isTrue);
      final work = focus.sessionsOf(SessionKind.focus).single;
      expect(work.endedAt, _at(25));
      expect(work.endReason, EndReason.interval);
      final breakSession = focus.sessionsOf(SessionKind.breakTime).single;
      expect(breakSession.startedAt, _at(25));
      expect(breakSession.isOpen, isTrue);
      expect(focus.repository.task(1).timeSpent, const Duration(minutes: 25).inMilliseconds);
      // The break notification is due now and must not be cancelled; the "break is over" one is scheduled.
      expect(focus.notifications.cancelled, isNot(contains(NotificationIds.breakStarts)));
      expect(focus.notifications.scheduled[NotificationIds.breakOver]?.$2, _at(30));
      expect(focus.notifications.scheduled[NotificationIds.breakOver]?.$1.body, contains('Task'));
    });
  });

  test('full cycle with auto-start: three short breaks, then a long break; break time is not focus time', () {
    _run([buildTask(assignedDate: _today)], intervals: _intervals.copyWith(autoStart: true), (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();

      // 4 × 25 min work + 3 × 5 min short breaks + 15 min long break = 130 min.
      async.elapse(const Duration(minutes: 115, seconds: 2));
      expect(focus.state.intervals?.phase, IntervalPhase.longBreak);
      expect(focus.state.intervals?.endsAt, _at(130));

      async.elapse(const Duration(minutes: 15));
      expect(focus.state.isOnBreak, isFalse);
      expect(focus.state.isPaused, isFalse);

      final work = focus.sessionsOf(SessionKind.focus);
      expect(work.where((session) => !session.isOpen).map((session) => session.duration), List.filled(4, const Duration(minutes: 25)));
      expect(work.last.isOpen, isTrue);
      expect(work.last.startedAt, _at(130));
      final breaks = focus.sessionsOf(SessionKind.breakTime);
      expect(breaks.map((session) => session.duration), [
        for (final minutes in [5, 5, 5, 15]) Duration(minutes: minutes),
      ]);
      expect(breaks.every((session) => session.endReason == EndReason.interval), isTrue);

      expect(focus.repository.task(1).timeSpent, const Duration(minutes: 100).inMilliseconds);
      Map<DateTime, Duration>? byDay;
      focus.repository.focusTimeByDay(DateRange(_today, _today)).then((value) => byDay = value);
      async.flushMicrotasks();
      // 100 min closed + the running work interval up to its last heartbeat (a second or two); no break time.
      expect(byDay![_today]! - const Duration(minutes: 100), predicate<Duration>((extra) => extra >= Duration.zero && extra <= const Duration(seconds: 5)));
    });
  });

  test('the notification before the long break announces the long break', () {
    _run([buildTask(assignedDate: _today)], intervals: _intervals.copyWith(autoStart: true, longBreakEvery: 2), (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      expect(focus.notifications.scheduled[NotificationIds.breakStarts]?.$1.body, contains('5 min'));

      async.elapse(const Duration(minutes: 30, seconds: 2));
      expect(focus.notifications.scheduled[NotificationIds.breakStarts]?.$1.body, contains('15 min'));
    });
  });

  test('without auto-start the next work interval waits until the user continues', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 30, seconds: 2));

      expect(focus.state.isOnBreak, isFalse);
      expect(focus.state.isBreakOver, isTrue);
      expect(focus.sessionsOf(SessionKind.breakTime).single.endedAt, _at(30));
      expect(focus.repository.sessions.where((session) => session.isOpen), isEmpty);

      // Waiting time counts as nothing.
      async.elapse(const Duration(minutes: 10));
      focus.notifier.continueAfterBreak();
      async.flushMicrotasks();

      expect(focus.state.isBreakOver, isFalse);
      expect(focus.state.isPaused, isFalse);
      final work = focus.sessionsOf(SessionKind.focus).last;
      expect(work.isOpen, isTrue);
      expect(work.startedAt.difference(_at(40)).inSeconds.abs(), lessThan(3));
      expect(focus.state.intervals?.phase, IntervalPhase.work);
      expect(focus.state.intervals?.endsAt, work.startedAt.add(const Duration(minutes: 25)));
    });
  });

  test('skipping a break closes the break session and starts work right away', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 25, seconds: 2));
      async.elapse(const Duration(minutes: 2));

      final skippedAt = clock.now();
      focus.notifier.skipBreak();
      async.flushMicrotasks();

      final breakSession = focus.sessionsOf(SessionKind.breakTime).single;
      expect(breakSession.endedAt, skippedAt);
      expect(breakSession.endReason, EndReason.skipped);
      expect(focus.notifications.cancelled, contains(NotificationIds.breakOver));
      expect(focus.state.isOnBreak, isFalse);
      expect(focus.state.isPaused, isFalse);
      expect(focus.sessionsOf(SessionKind.focus).last.startedAt, skippedAt);
      expect(focus.state.intervals?.endsAt, skippedAt.add(const Duration(minutes: 25)));
      expect(focus.state.intervals?.completedWork, 1);
    });
  });

  test('pausing during a break does nothing: the break runs on and no session starts', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 26));

      focus.notifier.pauseSession(reason: EndReason.background);
      focus.notifier.resumeSession();
      async.flushMicrotasks();

      expect(focus.state.isOnBreak, isTrue);
      expect(focus.repository.sessions.where((session) => session.isOpen).single.kind, SessionKind.breakTime);
      expect(focus.state.intervals?.endsAt, _at(30));
    });
  });

  test('pausing work freezes the interval; the break comes after the rest of it', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 10));

      focus.notifier.pauseSession(reason: EndReason.background);
      async.flushMicrotasks();
      expect(focus.notifications.cancelled, contains(NotificationIds.breakStarts));

      async.elapse(const Duration(minutes: 30));
      expect(focus.state.isOnBreak, isFalse);

      focus.notifier.resumeSession();
      async.flushMicrotasks();
      expect(focus.state.intervals?.endsAt, _at(55));
      expect(focus.notifications.scheduled[NotificationIds.breakStarts]?.$2, _at(55));

      async.elapse(const Duration(minutes: 15, seconds: 2));
      expect(focus.state.isOnBreak, isTrue);
      expect(focus.repository.task(1).timeSpent, const Duration(minutes: 25).inMilliseconds);
    });
  });

  test('the work interval runs across tasks', () {
    _run([buildTask(id: 1, assignedDate: _today), buildTask(id: 2, title: 'Second', assignedDate: _today, sortOrder: 'a1')], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 10));
      focus.notifier.completeCurrentTask();
      async.flushMicrotasks();
      expect(focus.state.currentTask?.id, 2);
      expect(focus.state.intervals?.endsAt, _at(25));

      async.elapse(const Duration(minutes: 15, seconds: 2));
      expect(focus.state.isOnBreak, isTrue);
      expect(focus.repository.task(2).timeSpent, const Duration(minutes: 15).inMilliseconds);
    });
  });

  test('ending focus during a break closes the break session and stops the cycle', () {
    _run([buildTask(assignedDate: _today)], (async, focus) {
      focus.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 27));

      focus.notifier.exitFocus();
      async.flushMicrotasks();

      final breakSession = focus.sessionsOf(SessionKind.breakTime).single;
      expect(breakSession.endReason, EndReason.exited);
      expect(breakSession.endedAt, clock.now());
      expect(focus.notifications.cancelled, contains(NotificationIds.breakOver));
      expect(focus.state.intervals, isNull);
      expect(focus.repository.sessions.where((session) => session.isOpen), isEmpty);
      expect(async.periodicTimerCount, 0);
    });
  });

  test('an app restart during a break: recovery closes the break session without asking', () {
    fakeAsync((async) {
      final repository = FakeTaskRepository(tasks: [buildTask(assignedDate: _today)]);
      final first = _Focus(repository);
      first.notifier.initializeForDay(_today);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 27));
      // The app is killed: nothing is closed.
      first.container.dispose();
      final lastSeen = repository.sessions.last.lastSeenAt;
      expect(lastSeen.isAfter(_at(25)), isTrue);

      async.elapse(const Duration(hours: 1));
      final second = _Focus(repository);
      List<FocusSession>? recoverable;
      second.notifier.loadRecoverableSessions().then((value) => recoverable = value);
      async.flushMicrotasks();

      expect(recoverable, isEmpty);
      final breakSession = repository.sessions.where((session) => session.kind == SessionKind.breakTime).single;
      expect(breakSession.endedAt, lastSeen);
      expect(breakSession.endReason, EndReason.recovered);
      expect(repository.task(1).timeSpent, const Duration(minutes: 25).inMilliseconds);
      second.container.dispose();
    }, initialTime: _start);
  });

  group('target alarm', () {
    test('a target before the interval end rings as usual', () {
      _run([buildTask(assignedDate: _today, targetDurationMinutes: 10)], (async, focus) {
        focus.notifier.initializeForDay(_today);
        async.flushMicrotasks();
        expect(focus.alarm.scheduledAt, _at(10));

        async.elapse(const Duration(minutes: 10, seconds: 2));
        expect(focus.state.shouldShowAlarm, isTrue);
      });
    });

    test('a target at the interval end waits for the break and rings once afterwards', () {
      _run([buildTask(assignedDate: _today, targetDurationMinutes: 25)], (async, focus) {
        focus.notifier.initializeForDay(_today);
        async.flushMicrotasks();
        // The interval has priority: no alarm at the same moment.
        expect(focus.alarm.scheduledAt, isNull);

        async.elapse(const Duration(minutes: 25, seconds: 2));
        expect(focus.state.isOnBreak, isTrue);
        expect(focus.state.shouldShowAlarm, isFalse);
        expect(focus.state.hasAlarmPlayedForCurrentTask, isFalse);

        async.elapse(const Duration(minutes: 5));
        focus.notifier.continueAfterBreak();
        async.flushMicrotasks();
        final continuedAt = clock.now();
        expect(focus.alarm.scheduledAt, continuedAt);

        async.elapse(const Duration(seconds: 2));
        expect(focus.state.shouldShowAlarm, isTrue);
        focus.notifier.dismissAlarm();
        async.flushMicrotasks();
        final scheduleCount = focus.alarm.scheduleCount;

        async.elapse(const Duration(minutes: 30));
        expect(focus.state.shouldShowAlarm, isFalse);
        expect(focus.alarm.scheduleCount, scheduleCount);
      });
    });

    test('a target just before the interval end also waits for the break', () {
      _run([buildTask(assignedDate: _today, targetDurationMinutes: 25, timeSpent: const Duration(seconds: 30).inMilliseconds)], (async, focus) {
        focus.notifier.initializeForDay(_today);
        async.flushMicrotasks();
        expect(focus.alarm.scheduledAt, isNull);

        async.elapse(const Duration(minutes: 24, seconds: 45));
        expect(focus.state.shouldShowAlarm, isFalse);
      });
    });
  });
}
