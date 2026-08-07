import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/features/settings/presentation/settings_state.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._repository) : super(SettingsState.initial());

  static const String _themeModeKey = 'settings.theme_mode';
  static const String _retentionDaysKey = 'settings.retention_days';

  final ITaskRepository _repository;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeRaw = prefs.getString(_themeModeKey);
    final retentionDays = prefs.getInt(_retentionDaysKey) ?? 30;

    state = state.copyWith(themeMode: _parseThemeMode(themeModeRaw), retentionDays: retentionDays < 1 ? 1 : retentionDays, isLoading: false);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setRetentionDays(int days) async {
    final clamped = days < 1 ? 1 : days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_retentionDaysKey, clamped);
    state = state.copyWith(retentionDays: clamped);
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
    if (state.isLoading) {
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
