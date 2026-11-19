import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Focused Task'**
  String get appTitle;

  /// No description provided for @navPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get navPlan;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStatistics;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @calendarViewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// No description provided for @calendarPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get calendarPreviousWeek;

  /// No description provided for @calendarNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get calendarNextWeek;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarWeekRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String calendarWeekRange(String start, String end);

  /// No description provided for @calendarDoneOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total}'**
  String calendarDoneOfTotal(int completed, int total);

  /// No description provided for @calendarTasksDone.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{completed} of 1 task done} other{{completed} of {total} tasks done}}'**
  String calendarTasksDone(int completed, int total);

  /// No description provided for @calendarFocusTime.
  ///
  /// In en, this message translates to:
  /// **'Focus time {time}'**
  String calendarFocusTime(String time);

  /// No description provided for @calendarNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get calendarNoTasks;

  /// No description provided for @calendarOpenDay.
  ///
  /// In en, this message translates to:
  /// **'Open in plan'**
  String get calendarOpenDay;

  /// No description provided for @calendarMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get calendarMoveTo;

  /// No description provided for @calendarMoveTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Move “{title}” to'**
  String calendarMoveTaskTitle(String title);

  /// No description provided for @calendarOtherDate.
  ///
  /// In en, this message translates to:
  /// **'Other date…'**
  String get calendarOtherDate;

  /// No description provided for @calendarLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the calendar: {error}'**
  String calendarLoadError(String error);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonListItem.
  ///
  /// In en, this message translates to:
  /// **'• {item}'**
  String commonListItem(String item);

  /// No description provided for @commonMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String commonMinutes(int minutes);

  /// No description provided for @commonHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String commonHours(int hours);

  /// No description provided for @commonHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String commonHoursMinutes(int hours, int minutes);

  /// No description provided for @commonPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String commonPercent(int percent);

  /// No description provided for @planPickDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick Day'**
  String get planPickDayTooltip;

  /// No description provided for @planPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get planPreviousDay;

  /// No description provided for @planNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get planNextDay;

  /// No description provided for @planStartFocus.
  ///
  /// In en, this message translates to:
  /// **'Start focus'**
  String get planStartFocus;

  /// No description provided for @planNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks for this day.'**
  String get planNoTasks;

  /// No description provided for @planLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the tasks: {error}'**
  String planLoadError(String error);

  /// No description provided for @planAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get planAddTask;

  /// No description provided for @taskMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark task as complete'**
  String get taskMarkComplete;

  /// No description provided for @taskMarkIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark task as incomplete'**
  String get taskMarkIncomplete;

  /// No description provided for @taskNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get taskNoDescription;

  /// No description provided for @taskTodoProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total}'**
  String taskTodoProgress(int completed, int total);

  /// No description provided for @taskMoveOrCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move or copy'**
  String get taskMoveOrCopyTooltip;

  /// No description provided for @taskMoveToToday.
  ///
  /// In en, this message translates to:
  /// **'Move to today'**
  String get taskMoveToToday;

  /// No description provided for @taskMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get taskMoveTo;

  /// No description provided for @taskCopyTo.
  ///
  /// In en, this message translates to:
  /// **'Copy to…'**
  String get taskCopyTo;

  /// No description provided for @taskMovedToDate.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task moved to {date}} other{{count} tasks moved to {date}}}'**
  String taskMovedToDate(int count, String date);

  /// No description provided for @taskMovedToToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Task moved to today} other{{count} tasks moved to today}}'**
  String taskMovedToToday(int count);

  /// No description provided for @taskCopyToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to {date}'**
  String taskCopyToDateTitle(String date);

  /// No description provided for @taskCopyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Creates a new task with the same title, details and sub-tasks. The original stays where it is.'**
  String get taskCopyQuestion;

  /// No description provided for @taskEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get taskEditTooltip;

  /// No description provided for @taskKeepCompletedTodos.
  ///
  /// In en, this message translates to:
  /// **'Keep completed to-dos'**
  String get taskKeepCompletedTodos;

  /// No description provided for @taskKeepCompletedTodosHint.
  ///
  /// In en, this message translates to:
  /// **'If off, all to-dos will be reset'**
  String get taskKeepCompletedTodosHint;

  /// No description provided for @taskSubtractTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Subtract time spent'**
  String get taskSubtractTimeSpent;

  /// No description provided for @taskSubtractTimeSpentHint.
  ///
  /// In en, this message translates to:
  /// **'Reduces the new target duration by the time already tracked'**
  String get taskSubtractTimeSpentHint;

  /// No description provided for @taskFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get taskFormAddTitle;

  /// No description provided for @taskFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get taskFormEditTitle;

  /// No description provided for @taskFormDuplicateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Task'**
  String get taskFormDuplicateTooltip;

  /// No description provided for @taskFormDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get taskFormDeleteTooltip;

  /// No description provided for @taskFormTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskFormTitleLabel;

  /// No description provided for @taskFormDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskFormDescriptionLabel;

  /// No description provided for @taskFormSubTasks.
  ///
  /// In en, this message translates to:
  /// **'Sub-tasks'**
  String get taskFormSubTasks;

  /// No description provided for @taskFormAddSubTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Sub-task'**
  String get taskFormAddSubTaskTooltip;

  /// No description provided for @taskFormDeleteSubTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete sub-task'**
  String get taskFormDeleteSubTaskTooltip;

  /// No description provided for @taskFormTrackedTime.
  ///
  /// In en, this message translates to:
  /// **'Tracked time'**
  String get taskFormTrackedTime;

  /// No description provided for @taskFormAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get taskFormAddTime;

  /// No description provided for @taskFormAddTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add tracked time'**
  String get taskFormAddTimeTitle;

  /// No description provided for @taskFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save Task'**
  String get taskFormSave;

  /// No description provided for @focusTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get focusTitle;

  /// No description provided for @focusExitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Exit focus'**
  String get focusExitTooltip;

  /// No description provided for @focusTimeIsUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up!'**
  String get focusTimeIsUp;

  /// No description provided for @focusTargetReached.
  ///
  /// In en, this message translates to:
  /// **'You have reached your target duration for this task.'**
  String get focusTargetReached;

  /// No description provided for @focusStopAlarmAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Stop Alarm & Continue'**
  String get focusStopAlarmAndContinue;

  /// No description provided for @focusNoUnfinishedTasks.
  ///
  /// In en, this message translates to:
  /// **'No unfinished tasks for today.'**
  String get focusNoUnfinishedTasks;

  /// No description provided for @focusCompleteTask.
  ///
  /// In en, this message translates to:
  /// **'Complete Task'**
  String get focusCompleteTask;

  /// No description provided for @focusExit.
  ///
  /// In en, this message translates to:
  /// **'Exit Focus'**
  String get focusExit;

  /// No description provided for @focusTimerSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get focusTimerSession;

  /// No description provided for @focusTimerTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get focusTimerTask;

  /// No description provided for @focusTimerOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get focusTimerOverdue;

  /// No description provided for @focusTimerRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get focusTimerRemaining;

  /// No description provided for @focusAlarmNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'You have reached your target duration for: {taskTitle}'**
  String focusAlarmNotificationBody(String taskTitle);

  /// No description provided for @focusAlarmStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop Alarm'**
  String get focusAlarmStopButton;

  /// No description provided for @pauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pauseTitle;

  /// No description provided for @pauseMessage.
  ///
  /// In en, this message translates to:
  /// **'Focus paused while app is in background.'**
  String get pauseMessage;

  /// No description provided for @pauseResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Focus'**
  String get pauseResume;

  /// No description provided for @finishedTitle.
  ///
  /// In en, this message translates to:
  /// **'All Done'**
  String get finishedTitle;

  /// No description provided for @finishedHeadline.
  ///
  /// In en, this message translates to:
  /// **'Finished for Today!'**
  String get finishedHeadline;

  /// No description provided for @finishedMessage.
  ///
  /// In en, this message translates to:
  /// **'Great work — you completed everything planned for today.'**
  String get finishedMessage;

  /// No description provided for @finishedViewStatistics.
  ///
  /// In en, this message translates to:
  /// **'View Statistics'**
  String get finishedViewStatistics;

  /// No description provided for @finishedBackToPlan.
  ///
  /// In en, this message translates to:
  /// **'Back to Plan'**
  String get finishedBackToPlan;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover unfinished session?'**
  String get recoveryTitle;

  /// No description provided for @recoveryClosedWhileFocusing.
  ///
  /// In en, this message translates to:
  /// **'The app was closed while you were focusing on:'**
  String get recoveryClosedWhileFocusing;

  /// No description provided for @recoveryQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much of that time do you want to keep?'**
  String get recoveryQuestion;

  /// No description provided for @recoveryDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recoveryDiscard;

  /// No description provided for @recoveryDeletedTask.
  ///
  /// In en, this message translates to:
  /// **'(deleted task)'**
  String get recoveryDeletedTask;

  /// No description provided for @recoveryUntilNow.
  ///
  /// In en, this message translates to:
  /// **'Until now ({duration})'**
  String recoveryUntilNow(String duration);

  /// No description provided for @recoveryUntilLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Until last activity ({duration})'**
  String recoveryUntilLastActivity(String duration);

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statsDay;

  /// No description provided for @statsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsWeek;

  /// No description provided for @statsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statsYear;

  /// No description provided for @statsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No stats available yet.'**
  String get statsUnavailable;

  /// No description provided for @statsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get statsPreviousPeriod;

  /// No description provided for @statsNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get statsNextPeriod;

  /// No description provided for @statsCurrentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Go to current period'**
  String get statsCurrentPeriod;

  /// No description provided for @statsWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String statsWeekLabel(String start, String end);

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Plan tasks and work on them in focus mode. Your focus time, completed tasks and best hours will show up here.'**
  String get statsEmptyMessage;

  /// No description provided for @statsTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{completed}/1 task completed} other{{completed}/{total} tasks completed}}'**
  String statsTasksCompleted(int completed, int total);

  /// No description provided for @statsFocusTime.
  ///
  /// In en, this message translates to:
  /// **'Focus time'**
  String get statsFocusTime;

  /// No description provided for @statsAveragePerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg. per day'**
  String get statsAveragePerDay;

  /// No description provided for @statsElapsedDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{period not started yet} =1{over 1 day so far} other{over {days} days so far}}'**
  String statsElapsedDays(int days);

  /// No description provided for @statsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statsSessions;

  /// No description provided for @statsAverageSession.
  ///
  /// In en, this message translates to:
  /// **'Avg. {duration} each'**
  String statsAverageSession(String duration);

  /// No description provided for @statsCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statsCompletion;

  /// No description provided for @statsNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks planned'**
  String get statsNoTasks;

  /// No description provided for @statsInterruptions.
  ///
  /// In en, this message translates to:
  /// **'Interruptions per focus hour'**
  String get statsInterruptions;

  /// No description provided for @statsInterruptionsValue.
  ///
  /// In en, this message translates to:
  /// **'{value}'**
  String statsInterruptionsValue(double value);

  /// No description provided for @statsNotTrackedYet.
  ///
  /// In en, this message translates to:
  /// **'Not tracked yet'**
  String get statsNotTrackedYet;

  /// No description provided for @statsNoValue.
  ///
  /// In en, this message translates to:
  /// **'–'**
  String get statsNoValue;

  /// No description provided for @statsFocusPerHour.
  ///
  /// In en, this message translates to:
  /// **'Focus time per hour'**
  String get statsFocusPerHour;

  /// No description provided for @statsFocusPerDay.
  ///
  /// In en, this message translates to:
  /// **'Focus time per day'**
  String get statsFocusPerDay;

  /// No description provided for @statsFocusPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Focus time per month'**
  String get statsFocusPerMonth;

  /// No description provided for @statsChartTooltip.
  ///
  /// In en, this message translates to:
  /// **'{label}: {duration}'**
  String statsChartTooltip(String label, String duration);

  /// No description provided for @statsHourRange.
  ///
  /// In en, this message translates to:
  /// **'{start}:00–{end}:00'**
  String statsHourRange(String start, String end);

  /// No description provided for @statsHeatmapLabel.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {hours}'**
  String statsHeatmapLabel(String weekday, String hours);

  /// No description provided for @statsPlannedVsActual.
  ///
  /// In en, this message translates to:
  /// **'Planned vs. actual'**
  String get statsPlannedVsActual;

  /// No description provided for @statsPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statsPlanned;

  /// No description provided for @statsTracked.
  ///
  /// In en, this message translates to:
  /// **'Tracked'**
  String get statsTracked;

  /// No description provided for @statsTargetTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task with a target duration} other{{count} tasks with a target duration}}'**
  String statsTargetTasks(int count);

  /// No description provided for @statsNoTargets.
  ///
  /// In en, this message translates to:
  /// **'Give tasks a target duration to compare your plan with the time you actually needed.'**
  String get statsNoTargets;

  /// No description provided for @statsEstimationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks took {percent}% of their target (median).'**
  String statsEstimationAccuracy(int percent);

  /// No description provided for @statsBestHours.
  ///
  /// In en, this message translates to:
  /// **'Best focus hours'**
  String get statsBestHours;

  /// No description provided for @statsTopTasks.
  ///
  /// In en, this message translates to:
  /// **'Top tasks'**
  String get statsTopTasks;

  /// No description provided for @statsDeletedTask.
  ///
  /// In en, this message translates to:
  /// **'Deleted task'**
  String get statsDeletedTask;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get settingsPlanning;

  /// No description provided for @settingsAskToMoveUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Ask to move unfinished tasks'**
  String get settingsAskToMoveUnfinished;

  /// No description provided for @settingsAskToMoveUnfinishedHint.
  ///
  /// In en, this message translates to:
  /// **'On the first start of a day, offer to move open tasks of the last 7 days to today'**
  String get settingsAskToMoveUnfinishedHint;

  /// No description provided for @settingsDataRetention.
  ///
  /// In en, this message translates to:
  /// **'Data Retention'**
  String get settingsDataRetention;

  /// No description provided for @settingsDataRetentionInfo.
  ///
  /// In en, this message translates to:
  /// **'Deleted tasks are removed from your statistics as well. Tasks with an unfinished session are never deleted.'**
  String get settingsDataRetentionInfo;

  /// No description provided for @settingsAutoCleanup.
  ///
  /// In en, this message translates to:
  /// **'Delete old completed tasks automatically'**
  String get settingsAutoCleanup;

  /// No description provided for @settingsAutoCleanupHint.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{On every app start, completed tasks older than 1 day are deleted.} other{On every app start, completed tasks older than {days} days are deleted.}}'**
  String settingsAutoCleanupHint(int days);

  /// No description provided for @settingsRetentionPeriod.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Retention period: 1 day} other{Retention period: {days} days}}'**
  String settingsRetentionPeriod(int days);

  /// No description provided for @settingsDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get settingsDecrease;

  /// No description provided for @settingsIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get settingsIncrease;

  /// No description provided for @settingsCleanNow.
  ///
  /// In en, this message translates to:
  /// **'Clean now'**
  String get settingsCleanNow;

  /// No description provided for @settingsNothingToClean.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{No completed tasks older than 1 day.} other{No completed tasks older than {days} days.}}'**
  String settingsNothingToClean(int days);

  /// No description provided for @settingsCleanupDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was deleted.} =1{Deleted 1 task.} other{Deleted {count} tasks.}}'**
  String settingsCleanupDeleted(int count);

  /// No description provided for @settingsCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Cleanup failed. Please try again.'**
  String get settingsCleanupFailed;

  /// No description provided for @settingsCleanupConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete old tasks?'**
  String get settingsCleanupConfirmTitle;

  /// No description provided for @settingsCleanupConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 completed task} other{{count} completed tasks}} older than {days, plural, =1{1 day} other{{days} days}} will be deleted permanently, including the tracked time in the statistics.'**
  String settingsCleanupConfirmMessage(int count, int days);

  /// No description provided for @settingsFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Focus Mode'**
  String get settingsFocusMode;

  /// No description provided for @settingsKeepScreenAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get settingsKeepScreenAwake;

  /// No description provided for @settingsKeepScreenAwakeHint.
  ///
  /// In en, this message translates to:
  /// **'Prevents the screen from turning off during an active focus session.'**
  String get settingsKeepScreenAwakeHint;

  /// No description provided for @settingsPauseOnBackground.
  ///
  /// In en, this message translates to:
  /// **'Pause when minimized or locked'**
  String get settingsPauseOnBackground;

  /// No description provided for @settingsPauseOnBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Pauses the session if the app is sent to the background or the screen turns off.'**
  String get settingsPauseOnBackgroundHint;

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan Mode'**
  String get planTitle;

  /// No description provided for @planSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get planSettingsTooltip;

  /// No description provided for @planStatisticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get planStatisticsTooltip;

  /// No description provided for @planStartFocusTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start Focus'**
  String get planStartFocusTooltip;

  /// No description provided for @planSelectedDay.
  ///
  /// In en, this message translates to:
  /// **'Selected day: {day}'**
  String planSelectedDay(String day);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Focused Task. Allow them in your system settings to be alerted when a task’s time is up.'**
  String get settingsNotificationsDenied;

  /// No description provided for @settingsNotificationsAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get settingsNotificationsAskAgain;

  /// No description provided for @settingsNotificationsTest.
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get settingsNotificationsTest;

  /// No description provided for @settingsNotificationsTestHint.
  ///
  /// In en, this message translates to:
  /// **'Arrives after 10 seconds – you can leave the app in the meantime.'**
  String get settingsNotificationsTestHint;

  /// No description provided for @settingsNotificationsTestButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get settingsNotificationsTestButton;

  /// No description provided for @settingsNotificationsTestScheduled.
  ///
  /// In en, this message translates to:
  /// **'Test notification scheduled.'**
  String get settingsNotificationsTestScheduled;

  /// No description provided for @notificationTestBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications work.'**
  String get notificationTestBody;

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationOpenAction;

  /// No description provided for @notificationChannelFocusAlarm.
  ///
  /// In en, this message translates to:
  /// **'Focus alarm'**
  String get notificationChannelFocusAlarm;

  /// No description provided for @notificationChannelReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationChannelReminders;

  /// No description provided for @notificationChannelBreaks.
  ///
  /// In en, this message translates to:
  /// **'Breaks'**
  String get notificationChannelBreaks;

  /// No description provided for @taskFormTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get taskFormTitleRequired;

  /// No description provided for @taskFormDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get taskFormDateLabel;

  /// No description provided for @taskFormDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Target duration'**
  String get taskFormDurationLabel;

  /// No description provided for @taskFormDurationNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get taskFormDurationNone;

  /// No description provided for @taskFormDurationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get taskFormDurationCustom;

  /// No description provided for @taskFormHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get taskFormHours;

  /// No description provided for @taskFormMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get taskFormMinutes;

  /// No description provided for @taskFormDurationMax.
  ///
  /// In en, this message translates to:
  /// **'At most 12 hours.'**
  String get taskFormDurationMax;

  /// No description provided for @taskFormNewSubTask.
  ///
  /// In en, this message translates to:
  /// **'Add sub-task'**
  String get taskFormNewSubTask;

  /// No description provided for @taskFormPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskFormPriority;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium priority'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get taskPriorityHigh;

  /// No description provided for @taskFormDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get taskFormDeleteTitle;

  /// No description provided for @taskFormDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be deleted permanently.'**
  String taskFormDeleteMessage(String title);

  /// No description provided for @taskFormDeleteMessageTracked.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and its {duration} h of tracked time will be deleted permanently. The time still counts in your statistics.'**
  String taskFormDeleteMessageTracked(String title, String duration);

  /// No description provided for @taskFormDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get taskFormDiscardTitle;

  /// No description provided for @taskFormDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this task will be lost.'**
  String get taskFormDiscardMessage;

  /// No description provided for @taskFormKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get taskFormKeepEditing;

  /// No description provided for @taskFormDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get taskFormDiscard;

  /// No description provided for @focusSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get focusSkip;

  /// No description provided for @focusUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get focusUpNext;

  /// No description provided for @taskFocusTooltip.
  ///
  /// In en, this message translates to:
  /// **'Focus on this task'**
  String get taskFocusTooltip;

  /// No description provided for @planFocusStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get planFocusStart;

  /// No description provided for @planFocusAheadTitle.
  ///
  /// In en, this message translates to:
  /// **'Work ahead?'**
  String get planFocusAheadTitle;

  /// No description provided for @planFocusAheadTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Work on tomorrow’s tasks now?'**
  String get planFocusAheadTomorrow;

  /// No description provided for @planFocusAheadDate.
  ///
  /// In en, this message translates to:
  /// **'Work on the tasks of {date} now?'**
  String planFocusAheadDate(String date);

  /// No description provided for @planFocusMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to today?'**
  String get planFocusMoveTitle;

  /// No description provided for @planFocusMoveMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The open task of {date} moves to today, then focus starts.} other{The {count} open tasks of {date} move to today, then focus starts.}}'**
  String planFocusMoveMessage(int count, String date);

  /// No description provided for @planFocusYesterdayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing open today'**
  String get planFocusYesterdayTitle;

  /// No description provided for @planFocusYesterdayMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task from yesterday is still open. Move it to today and focus on it?} other{{count} tasks from yesterday are still open. Move them to today and focus on them?}}'**
  String planFocusYesterdayMessage(int count);

  /// No description provided for @planFocusMoveAndStart.
  ///
  /// In en, this message translates to:
  /// **'Move and start'**
  String get planFocusMoveAndStart;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @planRolloverTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfinished tasks'**
  String get planRolloverTitle;

  /// No description provided for @planRolloverMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task from the last few days is still open.} other{{count} tasks from the last few days are still open.}}'**
  String planRolloverMessage(int count);

  /// No description provided for @planRolloverMove.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Move to today} =1{Move 1 task to today} other{Move {count} tasks to today}}'**
  String planRolloverMove(int count);

  /// No description provided for @planRolloverNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get planRolloverNotNow;

  /// No description provided for @planRolloverSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'You can turn this question off in the settings.'**
  String get planRolloverSettingsHint;

  /// No description provided for @settingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get settingsGoals;

  /// No description provided for @settingsDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily focus goal'**
  String get settingsDailyGoal;

  /// No description provided for @settingsDailyGoalHint.
  ///
  /// In en, this message translates to:
  /// **'Focus time to aim for on a working day. Shown as a ring in the plan.'**
  String get settingsDailyGoalHint;

  /// No description provided for @settingsGoalOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsGoalOff;

  /// No description provided for @settingsWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'Working days'**
  String get settingsWorkingDays;

  /// No description provided for @settingsWorkingDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Days off neither break nor extend a streak.'**
  String get settingsWorkingDaysHint;

  /// No description provided for @planGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'Today’s focus: {focus} of {goal}'**
  String planGoalProgress(String focus, String goal);

  /// No description provided for @planGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached: {focus} of {goal}'**
  String planGoalReached(String focus, String goal);

  /// No description provided for @statsCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statsCurrentStreak;

  /// No description provided for @statsLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statsLongestStreak;

  /// No description provided for @statsStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String statsStreakDays(int count);

  /// No description provided for @statsStreakHint.
  ///
  /// In en, this message translates to:
  /// **'Working days with {goal} of focus'**
  String statsStreakHint(String goal);

  /// No description provided for @statsGoalDays.
  ///
  /// In en, this message translates to:
  /// **'Goal days in {year}'**
  String statsGoalDays(String year);

  /// No description provided for @statsGoalDaysTooltip.
  ///
  /// In en, this message translates to:
  /// **'{month}: {count, plural, =0{no goal days} =1{1 goal day} other{{count} goal days}}'**
  String statsGoalDaysTooltip(String month, int count);

  /// No description provided for @statsGoalOff.
  ///
  /// In en, this message translates to:
  /// **'Set a daily focus goal in the settings to see your streaks.'**
  String get statsGoalOff;

  /// No description provided for @finishedSummary.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get finishedSummary;

  /// No description provided for @finishedFocusTime.
  ///
  /// In en, this message translates to:
  /// **'Focus time'**
  String get finishedFocusTime;

  /// No description provided for @finishedTasksDone.
  ///
  /// In en, this message translates to:
  /// **'Tasks done'**
  String get finishedTasksDone;

  /// No description provided for @finishedGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get finishedGoal;

  /// No description provided for @finishedGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Reached ({goal})'**
  String finishedGoalReached(String goal);

  /// No description provided for @finishedGoalNotReached.
  ///
  /// In en, this message translates to:
  /// **'Not reached ({focus} of {goal})'**
  String finishedGoalNotReached(String focus, String goal);

  /// No description provided for @finishedStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get finishedStreak;

  /// No description provided for @notificationGoalReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached'**
  String get notificationGoalReachedTitle;

  /// No description provided for @notificationGoalReachedBody.
  ///
  /// In en, this message translates to:
  /// **'You focused for {goal} today.'**
  String notificationGoalReachedBody(String goal);

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// No description provided for @settingsCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Group tasks, filter the plan and focus on one category.'**
  String get settingsCategoriesHint;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Add one to group your tasks, e.g. “Work” or “Study”.'**
  String get categoriesEmpty;

  /// No description provided for @categoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoriesAdd;

  /// No description provided for @categoriesNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoriesNewTitle;

  /// No description provided for @categoriesEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoriesEditTitle;

  /// No description provided for @categoriesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoriesNameLabel;

  /// No description provided for @categoriesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get categoriesNameRequired;

  /// No description provided for @categoriesNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists.'**
  String get categoriesNameTaken;

  /// No description provided for @categoriesColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoriesColor;

  /// No description provided for @categoriesActions.
  ///
  /// In en, this message translates to:
  /// **'Category actions'**
  String get categoriesActions;

  /// No description provided for @categoriesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get categoriesEdit;

  /// No description provided for @categoriesArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get categoriesArchive;

  /// No description provided for @categoriesRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get categoriesRestore;

  /// No description provided for @categoriesArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get categoriesArchived;

  /// No description provided for @categoriesArchivedHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden in the plan and the task form. Their tasks keep the category.'**
  String get categoriesArchivedHint;

  /// No description provided for @categoriesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get categoriesDeleteTitle;

  /// No description provided for @categoriesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be deleted. Its tasks stay, without a category. Tracked time stays in the statistics.'**
  String categoriesDeleteMessage(String name);

  /// No description provided for @categoriesReorderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get categoriesReorderTooltip;

  /// No description provided for @categoryColorName.
  ///
  /// In en, this message translates to:
  /// **'{color, select, red{Red} orange{Orange} yellow{Yellow} green{Green} teal{Teal} cyan{Cyan} blue{Blue} indigo{Indigo} purple{Purple} pink{Pink} other{Color}}'**
  String categoryColorName(String color);

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String categoryLabel(String name);

  /// No description provided for @taskFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskFormCategory;

  /// No description provided for @taskFormCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get taskFormCategoryNone;

  /// No description provided for @taskFormCategoryNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get taskFormCategoryNew;

  /// No description provided for @planFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get planFilterAll;

  /// No description provided for @planShowList.
  ///
  /// In en, this message translates to:
  /// **'Show as list'**
  String get planShowList;

  /// No description provided for @planShowBoard.
  ///
  /// In en, this message translates to:
  /// **'Show as board'**
  String get planShowBoard;

  /// No description provided for @planFocusOnCategory.
  ///
  /// In en, this message translates to:
  /// **'Focus on {name}'**
  String planFocusOnCategory(String name);

  /// No description provided for @planNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get planNoCategory;

  /// No description provided for @planBoardDropHere.
  ///
  /// In en, this message translates to:
  /// **'Drop tasks here'**
  String get planBoardDropHere;

  /// No description provided for @planBoardDragTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drag to another category'**
  String get planBoardDragTooltip;

  /// No description provided for @planNoTasksInCategory.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this category for this day.'**
  String get planNoTasksInCategory;

  /// No description provided for @planCategoryOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none open} =1{1 open} other{{count} open}}'**
  String planCategoryOpenTasks(int count);

  /// No description provided for @statsByCategory.
  ///
  /// In en, this message translates to:
  /// **'Focus time per category'**
  String get statsByCategory;

  /// No description provided for @statsNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get statsNoCategory;

  /// No description provided for @focusTitleCategory.
  ///
  /// In en, this message translates to:
  /// **'Focus: {name}'**
  String focusTitleCategory(String name);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
