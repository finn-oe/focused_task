import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/break_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_screen.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

/// Short intervals keep the tests fast: 2 min work, 1 min break.
const _intervals = IntervalSettings(isEnabled: true, work: Duration(minutes: 2), shortBreak: Duration(minutes: 1));

Widget _app(FakeTaskRepository repository, SharedPreferences preferences, {IntervalSettings intervals = _intervals, String initialLocation = AppRoutes.focus}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.focus,
        builder: (_, _) => FocusScreen(request: FocusRequest(DateTime.now())),
      ),
      GoRoute(path: AppRoutes.breakTime, builder: (_, _) => const BreakScreen()),
      GoRoute(path: AppRoutes.plan, builder: (_, _) => const Text('plan screen')),
    ],
  );
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      recurrenceRepositoryProvider.overrideWithValue(repository),
      inboxRepositoryProvider.overrideWithValue(repository),
      targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      intervalSettingsProvider.overrideWithValue(intervals),
    ],
    child: localizedRouterApp(routerConfig: router),
  );
}

/// Pumps one frame per second for [duration], so the focus ticker runs.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  for (var second = 0; second < duration.inSeconds; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<FakeTaskRepository> _startFocus(WidgetTester tester, {IntervalSettings intervals = _intervals}) async {
  final repository = FakeTaskRepository(
    tasks: [buildTask(title: 'Deep work', assignedDate: DateTime.now())],
  );
  await tester.pumpWidget(_app(repository, await fakePreferences(), intervals: intervals));
  await tester.pump();
  await tester.pump();
  return repository;
}

void main() {
  setUp(() {
    // wakelock_plus has no implementation in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle', (
      _,
    ) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    });
  });

  testWidgets('focus shows when the break comes and switches to the break screen at the end of the interval', (tester) async {
    final repository = await _startFocus(tester);
    expect(find.text('Break in 00:02:00'), findsOneWidget);

    await _wait(tester, const Duration(minutes: 2, seconds: 2));

    expect(find.text('Short break'), findsOneWidget);
    expect(find.text('Stand up, stretch and look away from the screen.'), findsOneWidget);
    expect(find.byKey(const Key('breakCountdown')), findsOneWidget);
    expect(find.text('Skip break'), findsOneWidget);
    expect(repository.sessions.last.kind, SessionKind.breakTime);

    await tester.tap(find.text('Skip break'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Deep work'), findsOneWidget);
    expect(repository.task(1).isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('after the break it asks "Ready?" and continues with the task', (tester) async {
    final repository = await _startFocus(tester);
    await _wait(tester, const Duration(minutes: 3, seconds: 3));

    expect(find.text('Ready?'), findsOneWidget);
    expect(find.text('Continue with Deep work'), findsOneWidget);
    expect(repository.task(1).isRunning, isFalse);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Deep work'), findsOneWidget);
    expect(repository.task(1).isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with auto-start focus continues on its own after the break', (tester) async {
    final repository = await _startFocus(tester, intervals: _intervals.copyWith(autoStart: true));
    await _wait(tester, const Duration(minutes: 3, seconds: 3));

    expect(find.text('Ready?'), findsNothing);
    expect(find.text('Deep work'), findsOneWidget);
    expect(repository.task(1).isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ending focus on the break screen closes the break and returns to the plan', (tester) async {
    final repository = await _startFocus(tester);
    await _wait(tester, const Duration(minutes: 2, seconds: 2));

    await tester.tap(find.text('Exit Focus'));
    await tester.pumpAndSettle();

    expect(find.text('plan screen'), findsOneWidget);
    expect(repository.sessions.where((session) => session.isOpen), isEmpty);
    expect(repository.sessions.last.endReason, EndReason.exited);
  });

  testWidgets('the break screen without a break (e.g. a reload) goes to the plan', (tester) async {
    await tester.pumpWidget(_app(FakeTaskRepository(), await fakePreferences(), initialLocation: AppRoutes.breakTime));
    await tester.pumpAndSettle();

    expect(find.text('plan screen'), findsOneWidget);
  });

  testWidgets('the break screen fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _startFocus(tester);
    await _wait(tester, const Duration(minutes: 2, seconds: 2));
    expect(find.text('Skip break'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
