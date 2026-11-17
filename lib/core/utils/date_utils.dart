/// Calendar-date helpers.
///
/// A task's day is a *calendar date*, not a point in time. Never compute day boundaries with
/// `Duration(days: n)`: days are 23 or 25 hours long on daylight-saving switches. These helpers use
/// calendar arithmetic (`DateTime(y, m, d + n)`), which is always correct in local time.
extension CalendarDate on DateTime {
  /// Local midnight at the start of this date.
  DateTime get dateOnly => DateTime(year, month, day);

  /// Local midnight [days] calendar days after this date (negative values go back).
  DateTime addDays(int days) => DateTime(year, month, day + days);

  /// Local midnight at the start of the following day (exclusive end of this day).
  DateTime get nextDay => addDays(1);

  /// Monday of the ISO week containing this date.
  DateTime get startOfWeek => addDays(-(weekday - DateTime.monday));

  /// First day of this month.
  DateTime get startOfMonth => DateTime(year, month);

  /// First day of the next month (exclusive end of this month).
  DateTime get startOfNextMonth => DateTime(year, month + 1);

  bool isSameDate(DateTime other) => year == other.year && month == other.month && day == other.day;

  /// Number of calendar days from this date to [other] (ignores the time of day and DST).
  int calendarDaysUntil(DateTime other) {
    return DateTime.utc(other.year, other.month, other.day).difference(DateTime.utc(year, month, day)).inDays;
  }
}

/// Inclusive range of calendar dates (first and last day, both at local midnight).
class DateRange {
  DateRange(DateTime start, DateTime end) : start = start.dateOnly, end = end.dateOnly;

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start – $end)';
}
