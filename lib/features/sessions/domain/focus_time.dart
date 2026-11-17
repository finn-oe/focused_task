import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';

/// Focus time of [session] inside `[from, toExclusive)`. Breaks count as zero.
Duration focusTimeWithin(FocusSession session, DateTime from, DateTime toExclusive) {
  if (session.kind != SessionKind.focus) return Duration.zero;
  final start = session.startedAt.isAfter(from) ? session.startedAt : from;
  final end = session.effectiveEnd.isBefore(toExclusive) ? session.effectiveEnd : toExclusive;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// Focus time per calendar day of [range] (local midnight keys). Sessions are split at local midnight, so a session
/// from 23:30 to 00:30 counts 30 minutes on each day. Days without focus time are omitted.
Map<DateTime, Duration> focusTimeByDay(Iterable<FocusSession> sessions, DateRange range) {
  final result = <DateTime, Duration>{};
  for (var day = range.start; !day.isAfter(range.end); day = day.nextDay) {
    final total = sessions.fold(Duration.zero, (sum, session) => sum + focusTimeWithin(session, day, day.nextDay));
    if (total > Duration.zero) result[day] = total;
  }
  return result;
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
