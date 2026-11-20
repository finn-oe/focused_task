import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

Future<SharedPreferences> _pumpApp(WidgetTester tester, FakeTaskRepository repository, {Map<String, Object> preferences = const {}}) async {
  final router = createAppRouter();
  addTearDown(router.dispose);
  final prefs = await fakePreferences({PlanModeNotifier.rolloverPromptedKey: DateTime.now().dateOnly.isoDate, ...preferences});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        recurrenceRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
      child: localizedRouterApp(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  final today = DateTime.now().dateOnly;

  setUp(() {
    // wakelock_plus has no implementation in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  testWidgets('capture a thought in focus, review it on the plan and turn it into a task for today', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: today)],
    );
    await _pumpApp(tester, repository);
    expect(find.byKey(const Key('parkedThoughtsBanner')), findsNothing);

    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focusParkThought')), 'Book dentist');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Parked for later.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('focusParkThought'))).controller!.text, isEmpty, reason: 'the field clears');
    expect(find.text('Deep work'), findsOneWidget, reason: 'focus stays on the task');
    expect(repository.inboxItems.single.text, 'Book dentist');

    // The close button in the app bar; the snack bar covers the buttons at the bottom.
    await tester.tap(find.byTooltip('Exit focus'));
    await tester.pumpAndSettle();
    expect(find.text('Parked for later.'), findsNothing, reason: 'focus snack bars do not follow to the plan');
    expect(find.text('1 parked thought'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Parked thoughts'), findsOneWidget);
    expect(find.text('Book dentist'), findsOneWidget);

    await tester.tap(find.byTooltip('Add as a task for today'));
    await tester.pumpAndSettle();
    expect(find.text('Added to today.'), findsOneWidget);
    expect(find.text('All reviewed.'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parkedThoughtsBanner')), findsNothing);
    expect(find.text('Book dentist'), findsOneWidget, reason: 'the new task is in the plan');
    expect(repository.tasks.where((task) => task.title == 'Book dentist').single.assignedDate, today);
  });

  testWidgets('dismissing a parked thought can be undone in the sheet', (tester) async {
    final repository = FakeTaskRepository();
    await repository.addInboxItem(text: 'Look up flights', at: DateTime.now());
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Dismissed.'), findsOneWidget);
    expect(find.text('All reviewed.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Look up flights'), findsWidgets);
    expect(repository.inboxItems.single.isResolved, isFalse);
  });

  testWidgets('"I got distracted" counts an interruption on the session and nudges back', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: today)],
    );
    await _pumpApp(tester, repository);
    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('I got distracted'));
    await tester.pumpAndSettle();

    expect(find.text('Noted. Back to Deep work.'), findsOneWidget);
    expect(repository.sessions.single.interruptions, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Focus'));
    await tester.pumpAndSettle();
  });

  testWidgets('the minimal layout hides the app bar and secondary buttons and is remembered', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: today, targetDurationMinutes: 25)],
    );
    final prefs = await _pumpApp(tester, repository);
    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Minimal layout'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Exit Focus'), findsNothing);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('Complete Task'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('focusMinimalTimer'))).data, '00:25:00');
    expect(find.byKey(const Key('focusParkThought')), findsOneWidget);
    expect(prefs.getBool('settings.focus_minimal_layout'), isTrue);

    await tester.tap(find.byTooltip('Show everything'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(prefs.getBool('settings.focus_minimal_layout'), isFalse);
    await tester.tap(find.text('Exit Focus'));
    await tester.pumpAndSettle();
  });

  testWidgets('focus with the minimal layout fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'A task with a rather long title to wrap', assignedDate: today)],
    );
    await _pumpApp(tester, repository, preferences: {'settings.focus_minimal_layout': true});

    await tester.tap(find.byTooltip('Start focus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focusMinimalTimer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the app pauses focus; coming back counts the interruption and says how long it took', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: today)],
    );
    await _pumpApp(tester, repository);
    await tester.tap(find.text('Start focus'));
    await tester.pumpAndSettle();

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(repository.sessions.single.endReason, EndReason.background);

    await tester.pump(const Duration(minutes: 4));
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(find.text('Resume Focus'), findsOneWidget, reason: 'focus was paused in the background');
    expect(find.text('You were away 4 min.'), findsOneWidget);
    expect(repository.sessions.single.interruptions, 1);
  });

  testWidgets('the statistics list the recent parked thoughts and the interruption rate', (tester) async {
    // Noon, so the session can't cross midnight.
    final now = DateTime(today.year, today.month, today.day, 12);
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: today)],
    );
    final session = await repository.start(taskId: 1, at: now.subtract(const Duration(hours: 2)));
    for (var i = 0; i < 3; i++) {
      await repository.addInterruption(session.id);
    }
    await repository.end(session.id, now, EndReason.paused);
    await repository.addInboxItem(text: 'Renew passport', at: now);
    final reviewed = await repository.addInboxItem(text: 'Water plants', at: now);
    await repository.resolveInboxItem(reviewed, now);
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Statistics').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('statsParkedThoughts')), 200, scrollable: find.byType(Scrollable).first);

    expect(find.text('Renew passport'), findsOneWidget);
    expect(find.text('Water plants'), findsOneWidget);
    expect(find.byTooltip('Reviewed'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Interruptions per focus hour'), -200, scrollable: find.byType(Scrollable).first);
    expect(find.text('1.5'), findsOneWidget, reason: '3 interruptions in 2 h of focus');
  });
}
