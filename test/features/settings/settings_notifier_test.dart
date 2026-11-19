import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
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

  group('SettingsNotifier intervals', () {
    test('are off by default with 25 / 5 / 15 min and a long break every 4 intervals', () async {
      final container = await _container(FakeTaskRepository());

      expect(container.read(settingsNotifierProvider).intervals, IntervalSettings.off);
      expect(container.read(intervalSettingsProvider).work, const Duration(minutes: 25));
      expect(container.read(intervalSettingsProvider).longBreakEvery, 4);
    });

    test('persist every setting', () async {
      final container = await _container(FakeTaskRepository());
      const changed = IntervalSettings(
        isEnabled: true,
        work: Duration(minutes: 50),
        shortBreak: Duration(minutes: 10),
        longBreak: Duration(minutes: 30),
        longBreakEvery: 3,
        autoStart: true,
      );
      await container.read(settingsNotifierProvider.notifier).setIntervals(changed);
      expect(container.read(intervalSettingsProvider), changed);

      final preferences = container.read(sharedPreferencesProvider);
      final reloaded = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences), taskRepositoryProvider.overrideWithValue(FakeTaskRepository())],
      );
      expect(reloaded.read(settingsNotifierProvider).intervals, changed);
    });

    test('invalid stored values fall back to the defaults', () async {
      final container = await _container(FakeTaskRepository(), {'settings.interval_work_minutes': 0, 'settings.interval_long_break_every': -1});

      expect(container.read(intervalSettingsProvider).work, IntervalSettings.defaultWork);
      expect(container.read(intervalSettingsProvider).longBreakEvery, IntervalSettings.defaultLongBreakEvery);
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

  testWidgets('turning intervals on shows their lengths and changes them', (tester) async {
    final container = await _container(FakeTaskRepository());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('settingsIntervals')), 200);
    await tester.pumpAndSettle();
    expect(find.text('Work interval'), findsNothing);

    await tester.tap(find.byKey(const Key('settingsIntervals')));
    await tester.pumpAndSettle();
    expect(container.read(intervalSettingsProvider).isEnabled, isTrue);

    await tester.scrollUntilVisible(find.text('Continue automatically after a break'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Work interval'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('4 intervals'), findsOneWidget);

    await tester.ensureVisible(find.text('25 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 min').last);
    await tester.pumpAndSettle();
    expect(container.read(intervalSettingsProvider).work, const Duration(minutes: 50));
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
