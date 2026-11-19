import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';

/// Focus time of [session] inside `[from, toExclusive)`. Breaks count as zero.
Duration focusTimeWithin(FocusSession session, DateTime from, DateTime toExclusive) {
  if (session.kind != SessionKind.focus) return Duration.zero;
  final start = session.startedAt.isAfter(from) ? session.startedAt : from;
  final end = session.effectiveEnd.isBefore(toExclusive) ? session.effectiveEnd : toExclusive;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// Break time (#27) of [session] inside `[from, toExclusive)`. Focus sessions count as zero.
Duration breakTimeWithin(FocusSession session, DateTime from, DateTime toExclusive) {
  if (session.kind != SessionKind.breakTime) return Duration.zero;
  final start = session.startedAt.isAfter(from) ? session.startedAt : from;
  final end = session.effectiveEnd.isBefore(toExclusive) ? session.effectiveEnd : toExclusive;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// Focus time per calendar day of [range] (local midnight keys, in date order). Sessions are split at local midnight,
/// so a session from 23:30 to 00:30 counts 30 minutes on each day. Days without focus time are omitted.
///
/// Walks each session across the days it covers, so long ranges (e.g. the whole history for streaks) stay cheap.
Map<DateTime, Duration> focusTimeByDay(Iterable<FocusSession> sessions, DateRange range) {
  final from = range.start;
  final toExclusive = range.end.nextDay;
  final totals = <DateTime, Duration>{};
  for (final session in sessions) {
    if (session.kind != SessionKind.focus) continue;
    var cursor = session.startedAt.isAfter(from) ? session.startedAt : from;
    final end = session.effectiveEnd.isBefore(toExclusive) ? session.effectiveEnd : toExclusive;
    while (cursor.isBefore(end)) {
      final day = cursor.dateOnly;
      final next = day.nextDay;
      final sliceEnd = next.isBefore(end) ? next : end;
      final time = sliceEnd.difference(cursor);
      totals.update(day, (sum) => sum + time, ifAbsent: () => time);
      cursor = sliceEnd;
    }
  }
  final days = totals.keys.toList()..sort();
  return {for (final day in days) day: totals[day]!};
}

/// Focus time per task within [range]; the `null` key collects time of deleted tasks.
Map<int?, Duration> focusTimeByTask(Iterable<FocusSession> sessions, DateRange range) {
  final result = <int?, Duration>{};
  final from = range.start;
  final toExclusive = range.end.nextDay;
  for (final session in sessions) {
    final time = focusTimeWithin(session, from, toExclusive);
    if (time > Duration.zero) result.update(session.taskId, (sum) => sum + time, ifAbsent: () => time);
  }
  return result;
}
