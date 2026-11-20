import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';

final _today = DateTime(2026, 11, 20);

/// Runs [body] in fake time from 09:00 with focus running on one task.
void _run(
  void Function(FakeAsync async, ProviderContainer container, FocusModeNotifier notifier, FakeTaskRepository repository) body, {
  IntervalSettings intervals = IntervalSettings.off,
  List<TaskEntity>? tasks,
}) {
  fakeAsync((async) {
    final repository = FakeTaskRepository(tasks: tasks ?? [buildTask(assignedDate: _today)]);
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
        focusGoalProvider.overrideWithValue(FocusGoal.off),
        intervalSettingsProvider.overrideWithValue(intervals),
        appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
      ],
    );
    // Like the plan screen: the inbox is watched while focus runs.
    container.listen(inboxNotifierProvider, (_, _) {});
    final notifier = container.read(focusModeNotifierProvider.notifier);
    notifier.initializeForDay(_today);
    async.flushMicrotasks();
    body(async, container, notifier, repository);
    container.dispose();
  }, initialTime: DateTime(2026, 11, 20, 9));
}

FocusSession _focusSession(FakeTaskRepository repository) => repository.sessions.where((session) => session.kind == SessionKind.focus).last;

void main() {
  group('interruptions', () {
    test('debounce: the lifecycle events of one switch count once', () {
      _run((async, container, notifier, repository) {
        // A desktop window losing focus, then the app being hidden and paused: one switch.
        notifier.appLeft();
        async.elapse(const Duration(milliseconds: 300));
        notifier.appLeft();
        notifier.appLeft();
        async.elapse(const Duration(seconds: 5));
        notifier.appReturned();
        notifier.appReturned();
        async.flushMicrotasks();

        expect(_focusSession(repository).interruptions, 1);
      });
    });

    test('switches shorter than 2 s do not count', () {
      _run((async, container, notifier, repository) {
        for (var i = 0; i < 5; i++) {
          notifier.appLeft();
          async.elapse(const Duration(milliseconds: 1500));
          notifier.appReturned();
          async.flushMicrotasks();
        }
        expect(_focusSession(repository).interruptions, 0);

        notifier.appLeft();
        async.elapse(FocusModeNotifier.interruptionThreshold);
        notifier.appReturned();
        async.flushMicrotasks();
        expect(_focusSession(repository).interruptions, 1);
      });
    });

    test('"I got distracted" counts on the running session; the counter is stored on it', () {
      _run((async, container, notifier, repository) {
        notifier.recordDistraction();
        notifier.recordDistraction();
        async.flushMicrotasks();
        final session = _focusSession(repository);
        expect(session.interruptions, 2);

        async.elapse(const Duration(minutes: 5));
        notifier.pauseSession();
        async.flushMicrotasks();
        expect(repository.sessions.single.interruptions, 2, reason: 'ending the session keeps the counter');

        notifier.recordDistraction();
        async.flushMicrotasks();
        expect(repository.sessions.single.interruptions, 2, reason: 'nothing to count while paused');
      });
    });

    test('a switch that paused focus in the background counts on the session it interrupted', () {
      _run((async, container, notifier, repository) {
        notifier.appLeft();
        notifier.pauseSession(reason: EndReason.background);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 4));
        notifier.appReturned();
        async.flushMicrotasks();

        final session = repository.sessions.single;
        expect(session.endReason, EndReason.background);
        expect(session.interruptions, 1);
      });
    });

    test('leaving during a break is not a distraction', () {
      _run(intervals: const IntervalSettings(isEnabled: true, work: Duration(minutes: 1)), (async, container, notifier, repository) {
        async.elapse(const Duration(minutes: 1, seconds: 2));
        expect(container.read(focusModeNotifierProvider).isOnBreak, isTrue);

        notifier.appLeft();
        async.elapse(const Duration(minutes: 3));
        notifier.appReturned();
        async.flushMicrotasks();

        expect(repository.sessions.every((session) => session.interruptions == 0), isTrue);
        expect(container.read(focusModeNotifierProvider).awayFor, isNull);
      });
    });
  });

  group('welcome back', () {
    test('after a minute or more away the state says how long', () {
      _run((async, container, notifier, repository) {
        notifier.appLeft();
        async.elapse(const Duration(minutes: 4, seconds: 10));
        notifier.appReturned();
        async.flushMicrotasks();
        expect(container.read(focusModeNotifierProvider).awayFor, const Duration(minutes: 4, seconds: 10));

        notifier.clearAwayFor();
        expect(container.read(focusModeNotifierProvider).awayFor, isNull);
      });
    });

    test('a short absence counts but needs no message', () {
      _run((async, container, notifier, repository) {
        notifier.appLeft();
        async.elapse(const Duration(seconds: 20));
        notifier.appReturned();
        async.flushMicrotasks();
        expect(container.read(focusModeNotifierProvider).awayFor, isNull);
        expect(_focusSession(repository).interruptions, 1);
      });
    });

    test('exiting focus forgets an absence', () {
      _run((async, container, notifier, repository) {
        notifier.appLeft();
        notifier.exitFocus();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));
        notifier.appReturned();
        async.flushMicrotasks();
        expect(repository.sessions.single.interruptions, 0);
      });
    });
  });

  group('parking thoughts', () {
    test('parks a trimmed thought linked to the running session; empty text is ignored', () {
      _run((async, container, notifier, repository) {
        async.elapse(const Duration(minutes: 3));
        notifier.parkThought('  reply to Tom ');
        notifier.parkThought('   ');
        async.flushMicrotasks();

        final item = repository.inboxItems.single;
        expect(item.text, 'reply to Tom');
        expect(item.sessionId, _focusSession(repository).id);
        expect(item.createdAt, clock.now());
        expect(container.read(inboxNotifierProvider).open, [item]);
      });
    });

    test('turn a parked thought into a task at the end of today or tomorrow; dismiss and undo', () {
      _run(tasks: [buildTask(id: 1, assignedDate: _today, sortOrder: 'a5')], (async, container, notifier, repository) {
        notifier.parkThought('first');
        notifier.parkThought('second');
        notifier.parkThought('third');
        async.flushMicrotasks();
        final inbox = container.read(inboxNotifierProvider.notifier);
        final [first, second, third] = container.read(inboxNotifierProvider).open;

        int? todayId;
        int? tomorrowId;
        inbox.convertToTask(first, _today).then((id) => todayId = id);
        inbox.convertToTask(second, _today.nextDay).then((id) => tomorrowId = id);
        inbox.dismiss(third);
        async.flushMicrotasks();

        final today = repository.task(todayId!);
        expect((today.title, today.assignedDate, today.isCompleted), ('first', _today, false));
        expect(today.sortOrder.compareTo('a5'), greaterThan(0), reason: 'added at the end of the plan');
        expect(repository.task(tomorrowId!).assignedDate, _today.nextDay);
        expect(container.read(inboxNotifierProvider).open, isEmpty);
        expect(repository.inboxItems.every((item) => item.isResolved), isTrue);

        inbox.reopen(third);
        async.flushMicrotasks();
        expect(container.read(inboxNotifierProvider).open.map((item) => item.text), ['third']);
      });
    });
  });
}
