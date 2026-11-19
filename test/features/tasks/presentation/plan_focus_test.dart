import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

Future<GoRouter> _pumpApp(WidgetTester tester, FakeTaskRepository repository, {String initialLocation = AppRoutes.plan}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        // The daily rollover prompt was already offered; these tests are about "Start focus".
        sharedPreferencesProvider.overrideWithValue(await fakePreferences({PlanModeNotifier.rolloverPromptedKey: DateTime.now().dateOnly.isoDate})),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
      child: localizedRouterApp(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.routeInformationProvider.value.uri.toString();

void main() {
  final today = DateTime.now().dateOnly;

  setUp(() {
    // wakelock_plus has no implementation in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  testWidgets('the play button on the second task opens focus on that task', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [
        buildTask(id: 1, title: 'First', assignedDate: today, sortOrder: 'a0'),
        buildTask(id: 2, title: 'Second', assignedDate: today, sortOrder: 'a1'),
      ],
    );
    final router = await _pumpApp(tester, repository);

    await tester.tap(find.byTooltip('Focus on this task').at(1));
    await tester.pumpAndSettle();

    expect(_location(router), '/focus?day=${today.isoDate}&task=2');
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(repository.task(2).isRunning, isTrue);
  });

  testWidgets('Start focus on a future day asks before working ahead', (tester) async {
    final tomorrow = today.addDays(1);
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Prepare', assignedDate: tomorrow)],
    );
    final router = await _pumpApp(tester, repository, initialLocation: AppRoutes.planFor(tomorrow, today: today));

    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();
    expect(find.text('Work on tomorrow’s tasks now?'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(_location(router), '/focus?day=${tomorrow.isoDate}');
    expect(find.text('Prepare'), findsOneWidget);
  });

  testWidgets('Start focus on a past day with open tasks offers to move them to today', (tester) async {
    final past = today.addDays(-3);
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Leftover', assignedDate: past)],
    );
    final router = await _pumpApp(tester, repository, initialLocation: AppRoutes.planFor(past, today: today));

    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();
    expect(find.text('Move to today?'), findsOneWidget);

    await tester.tap(find.text('Move and start'));
    await tester.pumpAndSettle();
    expect(repository.task(1).assignedDate, today);
    expect(_location(router), '/focus?day=${today.isoDate}');
    expect(find.text('Leftover'), findsOneWidget);
  });

  testWidgets('with nothing open today, Start focus offers yesterday’s open tasks; cancel keeps them', (tester) async {
    final yesterday = today.addDays(-1);
    final repository = FakeTaskRepository(
      tasks: [
        buildTask(id: 1, title: 'Unfinished', assignedDate: yesterday),
        buildTask(id: 2, assignedDate: today, isCompleted: true, sortOrder: 'a1'),
      ],
    );
    final router = await _pumpApp(tester, repository);

    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing open today'), findsOneWidget);
    expect(find.textContaining('1 task from yesterday'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.task(1).assignedDate, yesterday);
    expect(_location(router), '/plan');
  });

  testWidgets('skipping in focus mode shows the next task', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [
        buildTask(id: 1, title: 'First', assignedDate: today, sortOrder: 'a0'),
        buildTask(id: 2, title: 'Second', assignedDate: today, sortOrder: 'a1'),
      ],
    );
    await _pumpApp(tester, repository, initialLocation: '/focus?day=${today.isoDate}');
    expect(find.widgetWithText(ListTile, 'Second'), findsOneWidget, reason: 'up next');

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'First'), findsOneWidget, reason: 'the skipped task is up next again');
    expect(repository.task(1).isCompleted, isFalse);
  });
}
