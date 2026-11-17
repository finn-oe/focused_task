import 'package:material_ui/material_ui.dart';

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.autoCleanupEnabled,
    required this.retentionDays,
    required this.pauseOnBackground,
    required this.enableWakelock,
    required this.isCleaning,
    this.lastCleanupMessage,
  });

  final ThemeMode themeMode;

  /// Whether completed tasks older than [retentionDays] are deleted on launch. Off by default because
  /// deleted tasks also disappear from the statistics.
  final bool autoCleanupEnabled;
  final int retentionDays;
  final bool pauseOnBackground;
  final bool enableWakelock;
  final bool isCleaning;
  final String? lastCleanupMessage;

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? autoCleanupEnabled,
    int? retentionDays,
    bool? pauseOnBackground,
    bool? enableWakelock,
    bool? isCleaning,
    String? lastCleanupMessage,
    bool clearCleanupMessage = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoCleanupEnabled: autoCleanupEnabled ?? this.autoCleanupEnabled,
      retentionDays: retentionDays ?? this.retentionDays,
      pauseOnBackground: pauseOnBackground ?? this.pauseOnBackground,
      enableWakelock: enableWakelock ?? this.enableWakelock,
      isCleaning: isCleaning ?? this.isCleaning,
      lastCleanupMessage: clearCleanupMessage ? null : lastCleanupMessage ?? this.lastCleanupMessage,
    );
  }
}
