import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

enum StatsRange {
  day,
  week,
  month,
  year;

  /// Chart bars: hours of a day, days of a week or month, months of a year.
  StatsGranularity get granularity => switch (this) {
    StatsRange.day => StatsGranularity.hour,
    StatsRange.week || StatsRange.month => StatsGranularity.day,
    StatsRange.year => StatsGranularity.month,
  };
}

/// The period the statistics screen shows: a [range] kind and a date inside it.
class StatsPeriod {
  StatsPeriod(this.range, DateTime anchor) : anchor = anchor.dateOnly;

  final StatsRange range;

  /// Any date inside the period.
  final DateTime anchor;

  /// First and last day of the period, weeks starting on [firstWeekday].
  DateRange dates({required int firstWeekday}) => statsDateRange(range, anchor, firstWeekday: firstWeekday);

  StatsQuery query({required int firstWeekday}) => StatsQuery(
    range: dates(firstWeekday: firstWeekday),
    granularity: range.granularity,
  );

  /// The period [steps] periods later (negative: earlier).
  StatsPeriod shift(int steps) {
    final next = switch (range) {
      StatsRange.day => anchor.addDays(steps),
      StatsRange.week => anchor.addDays(steps * DateTime.daysPerWeek),
      // The first of the month, so the 31st doesn't overflow into the month after.
      StatsRange.month => DateTime(anchor.year, anchor.month + steps),
      StatsRange.year => DateTime(anchor.year + steps, anchor.month),
    };
    return StatsPeriod(range, next);
  }

  /// Whether the period contains [today].
  bool contains(DateTime today, {required int firstWeekday}) {
    final range = dates(firstWeekday: firstWeekday);
    final day = today.dateOnly;
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  @override
  bool operator ==(Object other) => other is StatsPeriod && other.range == range && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(range, anchor);
}

/// The period of the statistics screen. Starts at today's day; resets when the screen is closed.
class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod(StatsRange.day, clock.now());

  /// Switches to [range], keeping the date that is shown.
  void select(StatsRange range) => state = StatsPeriod(range, state.anchor);

  void previous() => state = state.shift(-1);

  void next() => state = state.shift(1);

  /// Back to the period containing today.
  void goToCurrent() => state = StatsPeriod(state.range, clock.now());
}

/// Inclusive calendar-date range (first and last day) of [range] around [anchor]. Weeks start on [firstWeekday].
DateRange statsDateRange(StatsRange range, DateTime anchor, {required int firstWeekday}) {
  final weekStart = anchor.startOfWeek(firstWeekday);
  return switch (range) {
    StatsRange.day => DateRange(anchor, anchor),
    StatsRange.week => DateRange(weekStart, weekStart.addDays(DateTime.daysPerWeek - 1)),
    StatsRange.month => DateRange(anchor.startOfMonth, anchor.startOfNextMonth.addDays(-1)),
    StatsRange.year => DateRange(DateTime(anchor.year), DateTime(anchor.year + 1).addDays(-1)),
  };
}
