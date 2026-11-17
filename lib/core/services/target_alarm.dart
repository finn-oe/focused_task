import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:focused_task/core/services/notification_service.dart';

/// Localized texts of the alarm's system notification (Android / iOS).
class AlarmNotification {
  const AlarmNotification({required this.title, required this.body, required this.stopButton});

  final String title;
  final String body;
  final String stopButton;
}

/// Rings when a task reaches its target duration, also while the app is in the background.
///
/// At most one alarm is pending at a time: scheduling replaces the previous alarm.
abstract interface class TargetAlarm {
  Future<void> init();

  /// Schedules the alarm for [at], replacing any pending alarm. Times in the past ring immediately.
  Future<void> schedule({required AlarmNotification notification, required DateTime at});

  /// Cancels a pending alarm and stops it if it is ringing.
  Future<void> cancel();
}

/// Picks the implementation for the current platform without touching `dart:io`, so it also works on web.
///
/// On Android/iOS the OS alarm brings its own notification; elsewhere [notifications] shows one when the alarm rings.
TargetAlarm createTargetAlarm({required NotificationService notifications}) {
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    return NativeTargetAlarm();
  }
  return TimerTargetAlarm.withPlayer(AudioPlayer(), notifications: notifications);
}

/// Android / iOS: uses the OS alarm so it rings even when the app is suspended.
class NativeTargetAlarm implements TargetAlarm {
  static const int _alarmId = 8675309;

  @override
  Future<void> init() => Alarm.init();

  @override
  Future<void> schedule({required AlarmNotification notification, required DateTime at}) async {
    final now = DateTime.now();
    final safeAt = at.isAfter(now) ? at : now.add(const Duration(milliseconds: 500));

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: _alarmId,
        dateTime: safeAt,
        assetAudioPath: 'assets/sounds/alarm_looped.mp3',
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: defaultTargetPlatform == TargetPlatform.iOS,
        androidFullScreenIntent: true,
        volumeSettings: const VolumeSettings.fixed(volume: null, volumeEnforced: false),
        notificationSettings: NotificationSettings(title: notification.title, body: notification.body, stopButton: notification.stopButton),
      ),
    );
  }

  @override
  Future<void> cancel() => Alarm.stop(_alarmId);
}

/// Desktop / web: a cancellable in-process timer that plays a looping sound and shows a system notification.
class TimerTargetAlarm implements TargetAlarm {
  TimerTargetAlarm({required this._ring, required this._stop});

  /// Plays the looping alarm sound with [player] and shows the notification through [notifications].
  factory TimerTargetAlarm.withPlayer(AudioPlayer player, {required NotificationService notifications}) {
    return TimerTargetAlarm(
      ring: (notification) async {
        unawaited(notifications.show(AppNotification(id: NotificationIds.focusAlarm, channel: NotificationChannel.focusAlarm, title: notification.title, body: notification.body)));
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource('sounds/alarm_looped.mp3'));
      },
      stop: () async {
        await notifications.cancel(NotificationIds.focusAlarm);
        await player.stop();
      },
    );
  }

  final Future<void> Function(AlarmNotification notification) _ring;
  final Future<void> Function() _stop;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule({required AlarmNotification notification, required DateTime at}) async {
    _timer?.cancel();
    final delay = at.difference(clock.now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () => _ring(notification));
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    await _stop();
  }
}
