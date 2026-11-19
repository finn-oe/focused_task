import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/pause_screen.dart';

import '../../../helpers/fake_notification_service.dart';
import '../../../helpers/fake_preferences.dart';
import '../../../helpers/fake_target_alarm.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/task_builders.dart';
import '../../../helpers/localized_app.dart';

Widget _app(FakeTaskRepository repository, SharedPreferences preferences, {String initialLocation = '/focus'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/focus',
        builder: (_, _) => FocusScreen(request: FocusRequest(DateTime.now())),
      ),
      GoRoute(path: '/pause', builder: (_, _) => const PauseScreen()),
      GoRoute(path: '/plan', builder: (_, _) => const Text('plan screen')),
    ],
  );
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    ],
    child: localizedRouterApp(routerConfig: router),
  );
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

  testWidgets('system back in focus mode pauses the session and returns to plan', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Deep work', assignedDate: DateTime.now())],
    );

    await tester.pumpWidget(_app(repository, await fakePreferences()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Deep work'), findsOneWidget);
    expect(repository.task(1).isRunning, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('plan screen'), findsOneWidget);
    expect(repository.task(1).isRunning, isFalse);
  });

  testWidgets('system back on the pause screen exits focus', (tester) async {
    final repository = FakeTaskRepository(tasks: [buildTask(assignedDate: DateTime.now())]);

    await tester.pumpWidget(_app(repository, await fakePreferences(), initialLocation: '/pause'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('plan screen'), findsOneWidget);
  });
}
