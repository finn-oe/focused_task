import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static const int _alarmId = 8675309;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization
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
    // Android Permissions
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

    // iOS Permissions
    await _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleAlarm({required String taskTitle, required DateTime scheduledDate}) async {
    final androidDetails = AndroidNotificationDetails(
      'focus_alarm_channel',
      'Focus Alarms',
      channelDescription: 'Rings when a task timer is up',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      additionalFlags: Int32List.fromList([4]), // Loops on Android
      fullScreenIntent: true,
    );

    // iOS Details
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
      sound: 'alarm.mp3', // Must match the exact filename in Xcode
      interruptionLevel: InterruptionLevel.timeSensitive, // Helps bypass iOS Focus modes
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
    await _notifications.cancel(_alarmId);
  }
}
