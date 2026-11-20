import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';

/// The days on which a [RecurrenceRule] has an occurrence (#24). Calendar arithmetic only, so DST switches and month
/// lengths can't shift a day.
class RecurrenceExpander {
  const RecurrenceExpander();

  /// The occurrence dates of [rule] within [range] (inclusive), in order, at local midnight. Days in [exceptions]
  /// (deleted occurrences) are left out.
  List<DateTime> occurrences(RecurrenceRule rule, DateRange range, {Set<DateTime> exceptions = const {}}) {
    final start = rule.startDate.dateOnly;
    final end = rule.pattern.endDate?.dateOnly;
    var day = range.start.isBefore(start) ? start : range.start;
    final last = end != null && end.isBefore(range.end) ? end : range.end;
    final skipped = {for (final date in exceptions) date.dateOnly};
    final result = <DateTime>[];
    while (!day.isAfter(last)) {
      if (rule.pattern.matches(day, start: start) && !skipped.contains(day)) result.add(day);
      day = day.nextDay;
    }
    return result;
  }
}
