import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/calendar/presentation/calendar_period.dart';

void main() {
  CalendarPeriod week(DateTime anchor, int firstWeekday) => CalendarPeriod(view: CalendarView.week, anchor: anchor, firstWeekday: firstWeekday);
  CalendarPeriod month(DateTime anchor, int firstWeekday) => CalendarPeriod(view: CalendarView.month, anchor: anchor, firstWeekday: firstWeekday);

  test('a week starts on the first day of the week', () {
    final wednesday = DateTime(2026, 2, 4, 15, 30);
    expect(week(wednesday, DateTime.monday).visibleRange, DateRange(DateTime(2026, 2, 2), DateTime(2026, 2, 8)));
    expect(week(wednesday, DateTime.sunday).visibleRange, DateRange(DateTime(2026, 2, 1), DateTime(2026, 2, 7)));
    expect(week(wednesday, DateTime.monday).visibleDays, hasLength(7));
  });

  test('a month covers whole weeks: 4, 5 or 6 rows', () {
    // February 2026 starts on a Sunday and has 28 days.
    expect(month(DateTime(2026, 2, 10), DateTime.sunday).visibleRange, DateRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
    expect(month(DateTime(2026, 2, 10), DateTime.monday).visibleRange, DateRange(DateTime(2026, 1, 26), DateTime(2026, 3, 1)));
    expect(month(DateTime(2026, 8, 1), DateTime.monday).visibleDays, hasLength(42));
  });

  test('contains only the days of the month itself', () {
    final february = month(DateTime(2026, 2, 10), DateTime.monday);
    expect(february.contains(DateTime(2026, 2, 28, 23)), isTrue);
    expect(february.contains(DateTime(2026, 1, 31)), isFalse);
    expect(february.contains(DateTime(2026, 3, 1)), isFalse);
  });

  test('previous and next move by whole weeks and months, also across years and DST', () {
    expect(month(DateTime(2026, 1, 31), DateTime.monday).previous.start, DateTime(2025, 12));
    expect(month(DateTime(2026, 12, 15), DateTime.monday).next.start, DateTime(2027));
    // The week of the European spring DST switch (29 March 2026).
    expect(week(DateTime(2026, 3, 25), DateTime.monday).next.start, DateTime(2026, 3, 30));
    expect(week(DateTime(2026, 3, 30), DateTime.monday).previous.start, DateTime(2026, 3, 23));
  });

  test('parses the view from the URL', () {
    expect(CalendarView.tryParse('month'), CalendarView.month);
    expect(CalendarView.tryParse('year'), isNull);
    expect(CalendarView.tryParse(null), isNull);
  });
}
