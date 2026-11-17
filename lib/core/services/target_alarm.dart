import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// Rings when a task reaches its target duration, also while the app is in the background.
///
/// At most one alarm is pending at a time: scheduling replaces the previous alarm.
abstract interface class TargetAlarm {
  Future<void> init();

  /// Schedules the alarm for [at], replacing any pending alarm. Times in the past ring immediately.
  Future<void> schedule({required String taskTitle, required DateTime at});

  /// Cancels a pending alarm and stops it if it is ringing.
  Future<void> cancel();
}

/// Picks the implementation for the current platform without touching `dart:io`, so it also works on web.
TargetAlarm createTargetAlarm() {
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    return NativeTargetAlarm();
  }
  return TimerTargetAlarm.withPlayer(AudioPlayer());
}

/// Android / iOS: uses the OS alarm so it rings even when the app is suspended.
class NativeTargetAlarm implements TargetAlarm {
  static const int _alarmId = 8675309;

  @override
  Future<void> init() => Alarm.init();

  @override
  Future<void> schedule({required String taskTitle, required DateTime at}) async {
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
        notificationSettings: NotificationSettings(title: 'Time is up!', body: 'You have reached your target duration for: $taskTitle', stopButton: 'Stop Alarm'),
      ),
    );
  }

  @override
  Future<void> cancel() => Alarm.stop(_alarmId);
}

/// Desktop / web: a cancellable in-process timer that plays a looping sound.
class TimerTargetAlarm implements TargetAlarm {
  TimerTargetAlarm({required this._ring, required this._stop});

  /// Plays the looping alarm sound with [player].
  factory TimerTargetAlarm.withPlayer(AudioPlayer player) {
    return TimerTargetAlarm(
      ring: () async {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource('sounds/alarm_looped.mp3'));
      },
      stop: player.stop,
    );
  }

  final Future<void> Function() _ring;
  final Future<void> Function() _stop;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule({required String taskTitle, required DateTime at}) async {
    _timer?.cancel();
    final delay = at.difference(clock.now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _ring);
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    await _stop();
  }
}
