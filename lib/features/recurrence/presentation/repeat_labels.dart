import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/features/recurrence/domain/repeat_pattern.dart';

/// One line for a repeat (#24), e.g. "Weekly on Mon, Thu, until Fri, 3 Jul 2026"; "Never" for `null`.
String repeatSummary(BuildContext context, RepeatPattern? repeat) {
  final l10n = context.l10n;
  if (repeat == null) return l10n.taskRepeatNever;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final first = firstDayOfWeek(context);
  int position(int weekday) => (weekday - first) % DateTime.daysPerWeek;
  final pattern = switch (repeat.frequency) {
    RepeatFrequency.daily => l10n.taskRepeatDaily,
    RepeatFrequency.weekdays => l10n.taskRepeatWeekdays,
    // 2024-01-01 is a Monday.
    RepeatFrequency.weekly => l10n.taskRepeatWeeklyOn(
      (repeat.weekdays.toList()..sort((a, b) => position(a).compareTo(position(b)))).map((weekday) => DateFormat.E(locale).format(DateTime(2024, 1, weekday))).join(', '),
    ),
    RepeatFrequency.interval => l10n.taskRepeatEveryDays(repeat.intervalDays),
    RepeatFrequency.monthly => l10n.taskRepeatMonthly(repeat.monthDay),
  };
  final end = repeat.endDate;
  return end == null ? pattern : l10n.taskRepeatUntil(pattern, DateFormat.yMMMEd(locale).format(end));
}
