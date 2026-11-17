import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/utils/date_utils.dart';

enum StatsRange { day, week, month }

/// The period the statistics screen shows. Resets to [StatsRange.day] when the screen is closed.
class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.day;

  void select(StatsRange range) => state = range;
}

/// Inclusive calendar-date range (first and last day) of [range] around [now].
DateRange statsDateRange(StatsRange range, DateTime now) {
  return switch (range) {
    StatsRange.day => DateRange(now, now),
    StatsRange.week => DateRange(now.startOfWeek, now.startOfWeek.addDays(DateTime.daysPerWeek - 1)),
    StatsRange.month => DateRange(now.startOfMonth, now.startOfNextMonth.addDays(-1)),
  };
}
