import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/features/settings/presentation/reminders_settings_screen.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';

Future<ProviderContainer> _container(FakeNotificationService notifications, [Map<String, Object> preferences = const {}]) async {
  return ProviderContainer.test(
    overrides: [
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
      sharedPreferencesProvider.overrideWithValue(await fakePreferences(preferences)),
      notificationServiceProvider.overrideWithValue(notifications),
      appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
    ],
  );
}

void main() {
  test('asks for notification permission only once', () async {
    final notifications = FakeNotificationService();
    final container = await _container(notifications);
    final settings = container.read(settingsNotifierProvider.notifier);

    await settings.ensureNotificationPermission();
    await settings.ensureNotificationPermission();

    expect(notifications.permissionRequests, 1);
    expect(container.read(settingsNotifierProvider).notificationsDenied, isFalse);
  });

  test('remembers a refusal so the settings can show a hint', () async {
    final notifications = FakeNotificationService(grantPermission: false);
    final container = await _container(notifications);

    await container.read(settingsNotifierProvider.notifier).ensureNotificationPermission();

    expect(container.read(settingsNotifierProvider).notificationsDenied, isTrue);
    final restarted = await _container(notifications, {'settings.notifications_asked': true, 'settings.notifications_denied': true});
    expect(restarted.read(settingsNotifierProvider).notificationsDenied, isTrue);
  });

  test('the test notification is scheduled in 10 seconds', () async {
    final notifications = FakeNotificationService();
    final container = await _container(notifications);
    final now = DateTime(2026, 11, 17, 9);

    await withClock(Clock.fixed(now), () => container.read(settingsNotifierProvider.notifier).sendTestNotification());

    final (notification, at) = notifications.scheduled[NotificationIds.test]!;
    expect(at, now.add(const Duration(seconds: 10)));
    expect(notification.body, 'Notifications work.');
  });

  testWidgets('settings show a hint after a refusal, and "Ask again" can fix it', (tester) async {
    final notifications = FakeNotificationService(grantPermission: false);
    final container = await _container(notifications, {'settings.notifications_asked': true, 'settings.notifications_denied': true});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const RemindersSettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(find.text('Ask again'), 200);
    expect(find.textContaining('Notifications are turned off'), findsOneWidget);

    notifications.grantPermission = true;
    await tester.ensureVisible(find.text('Ask again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Notifications are turned off'), findsNothing);
  });
}
