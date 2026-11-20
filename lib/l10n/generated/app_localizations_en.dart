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
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarPreviousWeek => 'Previous week';

  @override
  String get calendarNextWeek => 'Next week';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String calendarWeekRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String calendarDoneOfTotal(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String calendarTasksDone(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed of $total tasks done', one: '$completed of 1 task done');
    return '$_temp0';
  }

  @override
  String calendarFocusTime(String time) {
    return 'Focus time $time';
  }

  @override
  String get calendarNoTasks => 'No tasks';

  @override
  String get calendarOpenDay => 'Open in plan';

  @override
  String get calendarMoveTo => 'Move to…';

  @override
  String calendarMoveTaskTitle(String title) {
    return 'Move “$title” to';
  }

  @override
  String get calendarOtherDate => 'Other date…';

  @override
  String calendarLoadError(String error) {
    return 'Could not load the calendar: $error';
  }

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
  String commonHours(int hours) {
    return '$hours h';
  }

  @override
  String commonHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
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
  String get taskMoveOrCopyTooltip => 'Move or copy';

  @override
  String get taskMoveToToday => 'Move to today';

  @override
  String get taskMoveTo => 'Move to…';

  @override
  String get taskCopyTo => 'Copy to…';

  @override
  String taskMovedToDate(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks moved to $date', one: 'Task moved to $date');
    return '$_temp0';
  }

  @override
  String taskMovedToToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks moved to today', one: 'Task moved to today');
    return '$_temp0';
  }

  @override
  String taskCopyToDateTitle(String date) {
    return 'Copy to $date';
  }

  @override
  String get taskCopyQuestion => 'Creates a new task with the same title, details and sub-tasks. The original stays where it is.';

  @override
  String get taskEditTooltip => 'Edit Task';

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
  String get statsYear => 'Year';

  @override
  String get statsUnavailable => 'No stats available yet.';

  @override
  String get statsPreviousPeriod => 'Previous period';

  @override
  String get statsNextPeriod => 'Next period';

  @override
  String get statsCurrentPeriod => 'Go to current period';

  @override
  String statsWeekLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get statsEmptyTitle => 'No data for this period';

  @override
  String get statsEmptyMessage => 'Plan tasks and work on them in focus mode. Your focus time, completed tasks and best hours will show up here.';

  @override
  String statsTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed/$total tasks completed', one: '$completed/1 task completed');
    return '$_temp0';
  }

  @override
  String get statsFocusTime => 'Focus time';

  @override
  String get statsAveragePerDay => 'Avg. per day';

  @override
  String statsElapsedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'over $days days so far', one: 'over 1 day so far', zero: 'period not started yet');
    return '$_temp0';
  }

  @override
  String get statsSessions => 'Sessions';

  @override
  String statsAverageSession(String duration) {
    return 'Avg. $duration each';
  }

  @override
  String get statsCompletion => 'Completed';

  @override
  String get statsNoTasks => 'No tasks planned';

  @override
  String get statsInterruptions => 'Interruptions per focus hour';

  @override
  String statsInterruptionsValue(double value) {
    final intl.NumberFormat valueNumberFormat = intl.NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString';
  }

  @override
  String get statsNoValue => '–';

  @override
  String get statsFocusPerHour => 'Focus time per hour';

  @override
  String get statsFocusPerDay => 'Focus time per day';

  @override
  String get statsFocusPerMonth => 'Focus time per month';

  @override
  String statsChartTooltip(String label, String duration) {
    return '$label: $duration';
  }

  @override
  String statsHourRange(String start, String end) {
    return '$start:00–$end:00';
  }

  @override
  String statsHeatmapLabel(String weekday, String hours) {
    return '$weekday $hours';
  }

  @override
  String get statsPlannedVsActual => 'Planned vs. actual';

  @override
  String get statsPlanned => 'Planned';

  @override
  String get statsTracked => 'Tracked';

  @override
  String statsTargetTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks with a target duration', one: '1 task with a target duration');
    return '$_temp0';
  }

  @override
  String get statsNoTargets => 'Give tasks a target duration to compare your plan with the time you actually needed.';

  @override
  String statsEstimationAccuracy(int percent) {
    return 'Completed tasks took $percent% of their target (median).';
  }

  @override
  String get statsBestHours => 'Best focus hours';

  @override
  String get statsTopTasks => 'Top tasks';

  @override
  String get statsDeletedTask => 'Deleted task';

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
  String get settingsPlanning => 'Planning';

  @override
  String get settingsAskToMoveUnfinished => 'Ask to move unfinished tasks';

  @override
  String get settingsAskToMoveUnfinishedHint => 'On the first start of a day, offer to move open tasks of the last 7 days to today';

  @override
  String get settingsCollapseCompleted => 'Collapse completed tasks';

  @override
  String get settingsCollapseCompletedHint => 'Completed tasks move into a section at the end of the plan that you can show or hide';

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

  @override
  String get focusSkip => 'Skip';

  @override
  String get focusUpNext => 'Up next';

  @override
  String get taskFocusTooltip => 'Focus on this task';

  @override
  String get planFocusStart => 'Start';

  @override
  String get planFocusAheadTitle => 'Work ahead?';

  @override
  String get planFocusAheadTomorrow => 'Work on tomorrow’s tasks now?';

  @override
  String planFocusAheadDate(String date) {
    return 'Work on the tasks of $date now?';
  }

  @override
  String get planFocusMoveTitle => 'Move to today?';

  @override
  String planFocusMoveMessage(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The $count open tasks of $date move to today, then focus starts.',
      one: 'The open task of $date moves to today, then focus starts.',
    );
    return '$_temp0';
  }

  @override
  String get planFocusYesterdayTitle => 'Nothing open today';

  @override
  String planFocusYesterdayMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks from yesterday are still open. Move them to today and focus on them?',
      one: '1 task from yesterday is still open. Move it to today and focus on it?',
    );
    return '$_temp0';
  }

  @override
  String get planFocusMoveAndStart => 'Move and start';

  @override
  String get commonUndo => 'Undo';

  @override
  String get planRolloverTitle => 'Unfinished tasks';

  @override
  String planRolloverMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks from the last few days are still open.',
      one: '1 task from the last few days is still open.',
    );
    return '$_temp0';
  }

  @override
  String planRolloverMove(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Move $count tasks to today', one: 'Move 1 task to today', zero: 'Move to today');
    return '$_temp0';
  }

  @override
  String get planRolloverNotNow => 'Not now';

  @override
  String get planRolloverSettingsHint => 'You can turn this question off in the settings.';

  @override
  String get settingsGoals => 'Goals';

  @override
  String get settingsDailyGoal => 'Daily focus goal';

  @override
  String get settingsDailyGoalHint => 'Focus time to aim for on a working day. Shown as a ring in the plan.';

  @override
  String get settingsGoalOff => 'Off';

  @override
  String get settingsWorkingDays => 'Working days';

  @override
  String get settingsWorkingDaysHint => 'Days off neither break nor extend a streak.';

  @override
  String planGoalProgress(String focus, String goal) {
    return 'Today’s focus: $focus of $goal';
  }

  @override
  String planGoalReached(String focus, String goal) {
    return 'Daily goal reached: $focus of $goal';
  }

  @override
  String get statsCurrentStreak => 'Current streak';

  @override
  String get statsLongestStreak => 'Longest streak';

  @override
  String statsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String statsStreakHint(String goal) {
    return 'Working days with $goal of focus';
  }

  @override
  String statsGoalDays(String year) {
    return 'Goal days in $year';
  }

  @override
  String statsGoalDaysTooltip(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count goal days', one: '1 goal day', zero: 'no goal days');
    return '$month: $_temp0';
  }

  @override
  String get statsGoalOff => 'Set a daily focus goal in the settings to see your streaks.';

  @override
  String get finishedSummary => 'Today';

  @override
  String get finishedFocusTime => 'Focus time';

  @override
  String get finishedTasksDone => 'Tasks done';

  @override
  String get finishedGoal => 'Daily goal';

  @override
  String finishedGoalReached(String goal) {
    return 'Reached ($goal)';
  }

  @override
  String finishedGoalNotReached(String focus, String goal) {
    return 'Not reached ($focus of $goal)';
  }

  @override
  String get finishedStreak => 'Streak';

  @override
  String get notificationGoalReachedTitle => 'Daily goal reached';

  @override
  String notificationGoalReachedBody(String goal) {
    return 'You focused for $goal today.';
  }

  @override
  String get settingsCategories => 'Categories';

  @override
  String get settingsCategoriesHint => 'Group tasks, filter the plan and focus on one category.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmpty => 'No categories yet. Add one to group your tasks, e.g. “Work” or “Study”.';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesNewTitle => 'New category';

  @override
  String get categoriesEditTitle => 'Edit category';

  @override
  String get categoriesNameLabel => 'Name';

  @override
  String get categoriesNameRequired => 'Please enter a name.';

  @override
  String get categoriesNameTaken => 'A category with this name already exists.';

  @override
  String get categoriesColor => 'Color';

  @override
  String get categoriesActions => 'Category actions';

  @override
  String get categoriesEdit => 'Edit';

  @override
  String get categoriesArchive => 'Archive';

  @override
  String get categoriesRestore => 'Restore';

  @override
  String get categoriesArchived => 'Archived';

  @override
  String get categoriesArchivedHint => 'Hidden in the plan and the task form. Their tasks keep the category.';

  @override
  String get categoriesDeleteTitle => 'Delete category?';

  @override
  String categoriesDeleteMessage(String name) {
    return '“$name” will be deleted. Its tasks stay, without a category. Tracked time stays in the statistics.';
  }

  @override
  String get categoriesReorderTooltip => 'Drag to reorder';

  @override
  String categoryColorName(String color) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'red': 'Red',
      'orange': 'Orange',
      'yellow': 'Yellow',
      'green': 'Green',
      'teal': 'Teal',
      'cyan': 'Cyan',
      'blue': 'Blue',
      'indigo': 'Indigo',
      'purple': 'Purple',
      'pink': 'Pink',
      'other': 'Color',
    });
    return '$_temp0';
  }

  @override
  String categoryLabel(String name) {
    return 'Category: $name';
  }

  @override
  String get taskFormCategory => 'Category';

  @override
  String get taskFormCategoryNone => 'None';

  @override
  String get taskFormCategoryNew => 'New';

  @override
  String get planFilterAll => 'All';

  @override
  String get planShowList => 'Show as list';

  @override
  String get planShowBoard => 'Show as board';

  @override
  String planFocusOnCategory(String name) {
    return 'Focus on $name';
  }

  @override
  String get planNoCategory => 'No category';

  @override
  String get planBoardDropHere => 'Drop tasks here';

  @override
  String get planBoardDragTooltip => 'Drag to another category';

  @override
  String get planNoTasksInCategory => 'No tasks in this category for this day.';

  @override
  String planCategoryOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count open', one: '1 open', zero: 'none open');
    return '$_temp0';
  }

  @override
  String planCategoryProgress(int done, int total, int percent) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$total tasks', one: '1 task');
    return '$done of $_temp0 done ($percent%)';
  }

  @override
  String planCategoryTracked(String duration) {
    return '$duration tracked';
  }

  @override
  String planCompletedSection(int count) {
    return 'Completed ($count)';
  }

  @override
  String get planShowCompleted => 'Show completed tasks';

  @override
  String get planHideCompleted => 'Hide completed tasks';

  @override
  String get statsByCategory => 'Focus time per category';

  @override
  String get statsNoCategory => 'No category';

  @override
  String focusTitleCategory(String name) {
    return 'Focus: $name';
  }

  @override
  String get settingsIntervals => 'Work in intervals';

  @override
  String get settingsIntervalsHint => 'Pomodoro style: focus for a set time, then take a short break.';

  @override
  String get settingsIntervalWork => 'Work interval';

  @override
  String get settingsIntervalShortBreak => 'Short break';

  @override
  String get settingsIntervalLongBreak => 'Long break';

  @override
  String get settingsIntervalLongBreakEvery => 'Long break after';

  @override
  String settingsIntervalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count intervals', one: '1 interval');
    return '$_temp0';
  }

  @override
  String get settingsIntervalAutoStart => 'Continue automatically after a break';

  @override
  String get settingsIntervalAutoStartHint => 'Otherwise focus waits until you are ready.';

  @override
  String focusBreakIn(String duration) {
    return 'Break in $duration';
  }

  @override
  String get breakShortTitle => 'Short break';

  @override
  String get breakLongTitle => 'Long break';

  @override
  String get breakHint => 'Stand up, stretch and look away from the screen.';

  @override
  String get breakSkip => 'Skip break';

  @override
  String get breakReadyTitle => 'Ready?';

  @override
  String breakContinueWith(String task) {
    return 'Continue with $task';
  }

  @override
  String get breakContinue => 'Continue';

  @override
  String get notificationBreakTitle => 'Time for a break';

  @override
  String notificationBreakBody(String duration) {
    return 'Take $duration off. Stand up and look away from the screen.';
  }

  @override
  String get notificationBreakOverTitle => 'Break is over';

  @override
  String notificationBreakOverBody(String task) {
    return 'Ready? Continue with $task.';
  }

  @override
  String statsBreakTime(String duration) {
    return '+ $duration breaks';
  }

  @override
  String get settingsMinimalFocusLayout => 'Minimal focus layout';

  @override
  String get settingsMinimalFocusLayoutHint => 'Only the timer, the task and its main button. Can also be switched in focus mode.';

  @override
  String get focusDistracted => 'I got distracted';

  @override
  String focusDistractedNoted(String task) {
    return 'Noted. Back to $task.';
  }

  @override
  String get focusMinimalLayout => 'Minimal layout';

  @override
  String get focusFullLayout => 'Show everything';

  @override
  String get focusParkThought => 'Park a thought…';

  @override
  String get focusThoughtParked => 'Parked for later.';

  @override
  String focusAwayFor(String duration) {
    return 'You were away $duration.';
  }

  @override
  String inboxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count parked thoughts', one: '1 parked thought');
    return '$_temp0';
  }

  @override
  String get inboxReview => 'Review';

  @override
  String get inboxTitle => 'Parked thoughts';

  @override
  String get inboxHint => 'Turn them into tasks or let them go.';

  @override
  String get inboxToTodayTooltip => 'Add as a task for today';

  @override
  String get inboxToTomorrowTooltip => 'Add as a task for tomorrow';

  @override
  String get inboxDismiss => 'Dismiss';

  @override
  String get inboxAddedToday => 'Added to today.';

  @override
  String get inboxAddedTomorrow => 'Added to tomorrow.';

  @override
  String get inboxDismissed => 'Dismissed.';

  @override
  String get inboxAllReviewed => 'All reviewed.';

  @override
  String get statsParkedThoughts => 'Parked thoughts';

  @override
  String get statsParkedThoughtReviewed => 'Reviewed';

  @override
  String get taskFormSchedule => 'Schedule & reminder';

  @override
  String get taskFormScheduleNotSet => 'Not set';

  @override
  String taskScheduleStart(String time) {
    return 'Start $time';
  }

  @override
  String taskScheduleDue(String date) {
    return 'Due $date';
  }

  @override
  String taskScheduleReminderBefore(String duration) {
    return '$duration before';
  }

  @override
  String get taskScheduleReminderOff => 'No reminder';

  @override
  String get taskScheduleTitle => 'Schedule & reminder';

  @override
  String get taskScheduleStartTime => 'Start time';

  @override
  String taskScheduleStartHint(String day) {
    return 'On the task\'s day ($day)';
  }

  @override
  String get taskScheduleNone => 'None';

  @override
  String get taskScheduleDueDate => 'Due date';

  @override
  String get taskScheduleDueTime => 'Due time';

  @override
  String taskScheduleDueTimeDefault(String time) {
    return 'Default ($time)';
  }

  @override
  String get taskScheduleClear => 'Remove';

  @override
  String get taskScheduleReminder => 'Reminder';

  @override
  String taskScheduleReminderDefault(String duration) {
    return 'Default ($duration)';
  }

  @override
  String get taskScheduleReminderOffOption => 'Off';

  @override
  String taskScheduleReminderAt(String time) {
    return 'Reminder at $time';
  }

  @override
  String get taskScheduleReminderNow => 'The reminder time has passed – you\'ll be reminded right away.';

  @override
  String get taskScheduleReminderNeedsTime => 'Set a start time or a due date to get a reminder.';

  @override
  String get taskScheduleReminderDueHint => 'Before the deadline, early enough for the time still left on the estimate.';

  @override
  String get taskScheduleRemindersDisabled => 'Task reminders are turned off in the settings.';

  @override
  String taskStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String planOverdueBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tasks overdue', one: '1 task overdue');
    return '$_temp0';
  }

  @override
  String get planOverdueShow => 'Show';

  @override
  String get planOverdueSheetTitle => 'Overdue tasks';

  @override
  String planOverduePlannedFor(String day) {
    return 'Planned for $day';
  }

  @override
  String get settingsReminders => 'Reminders & dates';

  @override
  String get settingsRemindersHint => 'Task reminders, daily planning, inactivity and notifications';

  @override
  String get settingsTaskReminders => 'Task reminders';

  @override
  String get settingsTaskRemindersHint => 'Before a task\'s start time or deadline';

  @override
  String get settingsDefaultLead => 'Default reminder';

  @override
  String get settingsDefaultDueTime => 'Default due time';

  @override
  String get settingsDefaultDueTimeHint => 'For deadlines with only a date';

  @override
  String get settingsDailyPlanning => 'Daily planning';

  @override
  String get settingsDailyPlanningHint => '\"Plan your day\" on working days when nothing is planned yet';

  @override
  String get settingsReminderTime => 'Time';

  @override
  String get settingsInactivity => 'Inactivity reminder';

  @override
  String get settingsInactivityHint => 'During working hours on working days, when no focus session ran for a while';

  @override
  String get settingsWorkStart => 'Working hours from';

  @override
  String get settingsWorkEnd => 'Working hours until';

  @override
  String get settingsIdleTime => 'Remind after';

  @override
  String get settingsWorkingDaysFromGoals => 'Working days are set under Goals in the settings.';

  @override
  String reminderTaskStartBody(String time) {
    return 'Starts at $time';
  }

  @override
  String reminderTaskDueBody(String time) {
    return 'Due $time';
  }

  @override
  String get reminderPlanDayTitle => 'Plan your day';

  @override
  String get reminderPlanDayBody => 'Nothing is planned for today yet. Pick the tasks you want to focus on.';

  @override
  String get reminderInactivityTitle => 'Ready for the next focus block?';

  @override
  String reminderInactivityBody(String duration) {
    return 'No focus session for $duration.';
  }

  @override
  String taskOverdueDue(String date) {
    return 'Overdue, was due $date';
  }

  @override
  String get taskFormRepeat => 'Repeat';

  @override
  String get taskRepeatTitle => 'Repeat';

  @override
  String get taskRepeatNever => 'Never';

  @override
  String get taskRepeatDaily => 'Every day';

  @override
  String get taskRepeatWeekdays => 'Every weekday (Mon–Fri)';

  @override
  String get taskRepeatWeekly => 'Weekly';

  @override
  String taskRepeatWeeklyOn(String days) {
    return 'Weekly on $days';
  }

  @override
  String get taskRepeatIntervalOption => 'Every few days';

  @override
  String taskRepeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Every $count days', one: 'Every day');
    return '$_temp0';
  }

  @override
  String taskRepeatMonthly(int day) {
    return 'Monthly on day $day';
  }

  @override
  String get taskRepeatMonthlyHint => 'Months without this day use their last day.';

  @override
  String get taskRepeatIntervalLabel => 'Days between';

  @override
  String get taskRepeatFewerDays => 'Fewer days';

  @override
  String get taskRepeatMoreDays => 'More days';

  @override
  String get taskRepeatEnds => 'Ends';

  @override
  String get taskRepeatEndsNever => 'Never';

  @override
  String taskRepeatUntil(String pattern, String date) {
    return '$pattern, until $date';
  }

  @override
  String get taskRepeatSeriesHint => 'A change to the repeat applies to this and all following days.';

  @override
  String get taskRecurringLabel => 'Repeats';

  @override
  String get taskRepeatScopeTitle => 'Change recurring task';

  @override
  String get taskRepeatScopeMessage => 'Save the changes only for this day, or for this and all following days?';

  @override
  String get taskRepeatScopeOnlyThis => 'Only this';

  @override
  String get taskRepeatScopeThisAndFuture => 'This and future';

  @override
  String get taskRepeatDeleteTitle => 'Delete recurring task';

  @override
  String taskRepeatDeleteMessage(String title) {
    return 'Delete “$title” only on this day, or this and all following ones? Tracked time stays in the statistics.';
  }
}
