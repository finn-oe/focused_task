import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

/// Builds a [StatsReport] from the tasks assigned to a range and the sessions overlapping it. Pure and synchronous.
///
/// Focus time always comes from the session log, by the time it actually happened (sessions are split at local
/// midnight, hour and range boundaries); task counts come from the tasks by their assigned day.
class StatsCalculator {
  const StatsCalculator({this.interruptionsTracked = false});

  /// Number of top tasks in the report.
  static const topTaskCount = 5;

  /// Whether sessions record interruptions yet (#28). Until then the report shows no interruption rate.
  final bool interruptionsTracked;

  /// [tasks] are the tasks assigned to `query.range`; [sessions] overlap it (any kind, also open ones); [today] decides
  /// which days have elapsed.
  StatsReport compute(StatsQuery query, {required Iterable<TaskEntity> tasks, required Iterable<FocusSession> sessions, required DateTime today}) {
    final range = query.range;
    final from = range.start;
    final toExclusive = range.end.nextDay;
    final taskList = tasks.toList(growable: false);
    final focusSessions = sessions.where((session) => session.kind == SessionKind.focus).toList(growable: false);

    var focusTotal = Duration.zero;
    var sessionCount = 0;
    var interruptions = 0;
    for (final session in focusSessions) {
      final time = focusTimeWithin(session, from, toExclusive);
      if (time <= Duration.zero) continue;
      focusTotal += time;
      sessionCount++;
      interruptions += session.interruptions;
    }

    final elapsedDays = _elapsedDays(range, today);
    final focusHours = focusTotal.inMilliseconds / Duration.millisecondsPerHour;

    return StatsReport(
      query: query,
      focusTotal: focusTotal,
      buckets: [
        for (final (start, end) in _bucketBounds(query))
          StatsBucket(start: start, end: end, focus: focusSessions.fold(Duration.zero, (sum, session) => sum + focusTimeWithin(session, start, end))),
      ],
      elapsedDays: elapsedDays,
      averagePerElapsedDay: elapsedDays == 0 ? Duration.zero : focusTotal ~/ elapsedDays,
      tasksPlanned: taskList.length,
      tasksCompleted: taskList.where((task) => task.isCompleted).length,
      plannedVsActual: _plannedVsActual(taskList, focusSessions),
      sessionCount: sessionCount,
      averageSessionLength: sessionCount == 0 ? Duration.zero : focusTotal ~/ sessionCount,
      focusByWeekdayHour: _focusByWeekdayHour(focusSessions, from, toExclusive),
      topTasks: _topTasks(focusSessions, range, taskList),
      interruptionsPerFocusHour: !interruptionsTracked || focusHours == 0 ? null : interruptions / focusHours,
      focusByCategory: _focusByCategory(focusSessions, from, toExclusive, taskList),
      breakTotal: sessions.fold(Duration.zero, (sum, session) => sum + breakTimeWithin(session, from, toExclusive)),
    );
  }

  /// Days of [range] up to and including [today].
  static int _elapsedDays(DateRange range, DateTime today) {
    final lastElapsed = today.dateOnly.isBefore(range.end) ? today.dateOnly : range.end;
    if (lastElapsed.isBefore(range.start)) return 0;
    return range.start.calendarDaysUntil(lastElapsed) + 1;
  }

  static Iterable<(DateTime, DateTime)> _bucketBounds(StatsQuery query) sync* {
    final range = query.range;
    switch (query.granularity) {
      case StatsGranularity.hour:
        for (var day = range.start; !day.isAfter(range.end); day = day.nextDay) {
          // Contiguous buckets, so DST days (23 or 25 hours) neither count an hour twice nor lose one.
          var start = day;
          for (var hour = 0; hour < hoursPerDay; hour++) {
            final next = hour == hoursPerDay - 1 ? day.nextDay : DateTime(day.year, day.month, day.day, hour + 1);
            final end = next.isAfter(start) ? next : start;
            yield (start, end);
            start = end;
          }
        }
      case StatsGranularity.day:
        for (var day = range.start; !day.isAfter(range.end); day = day.nextDay) {
          yield (day, day.nextDay);
        }
      case StatsGranularity.month:
        for (var month = range.start.startOfMonth; !month.isAfter(range.end); month = month.startOfNextMonth) {
          final start = month.isBefore(range.start) ? range.start : month;
          final end = month.startOfNextMonth.isAfter(range.end.nextDay) ? range.end.nextDay : month.startOfNextMonth;
          yield (start, end);
        }
    }
  }

  /// Splits every session at local hour boundaries (so a session across midnight lands on two weekdays).
  static List<Duration> _focusByWeekdayHour(List<FocusSession> sessions, DateTime from, DateTime toExclusive) {
    final result = List.filled(DateTime.daysPerWeek * hoursPerDay, Duration.zero);
    for (final session in sessions) {
      var cursor = session.startedAt.isAfter(from) ? session.startedAt : from;
      final end = session.effectiveEnd.isBefore(toExclusive) ? session.effectiveEnd : toExclusive;
      while (cursor.isBefore(end)) {
        final nextHour = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
        final sliceEnd = nextHour.isBefore(end) ? nextHour : end;
        result[(cursor.weekday - 1) * hoursPerDay + cursor.hour] += sliceEnd.difference(cursor);
        cursor = sliceEnd;
      }
    }
    return result;
  }

  static List<TaskFocusTime> _topTasks(List<FocusSession> sessions, DateRange range, List<TaskEntity> tasks) {
    final titles = <int, String>{
      for (final session in sessions)
        if (session.taskId != null && session.taskTitle != null) session.taskId!: session.taskTitle!,
      for (final task in tasks) task.id: task.title,
    };
    final entries = focusTimeByTask(sessions, range).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in entries.take(topTaskCount)) TaskFocusTime(taskId: entry.key, title: entry.key == null ? null : titles[entry.key], focus: entry.value)];
  }

  /// The category of a session comes with it (joined from its task); tasks of the range fill in where it doesn't.
  static List<CategoryFocusTime> _focusByCategory(List<FocusSession> sessions, DateTime from, DateTime toExclusive, List<TaskEntity> tasks) {
    final categoryOf = {for (final task in tasks) task.id: task.categoryId};
    final totals = <int?, Duration>{};
    for (final session in sessions) {
      final time = focusTimeWithin(session, from, toExclusive);
      if (time <= Duration.zero) continue;
      final category = session.taskCategoryId ?? categoryOf[session.taskId];
      totals.update(category, (sum) => sum + time, ifAbsent: () => time);
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in entries) CategoryFocusTime(categoryId: entry.key, focus: entry.value)];
  }

  static PlannedVsActual _plannedVsActual(List<TaskEntity> tasks, List<FocusSession> sessions) {
    final withTarget = tasks.where((task) => (task.targetDurationMinutes ?? 0) > 0).toList(growable: false);
    if (withTarget.isEmpty) return PlannedVsActual.empty;

    // `timeSpent` holds the closed sessions; a running session adds its time so far.
    Duration tracked(TaskEntity task) {
      final open = sessions.where((session) => session.isOpen && session.taskId == task.id).fold(Duration.zero, (sum, session) => sum + session.duration);
      return Duration(milliseconds: task.timeSpent) + open;
    }

    var planned = Duration.zero;
    var actual = Duration.zero;
    final ratios = <double>[];
    for (final task in withTarget) {
      final target = Duration(minutes: task.targetDurationMinutes!);
      final time = tracked(task);
      planned += target;
      actual += time;
      if (task.isCompleted && time > Duration.zero) ratios.add(time.inMilliseconds / target.inMilliseconds);
    }
    return PlannedVsActual(taskCount: withTarget.length, planned: planned, actual: actual, estimationAccuracy: _median(ratios));
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
