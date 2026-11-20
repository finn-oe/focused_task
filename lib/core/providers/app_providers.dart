import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/core/services/target_alarm.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/calendar/presentation/calendar_notifier.dart';
import 'package:focused_task/features/categories/data/category_repository_impl.dart';
import 'package:focused_task/features/categories/domain/i_category_repository.dart';
import 'package:focused_task/features/categories/presentation/categories_notifier.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/inbox/data/inbox_repository_impl.dart';
import 'package:focused_task/features/inbox/domain/i_inbox_repository.dart';
import 'package:focused_task/features/inbox/domain/inbox_item.dart';
import 'package:focused_task/features/inbox/presentation/inbox_notifier.dart';
import 'package:focused_task/features/recurrence/data/recurrence_repository_impl.dart';
import 'package:focused_task/features/recurrence/domain/i_recurrence_repository.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/reminders/presentation/reminders_notifier.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart';
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';
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

/// System notifications. Overridden in `main()` with an initialized instance; uninitialized it does nothing.
final notificationServiceProvider = Provider<NotificationService>((ref) => createNotificationService());

/// Target-duration alarm. Overridden in `main()` with an initialized instance, and with fakes in tests.
final targetAlarmProvider = Provider<TargetAlarm>((ref) => createTargetAlarm(notifications: ref.watch(notificationServiceProvider)));

final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(appDatabaseProvider));
});

final focusSessionRepositoryProvider = Provider<IFocusSessionRepository>((ref) {
  return FocusSessionRepositoryImpl(ref.watch(appDatabaseProvider));
});

final categoryRepositoryProvider = Provider<ICategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Recurring tasks (#24).
final recurrenceRepositoryProvider = Provider<IRecurrenceRepository>((ref) {
  return RecurrenceRepositoryImpl(ref.watch(appDatabaseProvider));
});

final inboxRepositoryProvider = Provider<IInboxRepository>((ref) {
  return InboxRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Parked thoughts waiting for review (#28), and what to do with them.
final inboxNotifierProvider = NotifierProvider<InboxNotifier, InboxState>(InboxNotifier.new);

/// The most recent thoughts parked in a period (for the statistics), newest first.
final recentParkedThoughtsProvider = StreamProvider.autoDispose.family<List<InboxItem>, DateRange>((ref, range) {
  return ref.watch(inboxRepositoryProvider).watchInboxItemsCreated(range.start, range.end.nextDay);
});

/// All task categories (#2), also archived ones, and the actions to manage them.
final categoriesNotifierProvider = NotifierProvider<CategoriesNotifier, CategoriesState>(CategoriesNotifier.new);

final planModeNotifierProvider = NotifierProvider<PlanModeNotifier, PlanModeState>(PlanModeNotifier.new);

final focusModeNotifierProvider = NotifierProvider<FocusModeNotifier, FocusModeState>(FocusModeNotifier.new);

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// One-off work on app launch (currently the optional cleanup of old tasks). Watched once by the app root.
///
/// A failed cleanup is shown in the settings screen (`lastCleanup`) and is not retried, so it can't delete repeatedly.
final appStartupProvider = FutureProvider<void>((ref) async {
  // Providers must not modify other providers synchronously while they initialize.
  await Future<void>.value();
  await ref.read(settingsNotifierProvider.notifier).runLaunchCleanupIfNeeded();
}, retry: (_, _) => null);

/// Tasks and day summaries of the days the calendar shows (an inclusive date range).
final calendarProvider = NotifierProvider.autoDispose.family<CalendarNotifier, CalendarState, DateRange>(CalendarNotifier.new);

/// Statistics for a [StatsQuery]. Recomputed whenever a session in the range (or, with the in-memory fake, any task)
/// changes, so the screen stays current while focus mode runs in another tab.
final statsReportProvider = StreamProvider.autoDispose.family<StatsReport, StatsQuery>((ref, query) {
  final tasks = ref.watch(taskRepositoryProvider);
  final sessions = ref.watch(focusSessionRepositoryProvider);
  return sessions.watchInRange(query.range.start, query.range.end.nextDay).asyncMap((_) => tasks.getStatsReport(query));
});

/// The daily focus goal from the settings.
final focusGoalProvider = Provider<FocusGoal>((ref) => ref.watch(settingsNotifierProvider.select((settings) => settings.focusGoal)));

/// Whether the plan collapses completed tasks into their own section (#58).
final collapseCompletedProvider = Provider<bool>((ref) => ref.watch(settingsNotifierProvider.select((settings) => settings.collapseCompleted)));

/// Task, daily planning and inactivity reminder settings (#10).
final reminderSettingsProvider = Provider<ReminderSettings>((ref) => ref.watch(settingsNotifierProvider.select((settings) => settings.reminders)));

/// Open tasks whose deadline has passed (#10), earliest deadline first. Evaluated when a scheduled task changes.
final overdueTasksProvider = StreamProvider.autoDispose<List<TaskEntity>>((ref) {
  final dueMinute = ref.watch(reminderSettingsProvider.select((settings) => settings.defaultDueMinute));
  return ref.watch(taskRepositoryProvider).watchScheduledOpenTasks().map((tasks) {
    final now = clock.now();
    DateTime due(TaskEntity task) => task.schedule.dueAt(defaultDueMinute: dueMinute)!;
    return tasks.where((task) => task.isOverdueAt(now, defaultDueMinute: dueMinute)).toList()..sort((a, b) => due(a).compareTo(due(b)));
  });
});

/// Keeps task, daily planning and inactivity reminders scheduled (#10). Listened to by the app root.
final remindersNotifierProvider = NotifierProvider<RemindersNotifier, RemindersState>(RemindersNotifier.new);

/// The work/break cycle settings (#27).
final intervalSettingsProvider = Provider<IntervalSettings>((ref) => ref.watch(settingsNotifierProvider.select((settings) => settings.intervals)));

/// No session is older than this; the start of the whole session log for [goalStatusProvider].
final _historyStart = DateTime(2000);

/// Today's goal progress and the streaks, from the whole session log (split at local midnight like the statistics).
/// Recomputed whenever a session changes, so the progress ring moves while focus mode runs.
final goalStatusProvider = StreamProvider.autoDispose<GoalStatus>((ref) {
  final goal = ref.watch(focusGoalProvider);
  final sessions = ref.watch(focusSessionRepositoryProvider);
  // Open-ended, so the provider stays correct after midnight.
  return sessions.watchInRange(_historyStart, DateTime(9999)).map((all) {
    final today = clock.now().dateOnly;
    return GoalStatus.from(focusTimeByDay(all, DateRange(_historyStart, today)), goal, today);
  });
});

/// Period selected on the statistics screen.
final statsPeriodProvider = NotifierProvider.autoDispose<StatsPeriodNotifier, StatsPeriod>(StatsPeriodNotifier.new);

/// Strings for code outside the widget tree (e.g. alarm notifications), in the language the app shows.
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final chosen = ref.watch(settingsNotifierProvider.select((settings) => settings.locale));
  return lookupAppLocalizations(chosen ?? systemAppLocale());
});
