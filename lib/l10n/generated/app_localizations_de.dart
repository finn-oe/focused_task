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
  String commonPercent(int percent) {
    return '$percent %';
  }

  @override
  String get planTitle => 'Planen';

  @override
  String get planSettingsTooltip => 'Einstellungen';

  @override
  String get planPickDayTooltip => 'Tag wählen';

  @override
  String get planStatisticsTooltip => 'Statistik';

  @override
  String get planStartFocusTooltip => 'Fokus starten';

  @override
  String planSelectedDay(String day) {
    return 'Ausgewählter Tag: $day';
  }

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
  String get taskCopyToTodayTooltip => 'Nach heute kopieren';

  @override
  String get taskEditTooltip => 'Aufgabe bearbeiten';

  @override
  String get taskCopyToTodayTitle => 'Nach heute verschieben';

  @override
  String get taskCopyToTodayQuestion => 'Eine Kopie dieser Aufgabe für heute anlegen?';

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
  String get taskFormDuplicateWithoutTitle => 'Eine Aufgabe ohne Titel kann nicht dupliziert werden';

  @override
  String get taskFormChangeDateTooltip => 'Datum ändern';

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
  String get taskFormNoSubTasks => 'Keine Unteraufgaben.';

  @override
  String get taskFormEditSubTaskTooltip => 'Unteraufgabe bearbeiten';

  @override
  String get taskFormDeleteSubTaskTooltip => 'Unteraufgabe löschen';

  @override
  String get taskFormTargetDuration => 'Zieldauer (optional)';

  @override
  String get taskFormNoLimit => 'Keine Begrenzung';

  @override
  String get taskFormTrackedTime => 'Erfasste Zeit';

  @override
  String get taskFormAddTime => 'Zeit hinzufügen';

  @override
  String get taskFormAddTimeTitle => 'Erfasste Zeit hinzufügen';

  @override
  String taskFormTargetDurationValue(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get taskFormSave => 'Aufgabe speichern';

  @override
  String get taskFormAddSubTaskTitle => 'Unteraufgabe hinzufügen';

  @override
  String get taskFormEditSubTaskTitle => 'Unteraufgabe bearbeiten';

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
  String get statsUnavailable => 'Noch keine Statistik verfügbar.';

  @override
  String get statsCompletionScore => 'Erledigungsquote';

  @override
  String statsCompletionScoreValue(double score) {
    final intl.NumberFormat scoreNumberFormat = intl.NumberFormat.decimalPatternDigits(locale: localeName, decimalDigits: 1);
    final String scoreString = scoreNumberFormat.format(score);

    return '$scoreString %';
  }

  @override
  String statsTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: '$completed/$total Aufgaben erledigt', one: '$completed/1 Aufgabe erledigt');
    return '$_temp0';
  }

  @override
  String get statsFocusTime => 'Fokuszeit';

  @override
  String get statsAverageTaskDuration => 'Ø Dauer pro Aufgabe';

  @override
  String get statsPerDay => 'Pro Tag';

  @override
  String get statsRemaining => 'Offen';

  @override
  String statsTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Aufgaben', one: '1 Aufgabe');
    return '$_temp0';
  }

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
}
