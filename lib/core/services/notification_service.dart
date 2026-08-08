import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static const int _alarmId = 8675309; // Fixed ID so we can cancel it easily

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Tapping the notification automatically launches/resumes the app.
        // We can cancel the looping notification immediately upon tap.
        cancelAlarm();
      },
    );
  }

  static Future<void> requestPermissions() async {
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleAlarm({required String taskTitle, required DateTime scheduledDate}) async {
    final androidDetails = AndroidNotificationDetails(
      'focus_alarm_channel', // Channel ID
      'Focus Alarms', // Channel Name
      channelDescription: 'Rings when a task timer is up',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alarm'), // Refers to res/raw/alarm.mp3
      additionalFlags: Int32List.fromList([4]), // 4 = FLAG_INSISTENT (Loops sound)
      fullScreenIntent: true,
    );

    final details = NotificationDetails(android: androidDetails);

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
