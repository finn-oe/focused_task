import 'package:material_ui/material_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/features/settings/presentation/settings_state.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _themeModeKey = 'settings.theme_mode';
  static const String _localeKey = 'settings.locale';
  static const String _notificationsAskedKey = 'settings.notifications_asked';
  static const String _notificationsDeniedKey = 'settings.notifications_denied';
  static const String _autoCleanupEnabledKey = 'settings.auto_cleanup_enabled';
  static const String _retentionDaysKey = 'settings.retention_days';
  static const String _pauseOnBackgroundKey = 'settings.pause_on_background';
  static const String _enableWakelockKey = 'settings.enable_wakelock';
  static const String _askToMoveUnfinishedKey = 'settings.ask_to_move_unfinished';

  late SharedPreferences _prefs;
  late ITaskRepository _repository;
  late NotificationService _notifications;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _repository = ref.watch(taskRepositoryProvider);
    _notifications = ref.watch(notificationServiceProvider);

    final prefs = _prefs;
    final themeModeRaw = prefs.getString(_themeModeKey);
    final autoCleanupEnabled = prefs.getBool(_autoCleanupEnabledKey) ?? false;
    final retentionDays = prefs.getInt(_retentionDaysKey) ?? 30;
    final pauseOnBackground = prefs.getBool(_pauseOnBackgroundKey) ?? true;
    final enableWakelock = prefs.getBool(_enableWakelockKey) ?? false;

    return SettingsState(
      themeMode: _parseThemeMode(themeModeRaw),
      locale: _parseLocale(prefs.getString(_localeKey)),
      autoCleanupEnabled: autoCleanupEnabled,
      retentionDays: retentionDays < 1 ? 1 : retentionDays,
      pauseOnBackground: pauseOnBackground,
      enableWakelock: enableWakelock,
      isCleaning: false,
      askToMoveUnfinished: prefs.getBool(_askToMoveUnfinishedKey) ?? true,
      notificationsDenied: prefs.getBool(_notificationsDeniedKey) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  /// Sets the app language; `null` follows the system language.
  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_localeKey);
      state = state.copyWith(clearLocale: true);
    } else {
      await _prefs.setString(_localeKey, locale.toLanguageTag());
      state = state.copyWith(locale: locale);
    }
  }

  /// Asks for notification permission the first time a feature needs it (e.g. entering focus mode). Never asks twice;
  /// after a refusal the settings offer to ask again.
  Future<void> ensureNotificationPermission() async {
    if (_prefs.getBool(_notificationsAskedKey) ?? false) return;
    await _prefs.setBool(_notificationsAskedKey, true);
    await requestNotificationPermission();
  }

  /// Asks for notification permission now and remembers whether it was refused.
  Future<bool> requestNotificationPermission() async {
    final granted = await _notifications.requestPermission();
    await _prefs.setBool(_notificationsDeniedKey, !granted);
    state = state.copyWith(notificationsDenied: !granted);
    return granted;
  }

  /// Schedules a notification in [delay], so the user can check that notifications arrive in the background.
  Future<void> sendTestNotification({Duration delay = const Duration(seconds: 10)}) async {
    if (!await requestNotificationPermission()) return;
    final l10n = ref.read(appLocalizationsProvider);
    final notification = AppNotification(id: NotificationIds.test, channel: NotificationChannel.reminders, title: l10n.appTitle, body: l10n.notificationTestBody);
    await _notifications.schedule(notification, clock.now().add(delay));
  }

  Future<void> setAutoCleanupEnabled(bool value) async {
    await _prefs.setBool(_autoCleanupEnabledKey, value);
    state = state.copyWith(autoCleanupEnabled: value);
  }

  /// Number of tasks [cleanNow] would delete with the current retention period.
  Future<int> countCleanupCandidates() => _repository.countCompletedTasksOlderThanDays(state.retentionDays);

  Future<void> setRetentionDays(int days) async {
    final clamped = days < 1 ? 1 : days;
    await _prefs.setInt(_retentionDaysKey, clamped);
    state = state.copyWith(retentionDays: clamped);
  }

  Future<void> setPauseOnBackground(bool value) async {
    await _prefs.setBool(_pauseOnBackgroundKey, value);
    state = state.copyWith(pauseOnBackground: value);
  }

  Future<void> setEnableWakelock(bool value) async {
    await _prefs.setBool(_enableWakelockKey, value);
    state = state.copyWith(enableWakelock: value);
  }

  Future<void> setAskToMoveUnfinished(bool value) async {
    await _prefs.setBool(_askToMoveUnfinishedKey, value);
    state = state.copyWith(askToMoveUnfinished: value);
  }

  Future<int> cleanNow() async {
    state = state.copyWith(isCleaning: true, clearLastCleanup: true);

    try {
      final deleted = await _repository.deleteCompletedTasksOlderThanDays(state.retentionDays);
      state = state.copyWith(isCleaning: false, lastCleanup: CleanupResult.deleted(deleted));
      return deleted;
    } catch (_) {
      state = state.copyWith(isCleaning: false, lastCleanup: const CleanupResult.failed());
      rethrow;
    }
  }

  Future<void> runLaunchCleanupIfNeeded() async {
    if (!state.autoCleanupEnabled) {
      return;
    }

    await cleanNow();
  }

  /// Only supported languages are restored; anything else falls back to the system language.
  Locale? _parseLocale(String? raw) {
    if (raw == null) return null;
    final locale = Locale(raw.split('-').first);
    return AppLocalizations.supportedLocales.contains(locale) ? locale : null;
  }

  ThemeMode _parseThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
