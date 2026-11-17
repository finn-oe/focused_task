import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/services/target_alarm.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/features/settings/presentation/settings_notifier.dart';
import 'package:focused_task/features/settings/presentation/settings_state.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_range.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Loaded once in `main()` before `runApp` (and in tests), so settings are available synchronously on the first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden with an instance loaded before runApp.');
});

/// Target-duration alarm. Overridden in `main()` with an initialized instance, and with fakes in tests.
final targetAlarmProvider = Provider<TargetAlarm>((ref) => createTargetAlarm());

final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(appDatabaseProvider));
});

final planModeNotifierProvider = NotifierProvider<PlanModeNotifier, PlanModeState>(PlanModeNotifier.new);

final focusModeNotifierProvider = NotifierProvider<FocusModeNotifier, FocusModeState>(FocusModeNotifier.new);

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// One-off work on app launch (currently the optional cleanup of old tasks). Watched once by the app root.
///
/// A failed cleanup is shown in the settings screen (`lastCleanupMessage`) and is not retried, so it can't delete repeatedly.
final appStartupProvider = FutureProvider<void>((ref) async {
  // Providers must not modify other providers synchronously while they initialize.
  await Future<void>.value();
  await ref.read(settingsNotifierProvider.notifier).runLaunchCleanupIfNeeded();
}, retry: (_, _) => null);

/// Statistics for an inclusive calendar-date range.
final taskStatsProvider = FutureProvider.autoDispose.family<TaskStats, DateRange>((ref, range) {
  return ref.watch(taskRepositoryProvider).getTaskStats(start: range.start, end: range.end);
});

/// Period selected on the statistics screen.
final statsRangeProvider = NotifierProvider.autoDispose<StatsRangeNotifier, StatsRange>(StatsRangeNotifier.new);
