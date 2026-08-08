import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static const int _alarmId = 8675309;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<void> init() async {
    if (!_isMobile) return;

    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);

    const settings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        cancelAlarm();
      },
    );
  }

  static Future<void> requestPermissions() async {
    if (!_isMobile) return;

    if (Platform.isAndroid) {
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> scheduleAlarm({required String taskTitle, required DateTime scheduledDate}) async {
    if (!_isMobile) return;

    final androidDetails = AndroidNotificationDetails(
      'focus_alarm_channel',
      'Focus Alarms',
      channelDescription: 'Rings when a task timer is up',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      additionalFlags: Int32List.fromList([4]),
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
      sound: 'alarm_looped.mp3',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      _alarmId,
      'Time is up!',
      'You have reached your target duration for: $taskTitle',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAlarm() async {
    if (!_isMobile) return;
    await _notifications.cancel(_alarmId);
  }
}
