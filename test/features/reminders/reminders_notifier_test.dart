import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/reminders/presentation/reminders_notifier.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';

/// Wednesday morning.
final _now = DateTime(2026, 11, 18, 9);

void main() {
  late FakeNotificationService notifications;

  Future<ProviderContainer> start(FakeTaskRepository repository, {Map<String, Object> preferences = const {}, DateTime? openedAt}) async {
    final container = ProviderContainer.test(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences(preferences)),
        notificationServiceProvider.overrideWithValue(notifications),
        appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
        focusGoalProvider.overrideWithValue(const FocusGoal(daily: null, workingDays: FocusGoal.defaultWorkingDays)),
        appOpenedAtProvider.overrideWithValue(openedAt ?? _now),
      ],
    );
    container.listen(remindersNotifierProvider, (_, _) {});
    await container.read(remindersNotifierProvider.notifier).settled;
    return container;
  }

  setUp(() => notifications = FakeNotificationService());

  test('a task with a start time gets a reminder; the text names the start', () async {
    await withClock(Clock.fixed(_now), () async {
      await start(
        FakeTaskRepository(
          tasks: [
            buildTask(
              id: 3,
              title: 'Call Anna',
              assignedDate: _now,
              schedule: const TaskSchedule(startMinute: 14 * 60),
            ),
          ],
        ),
      );

      final (notification, at) = notifications.scheduled[NotificationIds.taskReminder(3)]!;
      expect(at, DateTime(2026, 11, 18, 13, 45));
      expect(notification.title, 'Call Anna');
      expect(notification.body, 'Starts at ${DateFormat.jm('en').format(DateTime(2026, 11, 18, 14))}');
      expect(notification.channel, NotificationChannel.reminders);
    });
  });

  test('completing the task or turning its reminder off cancels it', () async {
    await withClock(Clock.fixed(_now), () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(
            id: 3,
            assignedDate: _now,
            schedule: const TaskSchedule(startMinute: 14 * 60),
          ),
        ],
      );
      final container = await start(repository);
      expect(notifications.scheduled, contains(NotificationIds.taskReminder(3)));

      await repository.setTaskCompletion(taskId: 3, isCompleted: true);
      await container.read(remindersNotifierProvider.notifier).settled;

      expect(notifications.scheduled, isNot(contains(NotificationIds.taskReminder(3))));
      expect(notifications.cancelled, contains(NotificationIds.taskReminder(3)));
    });
  });

  test('a passed reminder time is shown at once, and not again after a restart', () async {
    final now = DateTime(2026, 11, 18, 13, 50);
    await withClock(Clock.fixed(now), () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(
            id: 3,
            assignedDate: now,
            schedule: const TaskSchedule(startMinute: 14 * 60),
          ),
        ],
      );
      final first = await start(repository);
      expect(notifications.shown.single.id, NotificationIds.taskReminder(3));
      final stored = first.read(sharedPreferencesProvider).getStringList(RemindersNotifier.deliveredKey)!;

      notifications = FakeNotificationService();
      await start(repository, preferences: {RemindersNotifier.deliveredKey: stored});
      expect(notifications.shown, isEmpty);
      expect(notifications.scheduled, isNot(contains(NotificationIds.taskReminder(3))));
    });
  });

  test('tracked time moves a due reminder', () async {
    await withClock(Clock.fixed(_now), () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(
            id: 3,
            assignedDate: _now,
            targetDurationMinutes: 120,
            schedule: TaskSchedule(dueDate: _now, dueMinute: 18 * 60),
          ),
        ],
      );
      final container = await start(repository);
      expect(notifications.scheduled[NotificationIds.taskReminder(3)]!.$2, DateTime(2026, 11, 18, 15, 45));

      await repository.addManualTime(taskId: 3, day: _now, duration: const Duration(minutes: 60));
      await container.read(remindersNotifierProvider.notifier).settled;

      expect(notifications.scheduled[NotificationIds.taskReminder(3)]!.$2, DateTime(2026, 11, 18, 16, 45));
    });
  });

  test('daily planning: scheduled for the next working day without tasks', () async {
    final early = DateTime(2026, 11, 18, 7);
    await withClock(Clock.fixed(early), () async {
      final repository = FakeTaskRepository();
      final container = await start(repository, preferences: {'settings.daily_planning': true});
      expect(notifications.scheduled[NotificationIds.dailyPlanning]!.$2, DateTime(2026, 11, 18, 8, 30));
      expect(notifications.scheduled[NotificationIds.dailyPlanning]!.$1.title, 'Plan your day');

      await repository.createTask(title: 'Report', assignedDate: early, sortOrder: 'a0');
      await container.read(remindersNotifierProvider.notifier).settled;

      expect(notifications.scheduled[NotificationIds.dailyPlanning]!.$2, DateTime(2026, 11, 19, 8, 30), reason: 'today has a task now');
    });
  });

  test('inactivity: after the idle time, cancelled while a focus session runs', () async {
    var now = _now;
    await withClock(Clock(() => now), () async {
      final repository = FakeTaskRepository(tasks: [buildTask(id: 1, assignedDate: _now)]);
      final container = await start(repository, preferences: {'settings.inactivity_reminder': true});
      final (notification, at) = notifications.scheduled[NotificationIds.inactivity]!;
      expect(at, DateTime(2026, 11, 18, 10));
      expect(notification.title, 'Ready for the next focus block?');

      final session = await repository.start(taskId: 1, at: _now);
      await container.read(remindersNotifierProvider.notifier).settled;
      expect(notifications.scheduled, isNot(contains(NotificationIds.inactivity)));

      now = DateTime(2026, 11, 18, 9, 30);
      await repository.end(session.id, now, EndReason.paused);
      await container.read(remindersNotifierProvider.notifier).settled;
      expect(notifications.scheduled[NotificationIds.inactivity]!.$2, DateTime(2026, 11, 18, 10, 30), reason: 'counted from the end of the session');
    });
  });

  test('everything off: nothing is scheduled', () async {
    await withClock(Clock.fixed(_now), () async {
      await start(
        FakeTaskRepository(
          tasks: [
            buildTask(
              id: 3,
              assignedDate: _now,
              schedule: const TaskSchedule(startMinute: 14 * 60),
            ),
          ],
        ),
        preferences: {'settings.task_reminders': false},
      );
      expect(notifications.scheduled, isEmpty);
      expect(notifications.shown, isEmpty);
    });
  });
}
