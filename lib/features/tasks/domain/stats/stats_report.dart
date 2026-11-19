import 'package:focused_task/core/utils/date_utils.dart';

/// Size of the buckets of the focus chart.
enum StatsGranularity { hour, day, month }

/// What the statistics show: the calendar dates of [range], with chart bars per [granularity].
class StatsQuery {
  const StatsQuery({required this.range, required this.granularity});

  final DateRange range;
  final StatsGranularity granularity;

  @override
  bool operator ==(Object other) => other is StatsQuery && other.range == range && other.granularity == granularity;

  @override
  int get hashCode => Object.hash(range, granularity);

  @override
  String toString() => 'StatsQuery($range, $granularity)';
}

/// Focus time in `[start, end)`, one bar of the focus chart.
class StatsBucket {
  const StatsBucket({required this.start, required this.end, required this.focus});

  final DateTime start;
  final DateTime end;
  final Duration focus;
}

/// Focus time spent on one task within the range.
class TaskFocusTime {
  const TaskFocusTime({required this.taskId, required this.title, required this.focus});

  /// `null` for time of deleted tasks.
  final int? taskId;

  /// `null` if the task was deleted.
  final String? title;
  final Duration focus;
}

/// Focus time spent on the tasks of one category within the range.
class CategoryFocusTime {
  const CategoryFocusTime({required this.categoryId, required this.focus});

  /// `null` for tasks without a category (and deleted tasks).
  final int? categoryId;
  final Duration focus;
}

/// Planned (target durations) vs. actual (tracked) time of the tasks with a target that are assigned to the range.
class PlannedVsActual {
  const PlannedVsActual({required this.taskCount, required this.planned, required this.actual, required this.estimationAccuracy});

  static const empty = PlannedVsActual(taskCount: 0, planned: Duration.zero, actual: Duration.zero, estimationAccuracy: null);

  /// Number of tasks with a target duration.
  final int taskCount;

  /// Sum of the target durations.
  final Duration planned;

  /// Total tracked time of those tasks (all sessions, not only the ones inside the range: a target is for the whole task).
  final Duration actual;

  /// Median of actual / target over the *completed* tasks with a target and tracked time; 1.0 = spot on, 1.5 = took 50 %
  /// longer than planned. `null` if no such task exists.
  final double? estimationAccuracy;
}

/// Hours per day, columns of [StatsReport.focusByWeekdayHour].
const hoursPerDay = 24;

/// Everything the statistics screen shows for a [StatsQuery]. Built by `StatsCalculator`.
class StatsReport {
  const StatsReport({
    required this.query,
    required this.focusTotal,
    required this.buckets,
    required this.elapsedDays,
    required this.averagePerElapsedDay,
    required this.tasksPlanned,
    required this.tasksCompleted,
    required this.plannedVsActual,
    required this.sessionCount,
    required this.averageSessionLength,
    required this.focusByWeekdayHour,
    required this.topTasks,
    required this.interruptionsPerFocusHour,
    this.focusByCategory = const [],
    this.breakTotal = Duration.zero,
  });

  final StatsQuery query;

  /// Focus time inside the range (sessions split at the range bounds).
  final Duration focusTotal;

  /// Focus time per hour / day / month of the range, in order, including empty buckets.
  final List<StatsBucket> buckets;

  /// Days of the range up to and including today; future days don't count for the average.
  final int elapsedDays;

  /// [focusTotal] / [elapsedDays]; zero if the range lies in the future.
  final Duration averagePerElapsedDay;

  /// Tasks assigned to the range, and how many of them are completed.
  final int tasksPlanned;
  final int tasksCompleted;

  final PlannedVsActual plannedVsActual;

  /// Focus sessions with time inside the range, and their average length within it.
  final int sessionCount;
  final Duration averageSessionLength;

  /// Focus time by weekday × hour of day: index `(weekday - 1) * 24 + hour` (see [focusAt]).
  final List<Duration> focusByWeekdayHour;

  /// Up to five tasks with the most focus time, most first.
  final List<TaskFocusTime> topTasks;

  /// `null` while interruptions aren't recorded yet (#28) or without focus time.
  final double? interruptionsPerFocusHour;

  /// Focus time per category, most first; categories without focus time in the range are left out.
  final List<CategoryFocusTime> focusByCategory;

  /// Break time of the work/break cycles (#27) inside the range; never part of [focusTotal].
  final Duration breakTotal;

  /// Whether any focus time of the range belongs to a category.
  bool get hasCategorizedFocus => focusByCategory.any((entry) => entry.categoryId != null);

  /// Focus time on [weekday] (a [DateTime.weekday] value) in [hour] (0–23).
  Duration focusAt(int weekday, int hour) => focusByWeekdayHour[(weekday - 1) * hoursPerDay + hour];

  /// Share of the planned tasks that are completed (0–1); `null` without planned tasks.
  double? get completionRate => tasksPlanned == 0 ? null : tasksCompleted / tasksPlanned;

  /// Nothing to show: no focus time and no planned tasks.
  bool get isEmpty => focusTotal == Duration.zero && tasksPlanned == 0;
}
