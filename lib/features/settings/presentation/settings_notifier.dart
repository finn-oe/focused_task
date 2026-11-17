import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/settings/presentation/settings_state.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _themeModeKey = 'settings.theme_mode';
  static const String _autoCleanupEnabledKey = 'settings.auto_cleanup_enabled';
  static const String _retentionDaysKey = 'settings.retention_days';
  static const String _pauseOnBackgroundKey = 'settings.pause_on_background';
  static const String _enableWakelockKey = 'settings.enable_wakelock';

  late SharedPreferences _prefs;
  late ITaskRepository _repository;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _repository = ref.watch(taskRepositoryProvider);

    final prefs = _prefs;
    final themeModeRaw = prefs.getString(_themeModeKey);
    final autoCleanupEnabled = prefs.getBool(_autoCleanupEnabledKey) ?? false;
    final retentionDays = prefs.getInt(_retentionDaysKey) ?? 30;
    final pauseOnBackground = prefs.getBool(_pauseOnBackgroundKey) ?? true;
    final enableWakelock = prefs.getBool(_enableWakelockKey) ?? false;

    return SettingsState(
      themeMode: _parseThemeMode(themeModeRaw),
      autoCleanupEnabled: autoCleanupEnabled,
      retentionDays: retentionDays < 1 ? 1 : retentionDays,
      pauseOnBackground: pauseOnBackground,
      enableWakelock: enableWakelock,
      isCleaning: false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    state = state.copyWith(themeMode: mode);
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

  Future<int> cleanNow() async {
    state = state.copyWith(isCleaning: true, clearCleanupMessage: true);

    try {
      final deleted = await _repository.deleteCompletedTasksOlderThanDays(state.retentionDays);
      state = state.copyWith(isCleaning: false, lastCleanupMessage: 'Deleted $deleted entries.');
      return deleted;
    } catch (_) {
      state = state.copyWith(isCleaning: false, lastCleanupMessage: 'Cleanup failed. Please try again.');
      rethrow;
    }
  }

  Future<void> runLaunchCleanupIfNeeded() async {
    if (!state.autoCleanupEnabled) {
      return;
    }

    await cleanNow();
  }

  ThemeMode _parseThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
