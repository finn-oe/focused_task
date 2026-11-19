import 'package:focused_task/core/utils/date_utils.dart';

/// Layout of the calendar screen.
enum CalendarView {
  week,
  month;

  /// The view named [value] (as in the URL), or `null` if [value] is missing or unknown.
  static CalendarView? tryParse(String? value) => CalendarView.values.asNameMap()[value];
}

/// The period the calendar shows: the week or month containing [anchor], with weeks starting on [firstWeekday] (a
/// [DateTime.weekday] value).
class CalendarPeriod {
  CalendarPeriod({required this.view, required DateTime anchor, required this.firstWeekday}) : anchor = anchor.dateOnly;

  final CalendarView view;

  /// Any day of the period.
  final DateTime anchor;
  final int firstWeekday;

  /// First day of the week, or of the month.
  DateTime get start => view == CalendarView.week ? anchor.startOfWeek(firstWeekday) : anchor.startOfMonth;

  /// Last day of the week, or of the month.
  DateTime get end => view == CalendarView.week ? start.addDays(DateTime.daysPerWeek - 1) : anchor.startOfNextMonth.addDays(-1);

  /// The days shown: the week, or the whole weeks covering the month (4 to 6 rows of 7 days).
  DateRange get visibleRange {
    final first = start.startOfWeek(firstWeekday);
    final last = end.startOfWeek(firstWeekday).addDays(DateTime.daysPerWeek - 1);
    return DateRange(first, last);
  }

  /// All days of [visibleRange], in order.
  List<DateTime> get visibleDays {
    final range = visibleRange;
    return [for (var day = range.start; !day.isAfter(range.end); day = day.nextDay) day];
  }

  /// Whether [day] belongs to the period itself (not just to the visible weeks around a month).
  bool contains(DateTime day) => !day.dateOnly.isBefore(start) && !day.dateOnly.isAfter(end);

  CalendarPeriod get previous => _shifted(-1);

  CalendarPeriod get next => _shifted(1);

  CalendarPeriod _shifted(int periods) {
    final anchor = view == CalendarView.week ? start.addDays(periods * DateTime.daysPerWeek) : DateTime(start.year, start.month + periods);
    return CalendarPeriod(view: view, anchor: anchor, firstWeekday: firstWeekday);
  }

  @override
  bool operator ==(Object other) => other is CalendarPeriod && other.view == view && other.start == start && other.firstWeekday == firstWeekday;

  @override
  int get hashCode => Object.hash(view, start, firstWeekday);
}
