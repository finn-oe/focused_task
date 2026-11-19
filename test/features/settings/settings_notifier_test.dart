import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';
import '../../helpers/localized_app.dart';

FakeTaskRepository _repositoryWithOldCompletedTask() {
  return FakeTaskRepository(tasks: [buildTask(isCompleted: true, assignedDate: DateTime.now().addDays(-40))]);
}

Future<ProviderContainer> _container(FakeTaskRepository repository, [Map<String, Object> preferences = const {}]) async {
  final container = ProviderContainer.test(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(await fakePreferences(preferences)),
    ],
  );
  return container;
}

void main() {
  group('SettingsNotifier', () {
    test('reads stored settings synchronously on first access', () async {
      final container = await _container(FakeTaskRepository(), {'settings.theme_mode': 'dark', 'settings.retention_days': 0, 'settings.enable_wakelock': true});

      final settings = container.read(settingsNotifierProvider);

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.retentionDays, 1, reason: 'retention is clamped to at least one day');
      expect(settings.enableWakelock, isTrue);
      expect(settings.pauseOnBackground, isTrue);
    });
  });

  group('SettingsNotifier launch cleanup', () {
    test('is disabled by default so statistics history is kept', () async {
      final repository = _repositoryWithOldCompletedTask();
      final container = await _container(repository);

      await container.read(appStartupProvider.future);

      expect(container.read(settingsNotifierProvider).autoCleanupEnabled, isFalse);
      expect(repository.tasks, hasLength(1));
    });

    test('deletes old completed tasks when enabled', () async {
      final repository = _repositoryWithOldCompletedTask();
      final container = await _container(repository, {'settings.auto_cleanup_enabled': true});

      await container.read(appStartupProvider.future);

      expect(repository.tasks, isEmpty);
    });

    test('persists the opt-in', () async {
      final container = await _container(FakeTaskRepository());

      await container.read(settingsNotifierProvider.notifier).setAutoCleanupEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.auto_cleanup_enabled'), isTrue);
      expect(container.read(settingsNotifierProvider).autoCleanupEnabled, isTrue);
    });
  });

  testWidgets('settings are shown on the first frame without a loading state', (tester) async {
    // Tall enough that the data retention section is built without scrolling.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await _container(FakeTaskRepository(), {'settings.retention_days': 12});
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SettingsScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retention period: 12 days'), findsOneWidget);
  });

  testWidgets('Clean now asks for confirmation and keeps data on cancel', (tester) async {
    final repository = _repositoryWithOldCompletedTask();
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(find.text('Clean now'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean now'));
    await tester.pumpAndSettle();

    expect(find.text('Delete old tasks?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.tasks, hasLength(1));

    await tester.scrollUntilVisible(find.text('Clean now'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.tasks, isEmpty);
  });
}
