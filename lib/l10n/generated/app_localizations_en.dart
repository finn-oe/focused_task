// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Focused Task';

  @override
  String get navPlan => 'Plan';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navStatistics => 'Statistics';

  @override
  String get navSettings => 'Settings';

  @override
  String get calendarComingSoon => 'Week and month views are coming soon.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String commonListItem(String item) {
    return '• $item';
  }

  @override
  String commonMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String get planPickDayTooltip => 'Pick Day';

  @override
  String get planPreviousDay => 'Previous day';

  @override
  String get planNextDay => 'Next day';

  @override
  String get planStartFocus => 'Start focus';

  @override
  String get planNoTasks => 'No tasks for this day.';

  @override
  String planLoadError(String error) {
    return 'Could not load the tasks: $error';
  }

  @override
  String get planAddTask => 'Add Task';

  @override
  String get taskMarkComplete => 'Mark task as complete';

  @override
  String get taskMarkIncomplete => 'Mark task as incomplete';

  @override
  String get taskNoDescription => 'No description';

  @override
  String taskTodoProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get taskCopyToTodayTooltip => 'Copy to Today';

  @override
  String get taskEditTooltip => 'Edit Task';

  @override
  String get taskCopyToTodayTitle => 'Move to Today';

  @override
  String get taskCopyToTodayQuestion => 'Create a copy of this task for today?';

  @override
  String get taskKeepCompletedTodos => 'Keep completed to-dos';

  @override
  String get taskKeepCompletedTodosHint => 'If off, all to-dos will be reset';

  @override
  String get taskSubtractTimeSpent => 'Subtract time spent';

  @override
  String get taskSubtractTimeSpentHint => 'Reduces the new target duration by the time already tracked';

  @override
  String get taskFormAddTitle => 'Add Task';

  @override
  String get taskFormEditTitle => 'Edit Task';

  @override
  String get taskFormDuplicateTooltip => 'Duplicate Task';

  @override
  String get taskFormDeleteTooltip => 'Delete Task';

  @override
  String get taskFormTitleLabel => 'Title';

  @override
  String get taskFormDescriptionLabel => 'Description';

  @override
  String get taskFormSubTasks => 'Sub-tasks';

  @override
  String get taskFormAddSubTaskTooltip => 'Add Sub-task';

  @override
  String get taskFormDeleteSubTaskTooltip => 'Delete sub-task';

  @override
  String get taskFormTrackedTime => 'Tracked time';

  @override
  String get taskFormAddTime => 'Add time';

  @override
  String get taskFormAddTimeTitle => 'Add tracked time';

  @override
  String get taskFormSave => 'Save Task';

  @override
  String get focusTitle => 'Focus Mode';

  @override
  String get focusExitTooltip => 'Exit focus';

  @override
  String get focusTimeIsUp => 'Time is up!';

  @override
  String get focusTargetReached => 'You have reached your target duration for this task.';

  @override
  String get focusStopAlarmAndContinue => 'Stop Alarm & Continue';

  @override
  String get focusNoUnfinishedTasks => 'No unfinished tasks for today.';

  @override
  String get focusCompleteTask => 'Complete Task';

  @override
  String get focusExit => 'Exit Focus';

  @override
  String get focusTimerSession => 'Session';

  @override
  String get focusTimerTask => 'Task';

  @override
  String get focusTimerOverdue => 'Overdue';

  @override
  String get focusTimerRemaining => 'Remaining';

  @override
  String focusAlarmNotificationBody(String taskTitle) {
    return 'You have reached your target duration for: $taskTitle';
  }

  @override
  String get focusAlarmStopButton => 'Stop Alarm';

  @override
  String get pauseTitle => 'Paused';

  @override
  String get pauseMessage => 'Focus paused while app is in background.';

  @override
  String get pauseResume => 'Resume Focus';

  @override
  String get finishedTitle => 'All Done';

  @override
  String get finishedHeadline => 'Finished for Today!';

  @override
  String get finishedMessage => 'Great work — you completed everything planned for today.';

  @override
  String get finishedViewStatistics => 'View Statistics';

  @override
  String get finishedBackToPlan => 'Back to Plan';

  @override
  String get recoveryTitle => 'Recover unfinished session?';

  @override
  String get recoveryClosedWhileFocusing => 'The app was closed while you were focusing on:';

  @override
  String get recoveryQuestion => 'How much of that time do you want to keep?';

  @override
  String get recoveryDiscard => 'Discard';

  @override
  String get recoveryDeletedTask => '(deleted task)';

  @override
  String recoveryUntilNow(String duration) {
    return 'Until now ($duration)';
  }

  @override
  String recoveryUntilLastActivity(String duration) {
    return 'Until last activity ($duration)';
  }

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsDay => 'Day';

  @override
  String get statsWeek => 'Week';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsUnavailable => 'No stats available yet.';

  @override
  String get statsCompletionScore => 'Completion score';

  @override
  String statsCompletionScoreValue(double score) {
    final intl.NumberFormat scoreNumberFormat = intl.NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1);
    final String scoreString = scoreNumberFormat.format(score);

    return '$scoreString%';
  }

  @override
  String statsTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed/$total tasks completed', one: '$completed/1 task completed');
    return '$_temp0';
  }

  @override
  String get statsFocusTime => 'Focus time';

  @override
  String get statsAverageTaskDuration => 'Avg. task duration';

  @override
  String get statsPerDay => 'Per day';

  @override
  String get statsRemaining => 'Remaining';

  @override
  String statsTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks', one: '1 task');
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsDataRetention => 'Data Retention';

  @override
  String get settingsDataRetentionInfo => 'Deleted tasks are removed from your statistics as well. Tasks with an unfinished session are never deleted.';

  @override
  String get settingsAutoCleanup => 'Delete old completed tasks automatically';

  @override
  String settingsAutoCleanupHint(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'On every app start, completed tasks older than $days days are deleted.',
      one: 'On every app start, completed tasks older than 1 day are deleted.',
    );
    return '$_temp0';
  }

  @override
  String settingsRetentionPeriod(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'Retention period: $days days', one: 'Retention period: 1 day');
    return '$_temp0';
  }

  @override
  String get settingsDecrease => 'Decrease';

  @override
  String get settingsIncrease => 'Increase';

  @override
  String get settingsCleanNow => 'Clean now';

  @override
  String settingsNothingToClean(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'No completed tasks older than $days days.', one: 'No completed tasks older than 1 day.');
    return '$_temp0';
  }

  @override
  String settingsCleanupDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Deleted $count tasks.', one: 'Deleted 1 task.', zero: 'Nothing was deleted.');
    return '$_temp0';
  }

  @override
  String get settingsCleanupFailed => 'Cleanup failed. Please try again.';

  @override
  String get settingsCleanupConfirmTitle => 'Delete old tasks?';

  @override
  String settingsCleanupConfirmMessage(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count completed tasks', one: '1 completed task');
    String _temp1 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days days', one: '1 day');
    return '$_temp0 older than $_temp1 will be deleted permanently, including the tracked time in the statistics.';
  }

  @override
  String get settingsFocusMode => 'Focus Mode';

  @override
  String get settingsKeepScreenAwake => 'Keep screen awake';

  @override
  String get settingsKeepScreenAwakeHint => 'Prevents the screen from turning off during an active focus session.';

  @override
  String get settingsPauseOnBackground => 'Pause when minimized or locked';

  @override
  String get settingsPauseOnBackgroundHint => 'Pauses the session if the app is sent to the background or the screen turns off.';

  @override
  String get planTitle => 'Plan Mode';

  @override
  String get planSettingsTooltip => 'Settings';

  @override
  String get planStatisticsTooltip => 'Statistics';

  @override
  String get planStartFocusTooltip => 'Start Focus';

  @override
  String planSelectedDay(String day) {
    return 'Selected day: $day';
  }

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsDenied => 'Notifications are turned off for Focused Task. Allow them in your system settings to be alerted when a task’s time is up.';

  @override
  String get settingsNotificationsAskAgain => 'Ask again';

  @override
  String get settingsNotificationsTest => 'Test notification';

  @override
  String get settingsNotificationsTestHint => 'Arrives after 10 seconds – you can leave the app in the meantime.';

  @override
  String get settingsNotificationsTestButton => 'Send';

  @override
  String get settingsNotificationsTestScheduled => 'Test notification scheduled.';

  @override
  String get notificationTestBody => 'Notifications work.';

  @override
  String get notificationOpenAction => 'Open';

  @override
  String get notificationChannelFocusAlarm => 'Focus alarm';

  @override
  String get notificationChannelReminders => 'Reminders';

  @override
  String get notificationChannelBreaks => 'Breaks';

  @override
  String get taskFormTitleRequired => 'Please enter a title.';

  @override
  String get taskFormDateLabel => 'Date';

  @override
  String get taskFormDurationLabel => 'Target duration';

  @override
  String get taskFormDurationNone => 'None';

  @override
  String get taskFormDurationCustom => 'Custom';

  @override
  String get taskFormHours => 'Hours';

  @override
  String get taskFormMinutes => 'Minutes';

  @override
  String get taskFormDurationMax => 'At most 12 hours.';

  @override
  String get taskFormNewSubTask => 'Add sub-task';

  @override
  String get taskFormPriority => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get taskPriorityMedium => 'Medium priority';

  @override
  String get taskPriorityHigh => 'High priority';

  @override
  String get taskFormDeleteTitle => 'Delete task?';

  @override
  String taskFormDeleteMessage(String title) {
    return '“$title” will be deleted permanently.';
  }

  @override
  String taskFormDeleteMessageTracked(String title, String duration) {
    return '“$title” and its $duration h of tracked time will be deleted permanently. The time still counts in your statistics.';
  }

  @override
  String get taskFormDiscardTitle => 'Discard changes?';

  @override
  String get taskFormDiscardMessage => 'Your changes to this task will be lost.';

  @override
  String get taskFormKeepEditing => 'Keep editing';

  @override
  String get taskFormDiscard => 'Discard';
}
