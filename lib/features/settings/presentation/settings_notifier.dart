import 'package:material_ui/material_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
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
  static const String _dailyGoalMinutesKey = 'settings.daily_goal_minutes';
  static const String _workingDaysKey = 'settings.working_days';
  static const String _intervalsEnabledKey = 'settings.intervals_enabled';
  static const String _intervalWorkMinutesKey = 'settings.interval_work_minutes';
  static const String _intervalShortBreakMinutesKey = 'settings.interval_short_break_minutes';
  static const String _intervalLongBreakMinutesKey = 'settings.interval_long_break_minutes';
  static const String _intervalLongBreakEveryKey = 'settings.interval_long_break_every';
  static const String _intervalAutoStartKey = 'settings.interval_auto_start';
  static const String _focusMinimalLayoutKey = 'settings.focus_minimal_layout';
  static const String _collapseCompletedKey = 'settings.collapse_completed';
  static const String _taskRemindersKey = 'settings.task_reminders';
  static const String _reminderLeadMinutesKey = 'settings.reminder_lead_minutes';
  static const String _defaultDueMinuteKey = 'settings.default_due_minute';
  static const String _dailyPlanningKey = 'settings.daily_planning';
  static const String _dailyPlanningMinuteKey = 'settings.daily_planning_minute';
  static const String _inactivityKey = 'settings.inactivity_reminder';
  static const String _workStartMinuteKey = 'settings.work_start_minute';
  static const String _workEndMinuteKey = 'settings.work_end_minute';
  static const String _idleMinutesKey = 'settings.idle_minutes';

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
      focusGoal: _loadFocusGoal(prefs),
      intervals: _loadIntervals(prefs),
      focusMinimalLayout: prefs.getBool(_focusMinimalLayoutKey) ?? false,
      collapseCompleted: prefs.getBool(_collapseCompletedKey) ?? false,
      reminders: _loadReminders(prefs),
    );
  }

  static ReminderSettings _loadReminders(SharedPreferences prefs) {
    int minuteOfDay(String key, int fallback) {
      final value = prefs.getInt(key);
      return value == null || value < 0 || value >= 24 * 60 ? fallback : value;
    }

    Duration minutes(String key, Duration fallback) {
      final value = prefs.getInt(key);
      return value == null || value < 1 ? fallback : Duration(minutes: value);
    }

    return ReminderSettings(
      taskReminders: prefs.getBool(_taskRemindersKey) ?? true,
      defaultLead: minutes(_reminderLeadMinutesKey, ReminderSettings.defaultLeadTime),
      defaultDueMinute: minuteOfDay(_defaultDueMinuteKey, ReminderSettings.defaultDueTime),
      dailyPlanning: prefs.getBool(_dailyPlanningKey) ?? false,
      dailyPlanningMinute: minuteOfDay(_dailyPlanningMinuteKey, ReminderSettings.defaultDailyPlanningTime),
      inactivity: prefs.getBool(_inactivityKey) ?? false,
      workStartMinute: minuteOfDay(_workStartMinuteKey, ReminderSettings.defaultWorkStart),
      workEndMinute: minuteOfDay(_workEndMinuteKey, ReminderSettings.defaultWorkEnd),
      idle: minutes(_idleMinutesKey, ReminderSettings.defaultIdle),
    );
  }

  /// Changes the reminder settings (#10). Turning on a reminder type asks for notification permission the first time.
  Future<void> setReminders(ReminderSettings reminders) async {
    final before = state.reminders;
    await _prefs.setBool(_taskRemindersKey, reminders.taskReminders);
    await _prefs.setInt(_reminderLeadMinutesKey, reminders.defaultLead.inMinutes);
    await _prefs.setInt(_defaultDueMinuteKey, reminders.defaultDueMinute);
    await _prefs.setBool(_dailyPlanningKey, reminders.dailyPlanning);
    await _prefs.setInt(_dailyPlanningMinuteKey, reminders.dailyPlanningMinute);
    await _prefs.setBool(_inactivityKey, reminders.inactivity);
    await _prefs.setInt(_workStartMinuteKey, reminders.workStartMinute);
    await _prefs.setInt(_workEndMinuteKey, reminders.workEndMinute);
    await _prefs.setInt(_idleMinutesKey, reminders.idle.inMinutes);
    state = state.copyWith(reminders: reminders);
    final turnedOn = (reminders.dailyPlanning && !before.dailyPlanning) || (reminders.inactivity && !before.inactivity) || (reminders.taskReminders && !before.taskReminders);
    if (turnedOn) await ensureNotificationPermission();
  }

  static FocusGoal _loadFocusGoal(SharedPreferences prefs) {
    final minutes = prefs.getInt(_dailyGoalMinutesKey) ?? 0;
    final stored = prefs.getStringList(_workingDaysKey)?.map(int.tryParse).whereType<int>().where((day) => day >= DateTime.monday && day <= DateTime.sunday).toSet();
    return FocusGoal(
      daily: minutes > 0 ? Duration(minutes: minutes) : null,
      workingDays: stored == null || stored.isEmpty ? FocusGoal.defaultWorkingDays : stored,
    );
  }

  static IntervalSettings _loadIntervals(SharedPreferences prefs) {
    Duration minutes(String key, Duration fallback) {
      final value = prefs.getInt(key);
      return value == null || value < 1 ? fallback : Duration(minutes: value);
    }

    final every = prefs.getInt(_intervalLongBreakEveryKey);
    return IntervalSettings(
      isEnabled: prefs.getBool(_intervalsEnabledKey) ?? false,
      work: minutes(_intervalWorkMinutesKey, IntervalSettings.defaultWork),
      shortBreak: minutes(_intervalShortBreakMinutesKey, IntervalSettings.defaultShortBreak),
      longBreak: minutes(_intervalLongBreakMinutesKey, IntervalSettings.defaultLongBreak),
      longBreakEvery: every == null || every < 1 ? IntervalSettings.defaultLongBreakEvery : every,
      autoStart: prefs.getBool(_intervalAutoStartKey) ?? false,
    );
  }

  /// Changes the work/break cycle settings. A running focus session keeps the cycle it started with.
  Future<void> setIntervals(IntervalSettings intervals) async {
    await _prefs.setBool(_intervalsEnabledKey, intervals.isEnabled);
    await _prefs.setInt(_intervalWorkMinutesKey, intervals.work.inMinutes);
    await _prefs.setInt(_intervalShortBreakMinutesKey, intervals.shortBreak.inMinutes);
    await _prefs.setInt(_intervalLongBreakMinutesKey, intervals.longBreak.inMinutes);
    await _prefs.setInt(_intervalLongBreakEveryKey, intervals.longBreakEvery);
    await _prefs.setBool(_intervalAutoStartKey, intervals.autoStart);
    state = state.copyWith(intervals: intervals);
  }

  /// Sets the daily focus goal; `null` turns it off.
  Future<void> setDailyGoal(Duration? goal) async {
    final minutes = goal?.inMinutes ?? 0;
    if (minutes > 0) {
      await _prefs.setInt(_dailyGoalMinutesKey, minutes);
    } else {
      await _prefs.remove(_dailyGoalMinutesKey);
    }
    state = state.copyWith(
      focusGoal: FocusGoal(
        daily: minutes > 0 ? Duration(minutes: minutes) : null,
        workingDays: state.focusGoal.workingDays,
      ),
    );
  }

  /// Makes [weekday] (a [DateTime.weekday] value) a working day or not. The last working day can't be removed.
  Future<void> setWorkingDay(int weekday, bool isWorkingDay) async {
    final days = {...state.focusGoal.workingDays};
    isWorkingDay ? days.add(weekday) : days.remove(weekday);
    if (days.isEmpty) return;
    await _prefs.setStringList(_workingDaysKey, [for (final day in days.toList()..sort()) '$day']);
    state = state.copyWith(
      focusGoal: FocusGoal(daily: state.focusGoal.daily, workingDays: days),
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

  Future<void> setFocusMinimalLayout(bool value) async {
    await _prefs.setBool(_focusMinimalLayoutKey, value);
    state = state.copyWith(focusMinimalLayout: value);
  }

  Future<void> setCollapseCompleted(bool value) async {
    await _prefs.setBool(_collapseCompletedKey, value);
    state = state.copyWith(collapseCompleted: value);
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
