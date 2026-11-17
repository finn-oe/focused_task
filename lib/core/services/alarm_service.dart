import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';

class AlarmService {
  static final _windowsPlayer = AudioPlayer();
  static const int _alarmId = 8675309;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Initialize the required plugins based on platform.
  static Future<void> init() async {
    if (_isMobile) {
      await Alarm.init();
    }
  }

  /// Schedules an alarm for the given [scheduledDate].
  static Future<void> scheduleAlarm({required String taskTitle, required DateTime scheduledDate}) async {
    final now = DateTime.now();
    final safeDate = scheduledDate.isBefore(now) ? now.add(const Duration(milliseconds: 500)) : scheduledDate;

    if (_isMobile) {
      final alarmSettings = AlarmSettings(
        id: _alarmId,
        dateTime: safeDate,
        assetAudioPath: 'assets/sounds/alarm_looped.mp3',
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: Platform.isIOS,
        androidFullScreenIntent: true,
        volumeSettings: const VolumeSettings.fixed(volume: null, volumeEnforced: false),

        notificationSettings: NotificationSettings(title: 'Time is up!', body: 'You have reached your target duration for: $taskTitle', stopButton: 'Stop Alarm'),
      );

      await Alarm.set(alarmSettings: alarmSettings);
    } else if (_isDesktop) {
      final delay = safeDate.difference(DateTime.now());
      if (delay.isNegative) return;

      Future.delayed(delay, () async {
        _windowsPlayer.setReleaseMode(ReleaseMode.loop);
        await _windowsPlayer.play(AssetSource('sounds/alarm_looped.mp3'));
      });
    }
  }

  /// Cancels a scheduled alarm or stops it if it is currently ringing.
  static Future<void> cancelAlarm() async {
    if (_isMobile) {
      await Alarm.stop(_alarmId);
    } else if (_isDesktop) {
      await _windowsPlayer.stop();
    }
  }
}
