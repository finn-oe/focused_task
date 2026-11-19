import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../../helpers/fake_notification_service.dart';
import '../../../helpers/fake_preferences.dart';
import '../../../helpers/fake_target_alarm.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/localized_app.dart';
import '../../../helpers/task_builders.dart';

Future<ProviderContainer> _container(FakeTaskRepository repository, [Map<String, Object> preferences = const {}]) async {
  return ProviderContainer.test(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(await fakePreferences(preferences)),
    ],
  );
}

Future<void> _pumpPlan(WidgetTester tester, FakeTaskRepository repository, {required SharedPreferences preferences, String initialLocation = AppRoutes.plan}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
      child: localizedRouterApp(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PlanModeNotifier.moveTasks', () {
    final past = DateTime(2026, 11, 10);
    final today = DateTime(2026, 11, 17);

    test('moves open tasks after the target day’s tasks and skips completed ones', () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, assignedDate: today, sortOrder: 'a5'),
          buildTask(id: 2, assignedDate: past, sortOrder: 'a0', timeSpent: 60000),
          buildTask(id: 3, assignedDate: past, sortOrder: 'a1', isCompleted: true),
        ],
      );
      final container = await _container(repository);

      final move = await container.read(planModeNotifierProvider.notifier).moveTasks([2, 3], today);

      expect(move.previous.map((task) => task.id), [2]);
      expect(repository.task(2).assignedDate, today);
      expect(repository.task(2).timeSpent, 60000);
      expect(repository.task(2).sortOrder.compareTo('a5'), greaterThan(0));
      expect(repository.task(3).assignedDate, past);
    });

    test('undoMove puts the tasks back on their day and position', () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, assignedDate: past, sortOrder: 'a0'),
          buildTask(id: 2, assignedDate: past, sortOrder: 'a1'),
          buildTask(id: 3, assignedDate: past, sortOrder: 'a2'),
        ],
      );
      final notifier = (await _container(repository)).read(planModeNotifierProvider.notifier);

      final move = await notifier.moveTasks([2], today);
      await notifier.undoMove(move);

      expect(repository.task(2).assignedDate, past);
      expect((await repository.getTasksForDay(past)).map((task) => task.id), [1, 2, 3]);
    });

    test('moveOpenTasks moves only the open tasks of the day', () async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, assignedDate: past, sortOrder: 'a0'),
          buildTask(id: 2, assignedDate: past, sortOrder: 'a1', isCompleted: true),
        ],
      );
      final notifier = (await _container(repository)).read(planModeNotifierProvider.notifier);

      final move = await notifier.moveOpenTasks(from: past, to: today);

      expect(move.count, 1);
      expect((repository.task(1).assignedDate, repository.task(2).assignedDate), (today, past));
    });
  });

  group('rollover prompt', () {
    final today = DateTime(2026, 11, 19);
    FakeTaskRepository repository() => FakeTaskRepository(
      tasks: [
        buildTask(id: 1, title: 'Yesterday', assignedDate: today.addDays(-1)),
        buildTask(id: 2, title: 'A week ago', assignedDate: today.addDays(-7)),
        buildTask(id: 3, title: 'Too old', assignedDate: today.addDays(-8)),
        buildTask(id: 4, title: 'Done', assignedDate: today.addDays(-1), sortOrder: 'a1', isCompleted: true),
        buildTask(id: 5, title: 'Today', assignedDate: today),
      ],
    );

    test('offers the open tasks of the last 7 days once per day', () async {
      final container = await _container(repository());
      final notifier = container.read(planModeNotifierProvider.notifier);

      await withClock(Clock.fixed(today.add(const Duration(hours: 8))), () async {
        expect((await notifier.takeRolloverCandidates()).map((task) => task.id), [2, 1]);
        expect(await notifier.takeRolloverCandidates(), isEmpty, reason: 'only once per day');
      });
      await withClock(Clock.fixed(today.add(const Duration(hours: 23, minutes: 59))), () async {
        expect(await notifier.takeRolloverCandidates(), isEmpty);
      });
      await withClock(Clock.fixed(today.addDays(1).add(const Duration(hours: 7))), () async {
        expect((await notifier.takeRolloverCandidates()).map((task) => task.id), [1, 5], reason: 'a new day asks again');
      });
      expect(container.read(sharedPreferencesProvider).getString(PlanModeNotifier.rolloverPromptedKey), today.addDays(1).isoDate);
    });

    test('respects the setting', () async {
      final container = await _container(repository());

      await container.read(settingsNotifierProvider.notifier).setAskToMoveUnfinished(false);
      expect(container.read(sharedPreferencesProvider).getBool('settings.ask_to_move_unfinished'), isFalse);

      await withClock(Clock.fixed(today), () async {
        expect(await container.read(planModeNotifierProvider.notifier).takeRolloverCandidates(), isEmpty);
      });
    });
  });

  group('plan screen', () {
    final today = DateTime.now().dateOnly;
    final yesterday = today.addDays(-1);
    final promptedToday = {PlanModeNotifier.rolloverPromptedKey: today.isoDate};

    setUp(() {
      // wakelock_plus has no implementation in widget tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
    });

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Move or copy').first);
      await tester.pumpAndSettle();
    }

    testWidgets('Move to today moves the task and can be undone', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, title: 'Leftover', assignedDate: yesterday, sortOrder: 'a1'),
          buildTask(id: 2, title: 'Other', assignedDate: yesterday, sortOrder: 'a2'),
        ],
      );
      await _pumpPlan(
        tester,
        repository,
        preferences: await fakePreferences(promptedToday),
        initialLocation: AppRoutes.planFor(yesterday, today: today),
      );

      await openMenu(tester);
      expect(find.text('Move to today'), findsOneWidget);
      expect(find.text('Move to…'), findsOneWidget);
      expect(find.text('Copy to…'), findsOneWidget);

      await tester.tap(find.text('Move to today'));
      await tester.pumpAndSettle();
      expect(repository.task(1).assignedDate, today);
      expect(find.text('Leftover'), findsNothing, reason: 'the task left the shown day');
      expect(find.text('Task moved to today'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.task(1).assignedDate, yesterday);
      expect(repository.task(1).sortOrder, 'a1');
      expect(find.text('Leftover'), findsOneWidget);
    });

    testWidgets('Move to… moves the task to the picked day', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [buildTask(id: 1, title: 'Leftover', assignedDate: yesterday)],
      );
      await _pumpPlan(
        tester,
        repository,
        preferences: await fakePreferences(promptedToday),
        initialLocation: AppRoutes.planFor(yesterday, today: today),
      );
      // A day in today's month (the picker opens there) that is neither today nor yesterday.
      final target = DateTime(today.year, today.month, today.day > 14 ? today.day - 7 : today.day + 7);

      await openMenu(tester);
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('${target.day}')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.task(1).assignedDate, target);
      expect(find.textContaining('Task moved to'), findsOneWidget);
    });

    testWidgets('Copy to… keeps the original and adds a copy', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [buildTask(id: 1, title: 'Leftover', assignedDate: yesterday)],
      );
      await _pumpPlan(
        tester,
        repository,
        preferences: await fakePreferences(promptedToday),
        initialLocation: AppRoutes.planFor(yesterday, today: today),
      );

      await openMenu(tester);
      await tester.tap(find.text('Copy to…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // the picker starts on today
      await tester.pumpAndSettle();
      expect(find.text('Copy to Today'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(repository.task(1).assignedDate, yesterday);
      expect(repository.tasks.where((task) => task.title == 'Leftover').map((task) => task.assignedDate), unorderedEquals([yesterday, today]));
    });

    testWidgets('completed past tasks can only be copied', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [buildTask(id: 1, title: 'Finished', assignedDate: yesterday, isCompleted: true)],
      );
      await _pumpPlan(
        tester,
        repository,
        preferences: await fakePreferences(promptedToday),
        initialLocation: AppRoutes.planFor(yesterday, today: today),
      );

      await openMenu(tester);
      expect(find.text('Move to today'), findsNothing);
      expect(find.text('Move to…'), findsNothing);
      expect(find.text('Copy to…'), findsOneWidget);
    });

    testWidgets('the first start of a day offers to move open tasks; unchecked ones stay', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, title: 'Write report', assignedDate: yesterday),
          buildTask(id: 2, title: 'Call back', assignedDate: today.addDays(-3)),
          buildTask(id: 3, title: 'Finished', assignedDate: yesterday, sortOrder: 'a1', isCompleted: true),
        ],
      );
      final preferences = await fakePreferences();
      await _pumpPlan(tester, repository, preferences: preferences);

      expect(find.text('Unfinished tasks'), findsOneWidget);
      expect(find.text('2 tasks from the last few days are still open.'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Finished'), findsNothing);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Call back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move 1 task to today'));
      await tester.pumpAndSettle();

      expect(repository.task(1).assignedDate, today);
      expect(repository.task(2).assignedDate, today.addDays(-3));
      expect(find.text('Write report'), findsOneWidget, reason: 'now in today’s plan');
      expect(find.text('Task moved to today'), findsOneWidget);

      // Starting again on the same day doesn't ask again.
      await tester.pumpWidget(const SizedBox());
      await _pumpPlan(tester, repository, preferences: preferences);
      expect(find.text('Unfinished tasks'), findsNothing);
    });

    testWidgets('the rollover sheet works on a 360 px screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeTaskRepository(
        tasks: [for (var i = 1; i <= 12; i++) buildTask(id: i, title: 'A rather long task title number $i that wraps', assignedDate: yesterday, sortOrder: 'a$i')],
      );
      await _pumpPlan(tester, repository, preferences: await fakePreferences());

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(repository.task(1).assignedDate, yesterday);
    });
  });
}
