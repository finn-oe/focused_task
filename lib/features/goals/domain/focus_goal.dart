import 'package:focused_task/core/utils/date_utils.dart';

/// The daily focus goal: how much focus time a working day should have.
///
/// There is only the *current* goal. Past days are judged by it as well, so changing the goal changes past streaks
/// (simple and predictable; the app keeps no history of goals).
class FocusGoal {
  const FocusGoal({required this.daily, this.workingDays = defaultWorkingDays});

  /// No goal.
  static const off = FocusGoal(daily: null);

  /// Monday to Friday ([DateTime.weekday] values).
  static const defaultWorkingDays = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};

  /// Goals the settings offer, in minutes: 30 min, 1 h … 8 h.
  static const options = [30, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480];

  /// Focus time per working day; `null` = no goal.
  final Duration? daily;

  /// Days the goal applies to, as [DateTime.weekday] values. Other days neither break nor extend a streak.
  final Set<int> workingDays;

  bool get isEnabled => daily != null && daily! > Duration.zero;

  bool isWorkingDay(DateTime day) => workingDays.contains(day.weekday);

  /// Whether [focus] reaches the goal; always `false` without a goal.
  bool isReachedBy(Duration focus) => isEnabled && focus >= daily!;

  /// Share of the goal reached by [focus], 0–1; 0 without a goal.
  double progress(Duration focus) => isEnabled ? (focus.inMilliseconds / daily!.inMilliseconds).clamp(0, 1).toDouble() : 0;

  @override
  bool operator ==(Object other) => other is FocusGoal && other.daily == daily && other.workingDays.length == workingDays.length && other.workingDays.containsAll(workingDays);

  @override
  int get hashCode => Object.hash(daily, Object.hashAllUnordered(workingDays));

  @override
  String toString() => 'FocusGoal($daily, $workingDays)';
}

/// Current and longest streak of working days on which the goal was reached.
class Streak {
  const Streak({required this.current, required this.longest});

  static const none = Streak(current: 0, longest: 0);

  final int current;
  final int longest;

  @override
  bool operator ==(Object other) => other is Streak && other.current == current && other.longest == longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'Streak(current: $current, longest: $longest)';
}

/// Streaks from the focus time per day. Pure; the focus time comes from the session log (`focusTimeByDay`, split at
/// local midnight).
abstract final class StreakCalculator {
  /// Streaks up to [today] for [goal] (the current goal is used for all days, see [FocusGoal]).
  ///
  /// - Only working days count: other days neither break nor extend a streak, even with focus time.
  /// - Today extends the streak once the goal is reached, but never breaks it: the day isn't over yet.
  /// - Days after [today] are ignored.
  static Streak compute(Map<DateTime, Duration> focusByDay, FocusGoal goal, DateTime today) {
    if (!goal.isEnabled || focusByDay.isEmpty) return Streak.none;
    final focus = _byDate(focusByDay);
    final lastDay = today.dateOnly;
    final firstDay = focus.keys.reduce((a, b) => a.isBefore(b) ? a : b);

    var current = 0;
    var longest = 0;
    for (var day = firstDay; !day.isAfter(lastDay); day = day.nextDay) {
      if (!goal.isWorkingDay(day)) continue;
      if (goal.isReachedBy(focus[day] ?? Duration.zero)) {
        current++;
        if (current > longest) longest = current;
      } else if (day != lastDay) {
        current = 0;
      }
    }
    return Streak(current: current, longest: longest);
  }

  /// Number of days per month of [year] on which the goal was reached (index 0 = January). Counts every day that
  /// reached the goal, also non-working days.
  static List<int> goalDaysPerMonth(Map<DateTime, Duration> focusByDay, FocusGoal goal, int year) {
    final result = List.filled(DateTime.monthsPerYear, 0);
    if (!goal.isEnabled) return result;
    _byDate(focusByDay).forEach((day, focus) {
      if (day.year == year && goal.isReachedBy(focus)) result[day.month - 1]++;
    });
    return result;
  }

  /// Keys normalized to local midnight (a caller might pass any time of day).
  static Map<DateTime, Duration> _byDate(Map<DateTime, Duration> focusByDay) {
    final result = <DateTime, Duration>{};
    focusByDay.forEach((day, focus) => result.update(day.dateOnly, (sum) => sum + focus, ifAbsent: () => focus));
    return result;
  }
}

/// Everything the goal UI shows: today's progress and the streaks. Built from the focus time per day.
class GoalStatus {
  const GoalStatus({required this.goal, required this.today, required this.todayFocus, required this.streak, required this.focusByDay});

  factory GoalStatus.from(Map<DateTime, Duration> focusByDay, FocusGoal goal, DateTime today) {
    final day = today.dateOnly;
    return GoalStatus(goal: goal, today: day, todayFocus: focusByDay[day] ?? Duration.zero, streak: StreakCalculator.compute(focusByDay, goal, day), focusByDay: focusByDay);
  }

  final FocusGoal goal;
  final DateTime today;
  final Duration todayFocus;
  final Streak streak;

  /// Focus time per day (local midnight keys) that the status was computed from.
  final Map<DateTime, Duration> focusByDay;

  bool get reachedToday => goal.isReachedBy(todayFocus);

  double get progressToday => goal.progress(todayFocus);

  List<int> goalDaysPerMonth(int year) => StreakCalculator.goalDaysPerMonth(focusByDay, goal, year);
}
