import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/tasks/domain/entities/task_schedule.dart';

/// A time of day ([minute] after midnight) in the user's format, e.g. "14:00" or "2:00 PM".
String timeOfDayLabel(BuildContext context, int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// A moment as short as it can be told apart from [now]: the time today, the weekday and time within a week,
/// otherwise the date and time.
String momentLabel(BuildContext context, DateTime moment, {required DateTime now}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final time = timeOfDayLabel(context, moment.hour * 60 + moment.minute);
  final days = now.dateOnly.calendarDaysUntil(moment);
  if (days == 0) return time;
  final day = days > 0 && days < DateTime.daysPerWeek ? DateFormat.E(locale).format(moment) : DateFormat.MMMd(locale).format(moment);
  return '$day $time';
}

/// The day of a deadline for a chip: "Today", "Tomorrow", the weekday within a week, otherwise the date.
String dueDayLabel(BuildContext context, DateTime due, {required DateTime now}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return switch (now.dateOnly.calendarDaysUntil(due)) {
    0 => timeOfDayLabel(context, due.hour * 60 + due.minute),
    1 => l10n.commonTomorrow,
    final days when days > 1 && days < DateTime.daysPerWeek => DateFormat.E(locale).format(due),
    _ => DateFormat.MMMd(locale).format(due),
  };
}

/// One line for the form's "Schedule & reminder" tile, e.g. "Start 14:00 · Due Fri 17:00 · 15 min before".
String scheduleSummary(BuildContext context, TaskSchedule schedule, ReminderSettings settings, {required DateTime now}) {
  final l10n = context.l10n;
  if (schedule.isEmpty) return l10n.taskFormScheduleNotSet;
  final start = schedule.startMinute;
  final due = schedule.dueAt(defaultDueMinute: settings.defaultDueMinute);
  return [
    if (start != null) l10n.taskScheduleStart(timeOfDayLabel(context, start)),
    if (due != null) l10n.taskScheduleDue(momentLabel(context, due, now: now)),
    if (schedule.reminderOff || !settings.taskReminders) l10n.taskScheduleReminderOff else l10n.taskScheduleReminderBefore(l10n.durationLabel(schedule.lead(settings.defaultLead))),
  ].join(' · ');
}
