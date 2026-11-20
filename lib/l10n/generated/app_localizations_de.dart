// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Focused Task';

  @override
  String get navPlan => 'Planen';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navStatistics => 'Statistik';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get calendarViewWeek => 'Woche';

  @override
  String get calendarViewMonth => 'Monat';

  @override
  String get calendarPreviousWeek => 'Vorherige Woche';

  @override
  String get calendarNextWeek => 'Nächste Woche';

  @override
  String get calendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get calendarNextMonth => 'Nächster Monat';

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
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed von $total Aufgaben erledigt', one: '$completed von 1 Aufgabe erledigt');
    return '$_temp0';
  }

  @override
  String calendarFocusTime(String time) {
    return 'Fokuszeit $time';
  }

  @override
  String get calendarNoTasks => 'Keine Aufgaben';

  @override
  String get calendarOpenDay => 'Im Plan öffnen';

  @override
  String get calendarMoveTo => 'Verschieben nach…';

  @override
  String calendarMoveTaskTitle(String title) {
    return '„$title“ verschieben nach';
  }

  @override
  String get calendarOtherDate => 'Anderes Datum…';

  @override
  String calendarLoadError(String error) {
    return 'Der Kalender konnte nicht geladen werden: $error';
  }

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonToday => 'Heute';

  @override
  String get commonTomorrow => 'Morgen';

  @override
  String get commonYesterday => 'Gestern';

  @override
  String commonListItem(String item) {
    return '• $item';
  }

  @override
  String commonMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String commonHours(int hours) {
    return '$hours Std.';
  }

  @override
  String commonHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String commonPercent(int percent) {
    return '$percent %';
  }

  @override
  String get planPickDayTooltip => 'Tag wählen';

  @override
  String get planPreviousDay => 'Vorheriger Tag';

  @override
  String get planNextDay => 'Nächster Tag';

  @override
  String get planStartFocus => 'Fokus starten';

  @override
  String get planNoTasks => 'Keine Aufgaben für diesen Tag.';

  @override
  String planLoadError(String error) {
    return 'Die Aufgaben konnten nicht geladen werden: $error';
  }

  @override
  String get planAddTask => 'Aufgabe hinzufügen';

  @override
  String get taskMarkComplete => 'Aufgabe als erledigt markieren';

  @override
  String get taskMarkIncomplete => 'Aufgabe als offen markieren';

  @override
  String get taskNoDescription => 'Keine Beschreibung';

  @override
  String taskTodoProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get taskMoveOrCopyTooltip => 'Verschieben oder kopieren';

  @override
  String get taskMoveToToday => 'Nach heute verschieben';

  @override
  String get taskMoveTo => 'Verschieben nach …';

  @override
  String get taskCopyTo => 'Kopieren nach …';

  @override
  String taskMovedToDate(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben nach $date verschoben', one: 'Aufgabe nach $date verschoben');
    return '$_temp0';
  }

  @override
  String taskMovedToToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben nach heute verschoben', one: 'Aufgabe nach heute verschoben');
    return '$_temp0';
  }

  @override
  String taskCopyToDateTitle(String date) {
    return 'Kopieren nach $date';
  }

  @override
  String get taskCopyQuestion => 'Legt eine neue Aufgabe mit demselben Titel, denselben Details und Unteraufgaben an. Das Original bleibt, wo es ist.';

  @override
  String get taskEditTooltip => 'Aufgabe bearbeiten';

  @override
  String get taskKeepCompletedTodos => 'Erledigte Unteraufgaben behalten';

  @override
  String get taskKeepCompletedTodosHint => 'Wenn aus, werden alle Unteraufgaben zurückgesetzt';

  @override
  String get taskSubtractTimeSpent => 'Bisherige Zeit abziehen';

  @override
  String get taskSubtractTimeSpentHint => 'Verkürzt die neue Zieldauer um die bereits erfasste Zeit';

  @override
  String get taskFormAddTitle => 'Aufgabe hinzufügen';

  @override
  String get taskFormEditTitle => 'Aufgabe bearbeiten';

  @override
  String get taskFormDuplicateTooltip => 'Aufgabe duplizieren';

  @override
  String get taskFormDeleteTooltip => 'Aufgabe löschen';

  @override
  String get taskFormTitleLabel => 'Titel';

  @override
  String get taskFormDescriptionLabel => 'Beschreibung';

  @override
  String get taskFormSubTasks => 'Unteraufgaben';

  @override
  String get taskFormAddSubTaskTooltip => 'Unteraufgabe hinzufügen';

  @override
  String get taskFormDeleteSubTaskTooltip => 'Unteraufgabe löschen';

  @override
  String get taskFormTrackedTime => 'Erfasste Zeit';

  @override
  String get taskFormAddTime => 'Zeit hinzufügen';

  @override
  String get taskFormAddTimeTitle => 'Erfasste Zeit hinzufügen';

  @override
  String get taskFormSave => 'Aufgabe speichern';

  @override
  String get focusTitle => 'Fokus';

  @override
  String get focusExitTooltip => 'Fokus beenden';

  @override
  String get focusTimeIsUp => 'Die Zeit ist um!';

  @override
  String get focusTargetReached => 'Du hast die Zieldauer für diese Aufgabe erreicht.';

  @override
  String get focusStopAlarmAndContinue => 'Alarm stoppen & weitermachen';

  @override
  String get focusNoUnfinishedTasks => 'Keine offenen Aufgaben für heute.';

  @override
  String get focusCompleteTask => 'Aufgabe abschließen';

  @override
  String get focusExit => 'Fokus beenden';

  @override
  String get focusTimerSession => 'Sitzung';

  @override
  String get focusTimerTask => 'Aufgabe';

  @override
  String get focusTimerOverdue => 'Überzogen';

  @override
  String get focusTimerRemaining => 'Verbleibend';

  @override
  String focusAlarmNotificationBody(String taskTitle) {
    return 'Du hast die Zieldauer erreicht für: $taskTitle';
  }

  @override
  String get focusAlarmStopButton => 'Alarm stoppen';

  @override
  String get pauseTitle => 'Pausiert';

  @override
  String get pauseMessage => 'Der Fokus wurde pausiert, weil die App im Hintergrund war.';

  @override
  String get pauseResume => 'Fokus fortsetzen';

  @override
  String get finishedTitle => 'Alles erledigt';

  @override
  String get finishedHeadline => 'Feierabend für heute!';

  @override
  String get finishedMessage => 'Gute Arbeit – du hast alles erledigt, was für heute geplant war.';

  @override
  String get finishedViewStatistics => 'Statistik ansehen';

  @override
  String get finishedBackToPlan => 'Zurück zum Plan';

  @override
  String get recoveryTitle => 'Unterbrochene Sitzung wiederherstellen?';

  @override
  String get recoveryClosedWhileFocusing => 'Die App wurde geschlossen, während du an folgenden Aufgaben gearbeitet hast:';

  @override
  String get recoveryQuestion => 'Wie viel dieser Zeit möchtest du behalten?';

  @override
  String get recoveryDiscard => 'Verwerfen';

  @override
  String get recoveryDeletedTask => '(gelöschte Aufgabe)';

  @override
  String recoveryUntilNow(String duration) {
    return 'Bis jetzt ($duration)';
  }

  @override
  String recoveryUntilLastActivity(String duration) {
    return 'Bis zur letzten Aktivität ($duration)';
  }

  @override
  String get statsTitle => 'Statistik';

  @override
  String get statsDay => 'Tag';

  @override
  String get statsWeek => 'Woche';

  @override
  String get statsMonth => 'Monat';

  @override
  String get statsYear => 'Jahr';

  @override
  String get statsUnavailable => 'Noch keine Statistik verfügbar.';

  @override
  String get statsPreviousPeriod => 'Vorheriger Zeitraum';

  @override
  String get statsNextPeriod => 'Nächster Zeitraum';

  @override
  String get statsCurrentPeriod => 'Zum aktuellen Zeitraum';

  @override
  String statsWeekLabel(String start, String end) {
    return '$start – $end';
  }

  @override
  String get statsEmptyTitle => 'Keine Daten für diesen Zeitraum';

  @override
  String get statsEmptyMessage => 'Plane Aufgaben und arbeite sie im Fokusmodus ab. Deine Fokuszeit, erledigte Aufgaben und besten Stunden erscheinen dann hier.';

  @override
  String statsTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed/$total Aufgaben erledigt', one: '$completed/1 Aufgabe erledigt');
    return '$_temp0';
  }

  @override
  String get statsFocusTime => 'Fokuszeit';

  @override
  String get statsAveragePerDay => 'Ø pro Tag';

  @override
  String statsElapsedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'über $days bisherige Tage', one: 'über 1 bisherigen Tag', zero: 'Zeitraum hat noch nicht begonnen');
    return '$_temp0';
  }

  @override
  String get statsSessions => 'Sitzungen';

  @override
  String statsAverageSession(String duration) {
    return 'Ø $duration pro Sitzung';
  }

  @override
  String get statsCompletion => 'Erledigt';

  @override
  String get statsNoTasks => 'Keine Aufgaben geplant';

  @override
  String get statsInterruptions => 'Unterbrechungen pro Fokusstunde';

  @override
  String statsInterruptionsValue(double value) {
    final intl.NumberFormat valueNumberFormat = intl.NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString';
  }

  @override
  String get statsNoValue => '–';

  @override
  String get statsFocusPerHour => 'Fokuszeit pro Stunde';

  @override
  String get statsFocusPerDay => 'Fokuszeit pro Tag';

  @override
  String get statsFocusPerMonth => 'Fokuszeit pro Monat';

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
  String get statsPlannedVsActual => 'Geplant vs. tatsächlich';

  @override
  String get statsPlanned => 'Geplant';

  @override
  String get statsTracked => 'Erfasst';

  @override
  String statsTargetTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben mit Zielzeit', one: '1 Aufgabe mit Zielzeit');
    return '$_temp0';
  }

  @override
  String get statsNoTargets => 'Gib Aufgaben eine Zielzeit, um deinen Plan mit der tatsächlich benötigten Zeit zu vergleichen.';

  @override
  String statsEstimationAccuracy(int percent) {
    return 'Erledigte Aufgaben brauchten $percent % ihrer Zielzeit (Median).';
  }

  @override
  String get statsBestHours => 'Beste Fokuszeiten';

  @override
  String get statsTopTasks => 'Top-Aufgaben';

  @override
  String get statsDeletedTask => 'Gelöschte Aufgabe';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsPlanning => 'Planung';

  @override
  String get settingsAskToMoveUnfinished => 'Unerledigte Aufgaben verschieben?';

  @override
  String get settingsAskToMoveUnfinishedHint => 'Beim ersten Start des Tages anbieten, offene Aufgaben der letzten 7 Tage nach heute zu verschieben';

  @override
  String get settingsDataRetention => 'Datenaufbewahrung';

  @override
  String get settingsDataRetentionInfo => 'Gelöschte Aufgaben verschwinden auch aus der Statistik. Aufgaben mit einer offenen Sitzung werden nie gelöscht.';

  @override
  String get settingsAutoCleanup => 'Alte erledigte Aufgaben automatisch löschen';

  @override
  String settingsAutoCleanupHint(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Bei jedem App-Start werden erledigte Aufgaben gelöscht, die älter als $days Tage sind.',
      one: 'Bei jedem App-Start werden erledigte Aufgaben gelöscht, die älter als 1 Tag sind.',
    );
    return '$_temp0';
  }

  @override
  String settingsRetentionPeriod(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'Aufbewahrung: $days Tage', one: 'Aufbewahrung: 1 Tag');
    return '$_temp0';
  }

  @override
  String get settingsDecrease => 'Verringern';

  @override
  String get settingsIncrease => 'Erhöhen';

  @override
  String get settingsCleanNow => 'Jetzt aufräumen';

  @override
  String settingsNothingToClean(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: 'Keine erledigten Aufgaben älter als $days Tage.', one: 'Keine erledigten Aufgaben älter als 1 Tag.');
    return '$_temp0';
  }

  @override
  String settingsCleanupDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben gelöscht.', one: '1 Aufgabe gelöscht.', zero: 'Nichts gelöscht.');
    return '$_temp0';
  }

  @override
  String get settingsCleanupFailed => 'Aufräumen fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get settingsCleanupConfirmTitle => 'Alte Aufgaben löschen?';

  @override
  String settingsCleanupConfirmMessage(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count erledigte Aufgaben', one: '1 erledigte Aufgabe');
    String _temp1 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days Tage', one: '1 Tag');
    String _temp2 = intl.Intl.pluralLogic(count, locale: localeName, other: 'werden', one: 'wird');
    return '$_temp0, älter als $_temp1, $_temp2 endgültig gelöscht – einschließlich der erfassten Zeit in der Statistik.';
  }

  @override
  String get settingsFocusMode => 'Fokus';

  @override
  String get settingsKeepScreenAwake => 'Bildschirm anlassen';

  @override
  String get settingsKeepScreenAwakeHint => 'Verhindert, dass sich der Bildschirm während einer Fokus-Sitzung ausschaltet.';

  @override
  String get settingsPauseOnBackground => 'Pausieren, wenn minimiert oder gesperrt';

  @override
  String get settingsPauseOnBackgroundHint => 'Pausiert die Sitzung, wenn die App in den Hintergrund geht oder der Bildschirm ausgeht.';

  @override
  String get planTitle => 'Planen';

  @override
  String get planSettingsTooltip => 'Einstellungen';

  @override
  String get planStatisticsTooltip => 'Statistik';

  @override
  String get planStartFocusTooltip => 'Fokus starten';

  @override
  String planSelectedDay(String day) {
    return 'Ausgewählter Tag: $day';
  }

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsNotificationsDenied =>
      'Benachrichtigungen sind für Focused Task ausgeschaltet. Erlaube sie in den Systemeinstellungen, um bei Ablauf der Zieldauer benachrichtigt zu werden.';

  @override
  String get settingsNotificationsAskAgain => 'Erneut fragen';

  @override
  String get settingsNotificationsTest => 'Testbenachrichtigung';

  @override
  String get settingsNotificationsTestHint => 'Kommt nach 10 Sekunden – du kannst die App solange verlassen.';

  @override
  String get settingsNotificationsTestButton => 'Senden';

  @override
  String get settingsNotificationsTestScheduled => 'Testbenachrichtigung geplant.';

  @override
  String get notificationTestBody => 'Benachrichtigungen funktionieren.';

  @override
  String get notificationOpenAction => 'Öffnen';

  @override
  String get notificationChannelFocusAlarm => 'Fokus-Alarm';

  @override
  String get notificationChannelReminders => 'Erinnerungen';

  @override
  String get notificationChannelBreaks => 'Pausen';

  @override
  String get taskFormTitleRequired => 'Bitte gib einen Titel ein.';

  @override
  String get taskFormDateLabel => 'Datum';

  @override
  String get taskFormDurationLabel => 'Zieldauer';

  @override
  String get taskFormDurationNone => 'Keine';

  @override
  String get taskFormDurationCustom => 'Eigene';

  @override
  String get taskFormHours => 'Stunden';

  @override
  String get taskFormMinutes => 'Minuten';

  @override
  String get taskFormDurationMax => 'Höchstens 12 Stunden.';

  @override
  String get taskFormNewSubTask => 'Unteraufgabe hinzufügen';

  @override
  String get taskFormPriority => 'Priorität';

  @override
  String get priorityLow => 'Niedrig';

  @override
  String get priorityMedium => 'Mittel';

  @override
  String get priorityHigh => 'Hoch';

  @override
  String get taskPriorityMedium => 'Mittlere Priorität';

  @override
  String get taskPriorityHigh => 'Hohe Priorität';

  @override
  String get taskFormDeleteTitle => 'Aufgabe löschen?';

  @override
  String taskFormDeleteMessage(String title) {
    return '„$title“ wird endgültig gelöscht.';
  }

  @override
  String taskFormDeleteMessageTracked(String title, String duration) {
    return '„$title“ und $duration Std. erfasste Zeit werden endgültig gelöscht. Die Zeit zählt weiter in deiner Statistik.';
  }

  @override
  String get taskFormDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get taskFormDiscardMessage => 'Deine Änderungen an dieser Aufgabe gehen verloren.';

  @override
  String get taskFormKeepEditing => 'Weiter bearbeiten';

  @override
  String get taskFormDiscard => 'Verwerfen';

  @override
  String get focusSkip => 'Überspringen';

  @override
  String get focusUpNext => 'Als Nächstes';

  @override
  String get taskFocusTooltip => 'An dieser Aufgabe arbeiten';

  @override
  String get planFocusStart => 'Starten';

  @override
  String get planFocusAheadTitle => 'Vorarbeiten?';

  @override
  String get planFocusAheadTomorrow => 'Jetzt schon an den Aufgaben von morgen arbeiten?';

  @override
  String planFocusAheadDate(String date) {
    return 'Jetzt an den Aufgaben vom $date arbeiten?';
  }

  @override
  String get planFocusMoveTitle => 'Nach heute verschieben?';

  @override
  String planFocusMoveMessage(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die $count offenen Aufgaben vom $date werden nach heute verschoben, dann startet der Fokus.',
      one: 'Die offene Aufgabe vom $date wird nach heute verschoben, dann startet der Fokus.',
    );
    return '$_temp0';
  }

  @override
  String get planFocusYesterdayTitle => 'Heute ist nichts offen';

  @override
  String planFocusYesterdayMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben von gestern sind noch offen. Nach heute verschieben und daran arbeiten?',
      one: '1 Aufgabe von gestern ist noch offen. Nach heute verschieben und daran arbeiten?',
    );
    return '$_temp0';
  }

  @override
  String get planFocusMoveAndStart => 'Verschieben und starten';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get planRolloverTitle => 'Unerledigte Aufgaben';

  @override
  String planRolloverMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben der letzten Tage sind noch offen.', one: '1 Aufgabe der letzten Tage ist noch offen.');
    return '$_temp0';
  }

  @override
  String planRolloverMove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben nach heute verschieben',
      one: '1 Aufgabe nach heute verschieben',
      zero: 'Nach heute verschieben',
    );
    return '$_temp0';
  }

  @override
  String get planRolloverNotNow => 'Nicht jetzt';

  @override
  String get planRolloverSettingsHint => 'Diese Frage lässt sich in den Einstellungen abschalten.';

  @override
  String get settingsGoals => 'Ziele';

  @override
  String get settingsDailyGoal => 'Tägliches Fokusziel';

  @override
  String get settingsDailyGoalHint => 'Fokuszeit, die du an einem Arbeitstag erreichen möchtest. Wird im Plan als Ring angezeigt.';

  @override
  String get settingsGoalOff => 'Aus';

  @override
  String get settingsWorkingDays => 'Arbeitstage';

  @override
  String get settingsWorkingDaysHint => 'Freie Tage unterbrechen keine Serie und verlängern sie nicht.';

  @override
  String planGoalProgress(String focus, String goal) {
    return 'Fokus heute: $focus von $goal';
  }

  @override
  String planGoalReached(String focus, String goal) {
    return 'Tagesziel erreicht: $focus von $goal';
  }

  @override
  String get statsCurrentStreak => 'Aktuelle Serie';

  @override
  String get statsLongestStreak => 'Längste Serie';

  @override
  String statsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Tage', one: '1 Tag');
    return '$_temp0';
  }

  @override
  String statsStreakHint(String goal) {
    return 'Arbeitstage mit $goal Fokus';
  }

  @override
  String statsGoalDays(String year) {
    return 'Zieltage $year';
  }

  @override
  String statsGoalDaysTooltip(String month, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Zieltage', one: '1 Zieltag', zero: 'keine Zieltage');
    return '$month: $_temp0';
  }

  @override
  String get statsGoalOff => 'Lege in den Einstellungen ein tägliches Fokusziel fest, um deine Serien zu sehen.';

  @override
  String get finishedSummary => 'Heute';

  @override
  String get finishedFocusTime => 'Fokuszeit';

  @override
  String get finishedTasksDone => 'Erledigte Aufgaben';

  @override
  String get finishedGoal => 'Tagesziel';

  @override
  String finishedGoalReached(String goal) {
    return 'Erreicht ($goal)';
  }

  @override
  String finishedGoalNotReached(String focus, String goal) {
    return 'Nicht erreicht ($focus von $goal)';
  }

  @override
  String get finishedStreak => 'Serie';

  @override
  String get notificationGoalReachedTitle => 'Tagesziel erreicht';

  @override
  String notificationGoalReachedBody(String goal) {
    return 'Du warst heute $goal fokussiert.';
  }

  @override
  String get settingsCategories => 'Kategorien';

  @override
  String get settingsCategoriesHint => 'Aufgaben gruppieren, den Plan filtern und dich auf eine Kategorie konzentrieren.';

  @override
  String get categoriesTitle => 'Kategorien';

  @override
  String get categoriesEmpty => 'Noch keine Kategorien. Lege eine an, um deine Aufgaben zu gruppieren, z. B. „Arbeit“ oder „Studium“.';

  @override
  String get categoriesAdd => 'Kategorie hinzufügen';

  @override
  String get categoriesNewTitle => 'Neue Kategorie';

  @override
  String get categoriesEditTitle => 'Kategorie bearbeiten';

  @override
  String get categoriesNameLabel => 'Name';

  @override
  String get categoriesNameRequired => 'Bitte gib einen Namen ein.';

  @override
  String get categoriesNameTaken => 'Es gibt schon eine Kategorie mit diesem Namen.';

  @override
  String get categoriesColor => 'Farbe';

  @override
  String get categoriesActions => 'Aktionen der Kategorie';

  @override
  String get categoriesEdit => 'Bearbeiten';

  @override
  String get categoriesArchive => 'Archivieren';

  @override
  String get categoriesRestore => 'Wiederherstellen';

  @override
  String get categoriesArchived => 'Archiviert';

  @override
  String get categoriesArchivedHint => 'Im Plan und im Aufgabenformular ausgeblendet. Ihre Aufgaben behalten die Kategorie.';

  @override
  String get categoriesDeleteTitle => 'Kategorie löschen?';

  @override
  String categoriesDeleteMessage(String name) {
    return '„$name“ wird gelöscht. Ihre Aufgaben bleiben erhalten, ohne Kategorie. Die erfasste Zeit bleibt in der Statistik.';
  }

  @override
  String get categoriesReorderTooltip => 'Ziehen zum Sortieren';

  @override
  String categoryColorName(String color) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'red': 'Rot',
      'orange': 'Orange',
      'yellow': 'Gelb',
      'green': 'Grün',
      'teal': 'Petrol',
      'cyan': 'Cyan',
      'blue': 'Blau',
      'indigo': 'Indigo',
      'purple': 'Lila',
      'pink': 'Pink',
      'other': 'Farbe',
    });
    return '$_temp0';
  }

  @override
  String categoryLabel(String name) {
    return 'Kategorie: $name';
  }

  @override
  String get taskFormCategory => 'Kategorie';

  @override
  String get taskFormCategoryNone => 'Keine';

  @override
  String get taskFormCategoryNew => 'Neu';

  @override
  String get planFilterAll => 'Alle';

  @override
  String get planShowList => 'Als Liste anzeigen';

  @override
  String get planShowBoard => 'Als Board anzeigen';

  @override
  String planFocusOnCategory(String name) {
    return 'Fokus auf $name';
  }

  @override
  String get planNoCategory => 'Ohne Kategorie';

  @override
  String get planBoardDropHere => 'Aufgaben hierher ziehen';

  @override
  String get planBoardDragTooltip => 'In eine andere Kategorie ziehen';

  @override
  String get planNoTasksInCategory => 'Keine Aufgaben dieser Kategorie an diesem Tag.';

  @override
  String planCategoryOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count offen', one: '1 offen', zero: 'keine offen');
    return '$_temp0';
  }

  @override
  String planCategoryProgress(int done, int total, int percent) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$total Aufgaben', one: '1 Aufgabe');
    return '$done von $_temp0 erledigt ($percent %)';
  }

  @override
  String planCategoryTracked(String duration) {
    return '$duration erfasst';
  }

  @override
  String get statsByCategory => 'Fokuszeit pro Kategorie';

  @override
  String get statsNoCategory => 'Ohne Kategorie';

  @override
  String focusTitleCategory(String name) {
    return 'Fokus: $name';
  }

  @override
  String get settingsIntervals => 'In Intervallen arbeiten';

  @override
  String get settingsIntervalsHint => 'Wie Pomodoro: eine feste Zeit fokussiert arbeiten, dann kurz Pause machen.';

  @override
  String get settingsIntervalWork => 'Arbeitsintervall';

  @override
  String get settingsIntervalShortBreak => 'Kurze Pause';

  @override
  String get settingsIntervalLongBreak => 'Lange Pause';

  @override
  String get settingsIntervalLongBreakEvery => 'Lange Pause nach';

  @override
  String settingsIntervalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Intervallen', one: '1 Intervall');
    return '$_temp0';
  }

  @override
  String get settingsIntervalAutoStart => 'Nach einer Pause automatisch weitermachen';

  @override
  String get settingsIntervalAutoStartHint => 'Sonst wartet der Fokus, bis du bereit bist.';

  @override
  String focusBreakIn(String duration) {
    return 'Pause in $duration';
  }

  @override
  String get breakShortTitle => 'Kurze Pause';

  @override
  String get breakLongTitle => 'Lange Pause';

  @override
  String get breakHint => 'Steh auf, streck dich und schau weg vom Bildschirm.';

  @override
  String get breakSkip => 'Pause überspringen';

  @override
  String get breakReadyTitle => 'Bereit?';

  @override
  String breakContinueWith(String task) {
    return 'Weiter mit $task';
  }

  @override
  String get breakContinue => 'Weiter';

  @override
  String get notificationBreakTitle => 'Zeit für eine Pause';

  @override
  String notificationBreakBody(String duration) {
    return 'Mach $duration Pause. Steh auf und schau weg vom Bildschirm.';
  }

  @override
  String get notificationBreakOverTitle => 'Die Pause ist vorbei';

  @override
  String notificationBreakOverBody(String task) {
    return 'Bereit? Weiter mit $task.';
  }

  @override
  String statsBreakTime(String duration) {
    return '+ $duration Pausen';
  }

  @override
  String get settingsMinimalFocusLayout => 'Minimale Fokusansicht';

  @override
  String get settingsMinimalFocusLayoutHint => 'Nur der Timer, die Aufgabe und ihr wichtigster Button. Lässt sich auch im Fokusmodus umschalten.';

  @override
  String get focusDistracted => 'Ich wurde abgelenkt';

  @override
  String focusDistractedNoted(String task) {
    return 'Notiert. Zurück zu $task.';
  }

  @override
  String get focusMinimalLayout => 'Minimale Ansicht';

  @override
  String get focusFullLayout => 'Alles zeigen';

  @override
  String get focusParkThought => 'Gedanken parken…';

  @override
  String get focusThoughtParked => 'Für später geparkt.';

  @override
  String focusAwayFor(String duration) {
    return 'Du warst $duration weg.';
  }

  @override
  String inboxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count geparkte Gedanken', one: '1 geparkter Gedanke');
    return '$_temp0';
  }

  @override
  String get inboxReview => 'Durchsehen';

  @override
  String get inboxTitle => 'Geparkte Gedanken';

  @override
  String get inboxHint => 'Mach Aufgaben daraus oder lass sie los.';

  @override
  String get inboxToTodayTooltip => 'Als Aufgabe für heute anlegen';

  @override
  String get inboxToTomorrowTooltip => 'Als Aufgabe für morgen anlegen';

  @override
  String get inboxDismiss => 'Verwerfen';

  @override
  String get inboxAddedToday => 'Für heute angelegt.';

  @override
  String get inboxAddedTomorrow => 'Für morgen angelegt.';

  @override
  String get inboxDismissed => 'Verworfen.';

  @override
  String get inboxAllReviewed => 'Alles durchgesehen.';

  @override
  String get statsParkedThoughts => 'Geparkte Gedanken';

  @override
  String get statsParkedThoughtReviewed => 'Durchgesehen';
}
