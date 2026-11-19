import 'package:material_ui/material_ui.dart';

/// Outcome of the last cleanup run; the screen turns it into a localized message.
class CleanupResult {
  const CleanupResult.deleted(int this.deletedCount);
  const CleanupResult.failed() : deletedCount = null;

  /// Number of deleted tasks, or `null` if the cleanup failed.
  final int? deletedCount;

  bool get failed => deletedCount == null;
}

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.autoCleanupEnabled,
    required this.retentionDays,
    required this.pauseOnBackground,
    required this.enableWakelock,
    required this.isCleaning,
    this.askToMoveUnfinished = true,
    this.notificationsDenied = false,
    this.locale,
    this.lastCleanup,
  });

  final ThemeMode themeMode;

  /// Language chosen in the settings, or `null` to follow the system language.
  final Locale? locale;

  /// Whether completed tasks older than [retentionDays] are deleted on launch. Off by default because
  /// deleted tasks also disappear from the statistics.
  final bool autoCleanupEnabled;
  final int retentionDays;
  final bool pauseOnBackground;
  final bool enableWakelock;
  final bool isCleaning;
  final CleanupResult? lastCleanup;

  /// On the first start of a day, offer to move the open tasks of the last days to today.
  final bool askToMoveUnfinished;

  /// The user declined notifications when asked; the settings show a hint.
  final bool notificationsDenied;

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? autoCleanupEnabled,
    int? retentionDays,
    bool? pauseOnBackground,
    bool? enableWakelock,
    bool? isCleaning,
    CleanupResult? lastCleanup,
    bool clearLastCleanup = false,
    bool? askToMoveUnfinished,
    bool? notificationsDenied,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : locale ?? this.locale,
      autoCleanupEnabled: autoCleanupEnabled ?? this.autoCleanupEnabled,
      retentionDays: retentionDays ?? this.retentionDays,
      pauseOnBackground: pauseOnBackground ?? this.pauseOnBackground,
      enableWakelock: enableWakelock ?? this.enableWakelock,
      isCleaning: isCleaning ?? this.isCleaning,
      lastCleanup: clearLastCleanup ? null : lastCleanup ?? this.lastCleanup,
      askToMoveUnfinished: askToMoveUnfinished ?? this.askToMoveUnfinished,
      notificationsDenied: notificationsDenied ?? this.notificationsDenied,
    );
  }
}
