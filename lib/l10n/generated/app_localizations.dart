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

  /// No description provided for @calendarComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Week and month views are coming soon.'**
  String get calendarComingSoon;

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

  /// No description provided for @taskCopyToTodayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy to Today'**
  String get taskCopyToTodayTooltip;

  /// No description provided for @taskEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get taskEditTooltip;

  /// No description provided for @taskCopyToTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to Today'**
  String get taskCopyToTodayTitle;

  /// No description provided for @taskCopyToTodayQuestion.
  ///
  /// In en, this message translates to:
  /// **'Create a copy of this task for today?'**
  String get taskCopyToTodayQuestion;

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

  /// No description provided for @taskFormDuplicateWithoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot duplicate a task without a title'**
  String get taskFormDuplicateWithoutTitle;

  /// No description provided for @taskFormChangeDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change Date'**
  String get taskFormChangeDateTooltip;

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

  /// No description provided for @taskFormNoSubTasks.
  ///
  /// In en, this message translates to:
  /// **'No sub-tasks added.'**
  String get taskFormNoSubTasks;

  /// No description provided for @taskFormEditSubTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit sub-task'**
  String get taskFormEditSubTaskTooltip;

  /// No description provided for @taskFormDeleteSubTaskTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete sub-task'**
  String get taskFormDeleteSubTaskTooltip;

  /// No description provided for @taskFormTargetDuration.
  ///
  /// In en, this message translates to:
  /// **'Target Duration (Optional)'**
  String get taskFormTargetDuration;

  /// No description provided for @taskFormNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get taskFormNoLimit;

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

  /// No description provided for @taskFormTargetDurationValue.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String taskFormTargetDurationValue(int hours, int minutes);

  /// No description provided for @taskFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save Task'**
  String get taskFormSave;

  /// No description provided for @taskFormAddSubTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add sub-task'**
  String get taskFormAddSubTaskTitle;

  /// No description provided for @taskFormEditSubTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit sub-task'**
  String get taskFormEditSubTaskTitle;

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

  /// No description provided for @statsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No stats available yet.'**
  String get statsUnavailable;

  /// No description provided for @statsCompletionScore.
  ///
  /// In en, this message translates to:
  /// **'Completion score'**
  String get statsCompletionScore;

  /// No description provided for @statsCompletionScoreValue.
  ///
  /// In en, this message translates to:
  /// **'{score}%'**
  String statsCompletionScoreValue(double score);

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

  /// No description provided for @statsAverageTaskDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg. task duration'**
  String get statsAverageTaskDuration;

  /// No description provided for @statsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get statsPerDay;

  /// No description provided for @statsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get statsRemaining;

  /// No description provided for @statsTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String statsTaskCount(int count);

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
