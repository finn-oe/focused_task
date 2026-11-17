import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/settings/presentation/settings_notifier.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';

FakeTaskRepository _repositoryWithOldCompletedTask() {
  return FakeTaskRepository(tasks: [buildTask(isCompleted: true, assignedDate: DateTime.now().addDays(-40))]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsNotifier launch cleanup', () {
    test('is disabled by default so statistics history is kept', () async {
      final repository = _repositoryWithOldCompletedTask();
      final notifier = SettingsNotifier(repository);

      await notifier.initialize();
      await notifier.runLaunchCleanupIfNeeded();

      expect(notifier.state.autoCleanupEnabled, isFalse);
      expect(repository.tasks, hasLength(1));
    });

    test('deletes old completed tasks when enabled', () async {
      SharedPreferences.setMockInitialValues({'settings.auto_cleanup_enabled': true});
      final repository = _repositoryWithOldCompletedTask();
      final notifier = SettingsNotifier(repository);

      await notifier.initialize();
      await notifier.runLaunchCleanupIfNeeded();

      expect(repository.tasks, isEmpty);
    });

    test('persists the opt-in', () async {
      final notifier = SettingsNotifier(FakeTaskRepository());
      await notifier.initialize();

      await notifier.setAutoCleanupEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.auto_cleanup_enabled'), isTrue);
    });
  });

  testWidgets('Clean now asks for confirmation and keeps data on cancel', (tester) async {
    final repository = _repositoryWithOldCompletedTask();
    final container = ProviderContainer(overrides: [taskRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(settingsNotifierProvider.notifier).initialize();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.tap(find.text('Clean now'));
    await tester.pumpAndSettle();

    expect(find.text('Delete old tasks?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.tasks, hasLength(1));

    await tester.tap(find.text('Clean now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.tasks, isEmpty);
  });
}
