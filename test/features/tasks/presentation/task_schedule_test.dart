import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../../helpers/fake_notification_service.dart';
import '../../../helpers/fake_preferences.dart';
import '../../../helpers/fake_target_alarm.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/localized_app.dart';
import '../../../helpers/task_builders.dart';

/// Start/due times and reminders in the form, on the plan and in the settings (#10).
List<Override> _overrides(FakeTaskRepository repository, SharedPreferences preferences, FakeNotificationService notifications) => [
  taskRepositoryProvider.overrideWithValue(repository),
  focusSessionRepositoryProvider.overrideWithValue(repository),
  categoryRepositoryProvider.overrideWithValue(repository),
  inboxRepositoryProvider.overrideWithValue(repository),
  sharedPreferencesProvider.overrideWithValue(preferences),
  targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
  notificationServiceProvider.overrideWithValue(notifications),
  focusGoalProvider.overrideWithValue(FocusGoal.off),
];

void main() {
  final today = DateTime.now().dateOnly;
  late FakeNotificationService notifications;

  Future<GoRouter> pumpApp(WidgetTester tester, FakeTaskRepository repository, {Size size = const Size(500, 900), String initialLocation = AppRoutes.plan}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    notifications = FakeNotificationService();
    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);
    final preferences = await fakePreferences({PlanModeNotifier.rolloverPromptedKey: today.isoDate});
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository, preferences, notifications),
        child: localizedRouterApp(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openForm(WidgetTester tester, GoRouter router, [TaskEntity? task]) async {
    // ignore: unawaited_futures, the form stays open for the test
    router.push(AppRoutes.taskForm, extra: task);
    await tester.pumpAndSettle();
  }

  group('task form', () {
    testWidgets('the basics come first on a 360×640 phone; the schedule is one tile below them', (tester) async {
      final router = await pumpApp(tester, FakeTaskRepository(), size: const Size(360, 640));
      await openForm(tester, router);

      for (final label in ['Title', 'Date']) {
        expect(tester.getRect(find.widgetWithText(InputDecorator, label)).bottom, lessThan(640 - 80), reason: '$label is visible without scrolling');
      }
      expect(find.text('25 min'), findsOneWidget, reason: 'the estimate presets are on the first screen');

      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const Key('taskFormSchedule')), 200, scrollable: list);
      final schedule = tester.getRect(find.byKey(const Key('taskFormSchedule')));
      expect(schedule.top, greaterThan(tester.getRect(find.text('Sub-tasks')).top));
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('the sub-page sets a start time and a custom reminder; the summary and the saved task follow', (tester) async {
      final day = today.addDays(2);
      final repository = FakeTaskRepository(
        tasks: [buildTask(id: 1, title: 'Call Anna', assignedDate: day)],
      );
      final router = await pumpApp(tester, repository);
      await openForm(tester, router, repository.task(1));

      await tester.scrollUntilVisible(find.byKey(const Key('taskFormSchedule')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('taskFormSchedule')));
      await tester.pumpAndSettle();
      expect(find.text('Schedule & reminder'), findsOneWidget);
      expect(find.text('Set a start time or a due date to get a reminder.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('scheduleStart')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // the picker starts at 9:00
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scheduleReminder-30')));
      await tester.pumpAndSettle();

      final weekday = DateFormat.E('en').format(day);
      expect(find.text('Reminder at $weekday 8:30 AM'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Start 9:00 AM · 30 min before'), findsOneWidget);

      await tester.tap(find.byKey(const Key('taskFormSaveAction')));
      await tester.pumpAndSettle();
      expect(repository.task(1).schedule, const TaskSchedule(startMinute: 9 * 60, reminderMinutes: 30));
      expect(notifications.permissionRequests, 1, reason: 'the first reminder asks for notification permission');
    });

    testWidgets('a due date can be set and removed again; leaving with schedule changes asks first', (tester) async {
      final day = today.addDays(2);
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(
            id: 1,
            title: 'Report',
            assignedDate: day,
            schedule: TaskSchedule(dueDate: day),
          ),
        ],
      );
      final router = await pumpApp(tester, repository);
      await openForm(tester, router, repository.task(1));

      await tester.scrollUntilVisible(find.byKey(const Key('taskFormSchedule')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Due ${DateFormat.E('en').format(day)} 5:00 PM · 15 min before'), findsOneWidget);
      await tester.tap(find.byKey(const Key('taskFormSchedule')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scheduleDueTime')), findsOneWidget);
      expect(find.textContaining('Default (5:00 PM)'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const Key('scheduleDueDate')), matching: find.byTooltip('Remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scheduleDueTime')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('plan', () {
    testWidgets('tiles show the start time and the deadline; overdue tasks get a banner with their list', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(
            id: 1,
            title: 'Call Anna',
            assignedDate: today,
            sortOrder: 'a0',
            schedule: const TaskSchedule(startMinute: 23 * 60 + 59),
          ),
          buildTask(
            id: 2,
            title: 'Old report',
            assignedDate: today.addDays(-3),
            sortOrder: 'a0',
            schedule: TaskSchedule(dueDate: today.addDays(-1)),
          ),
          buildTask(
            id: 3,
            title: 'Tax return',
            assignedDate: today,
            sortOrder: 'a1',
            schedule: TaskSchedule(dueDate: today.addDays(10)),
          ),
        ],
      );
      await pumpApp(tester, repository);

      expect(find.byKey(const ValueKey('taskStartChip-1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('taskStartChip-1')), matching: find.text('11:59 PM')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('taskDueChip-3')), matching: find.text('Due ${DateFormat.MMMd('en').format(today.addDays(10))}')), findsOneWidget);

      expect(find.text('1 task overdue'), findsOneWidget);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Overdue tasks'), findsOneWidget);
      expect(find.byKey(const ValueKey('overdueTask-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('overdueTask-3')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('overdueTask-2')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Old report'), findsOneWidget);
    });

    testWidgets('no banner and no chips without times', (tester) async {
      await pumpApp(
        tester,
        FakeTaskRepository(
          tasks: [buildTask(id: 1, title: 'Plain', assignedDate: today)],
        ),
      );
      expect(find.byKey(const Key('overdueBanner')), findsNothing);
      expect(find.byKey(const ValueKey('taskStartChip-1')), findsNothing);
      expect(find.byKey(const ValueKey('taskDueChip-1')), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('one tile opens "Reminders & dates"; reminder types can be switched on and set', (tester) async {
      await pumpApp(tester, FakeTaskRepository(), initialLocation: AppRoutes.settings);
      expect(find.text('Test notification'), findsNothing, reason: 'the notification checks moved to the sub-page');

      await tester.scrollUntilVisible(find.byKey(const Key('settingsReminders')), 200, scrollable: find.byType(Scrollable).first);
      // Clear of the navigation bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsReminders')));
      await tester.pumpAndSettle();

      expect(find.text('Reminders & dates'), findsOneWidget);
      expect(find.byKey(const Key('settingsDefaultLead')), findsOneWidget);
      expect(find.byKey(const Key('settingsDailyPlanningTime')), findsNothing);

      await tester.tap(find.byKey(const Key('settingsDailyPlanning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsInactivity')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsDailyPlanningTime')), findsOneWidget);
      expect(find.byKey(const Key('settingsWorkStart')), findsOneWidget);
      expect(find.byKey(const Key('settingsIdleTime')), findsOneWidget);
      expect(notifications.permissionRequests, 1, reason: 'asked when the first reminder type is turned on');

      await tester.scrollUntilVisible(find.text('Test notification'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Test notification'), findsOneWidget);
    });
  });
}
