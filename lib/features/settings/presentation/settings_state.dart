import 'package:flutter/material.dart';

class SettingsState {
  const SettingsState({required this.themeMode, required this.retentionDays, required this.isLoading, required this.isCleaning, this.lastCleanupMessage});

  factory SettingsState.initial() {
    return const SettingsState(themeMode: ThemeMode.system, retentionDays: 30, isLoading: true, isCleaning: false);
  }

  final ThemeMode themeMode;
  final int retentionDays;
  final bool isLoading;
  final bool isCleaning;
  final String? lastCleanupMessage;

  SettingsState copyWith({ThemeMode? themeMode, int? retentionDays, bool? isLoading, bool? isCleaning, String? lastCleanupMessage, bool clearCleanupMessage = false}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      retentionDays: retentionDays ?? this.retentionDays,
      isLoading: isLoading ?? this.isLoading,
      isCleaning: isCleaning ?? this.isCleaning,
      lastCleanupMessage: clearCleanupMessage ? null : lastCleanupMessage ?? this.lastCleanupMessage,
    );
  }
}
