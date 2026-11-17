import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:focused_task/core/l10n/l10n.dart';

/// Kind of notification; on Android each is a channel the user can configure.
enum NotificationChannel { focusAlarm, reminders, breaks }

/// All notification ids in one place, so features never collide.
abstract final class NotificationIds {
  static const focusAlarm = 1;
  static const test = 2;
}

/// A system notification. Texts are already localized.
class AppNotification {
  const AppNotification({required this.id, required this.channel, required this.title, required this.body});

  final int id;
  final NotificationChannel channel;
  final String title;
  final String body;
}

/// System notifications on every platform.
abstract interface class NotificationService {
  Future<void> init();

  /// Asks the user for permission where the platform requires it (Android 13+, iOS, macOS, web). Returns whether
  /// notifications may be shown.
  Future<bool> requestPermission();

  Future<void> show(AppNotification notification);

  /// Shows [notification] at [at]. Where the platform can't schedule (web, Linux), it is shown while the app runs.
  Future<void> schedule(AppNotification notification, DateTime at);

  Future<void> cancel(int id);
}

NotificationService createNotificationService() => LocalNotificationService(FlutterLocalNotificationsPlugin());

/// [NotificationService] backed by `flutter_local_notifications`. Until [init] succeeded every call is a no-op, so a
/// platform without notifications degrades gracefully.
class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final Map<int, Timer> _inAppTimers = {};
  bool _ready = false;

  /// Fixed identity of the app for Windows toast notifications.
  static const _windowsGuid = '6f1c5a0e-6d2b-4c4e-9a52-3d8f2b7e41a9';

  static bool get _canSchedule => !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

  @override
  Future<void> init() async {
    try {
      await _initTimeZone();
      final l10n = lookupAppLocalizations(systemAppLocale());
      const darwin = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: darwin,
          macOS: darwin,
          linux: LinuxInitializationSettings(defaultActionName: l10n.notificationOpenAction),
          windows: const WindowsInitializationSettings(appName: 'Focused Task', appUserModelId: 'TechReload.FocusedTask', guid: _windowsGuid),
          web: const WebInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Notifications are not available: $error');
    }
  }

  /// One-off notifications only need the right instant; the local zone matters for repeating ones later.
  static Future<void> _initTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (kIsWeb) {
        return await _plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
      }
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false,
        TargetPlatform.iOS => await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true) ?? false,
        TargetPlatform.macOS => await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true) ?? false,
        _ => true, // Windows and Linux don't ask.
      };
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  NotificationDetails _details(NotificationChannel channel) {
    final l10n = lookupAppLocalizations(systemAppLocale());
    final (name, importance) = switch (channel) {
      NotificationChannel.focusAlarm => (l10n.notificationChannelFocusAlarm, Importance.high),
      NotificationChannel.reminders => (l10n.notificationChannelReminders, Importance.defaultImportance),
      NotificationChannel.breaks => (l10n.notificationChannelBreaks, Importance.high),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(channel.name, name, importance: importance, priority: importance == Importance.high ? Priority.high : Priority.defaultPriority),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (!_ready) return;
    try {
      await _plugin.show(id: notification.id, title: notification.title, body: notification.body, notificationDetails: _details(notification.channel));
    } catch (error) {
      debugPrint('Showing a notification failed: $error');
    }
  }

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {
    if (!_ready) return;
    await cancel(notification.id);
    if (!_canSchedule) {
      final delay = at.difference(clock.now());
      _inAppTimers[notification.id] = Timer(delay.isNegative ? Duration.zero : delay, () {
        _inAppTimers.remove(notification.id);
        unawaited(show(notification));
      });
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details(notification.channel),
        // Inexact needs no extra permission; the focus alarm itself rings through `TargetAlarm`.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('Scheduling a notification failed: $error');
    }
  }

  @override
  Future<void> cancel(int id) async {
    _inAppTimers.remove(id)?.cancel();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('Cancelling a notification failed: $error');
    }
  }
}
