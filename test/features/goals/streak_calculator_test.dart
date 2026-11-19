import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart';

const _hour = Duration(hours: 1);
const _goal = FocusGoal(daily: _hour);

// Monday, 16 Nov 2026.
final _monday = DateTime(2026, 11, 16);

/// [hours] of focus time on each of the given days.
Map<DateTime, Duration> _focus(Iterable<DateTime> days, {double hours = 1}) => {for (final day in days) day: Duration(minutes: (hours * 60).round())};

FocusSession _session(DateTime start, Duration duration) =>
    FocusSession(id: 1, taskId: 1, kind: SessionKind.focus, startedAt: start, endedAt: start.add(duration), lastSeenAt: start.add(duration), endReason: EndReason.completed);

void main() {
  group('StreakCalculator.compute', () {
    test('without a goal or focus time there is no streak', () {
      expect(StreakCalculator.compute(_focus([_monday]), FocusGoal.off, _monday), Streak.none);
      expect(StreakCalculator.compute(const {}, _goal, _monday), Streak.none);
    });

    test('weekends neither break nor extend the streak', () {
      // Thu, Fri, (Sat, Sun off), Mon, Tue – the weekend has no focus time.
      final days = [_monday.addDays(-4), _monday.addDays(-3), _monday, _monday.addDays(1)];
      expect(StreakCalculator.compute(_focus(days), _goal, _monday.addDays(1)), const Streak(current: 4, longest: 4));

      // Focus time on Saturday doesn't add a day either.
      final withWeekend = _focus([...days, _monday.addDays(-2)]);
      expect(StreakCalculator.compute(withWeekend, _goal, _monday.addDays(1)), const Streak(current: 4, longest: 4));
    });

    test('a missed working day breaks the streak', () {
      // Mon, Tue reached; Wed missed; Thu reached.
      final focus = _focus([_monday, _monday.addDays(1), _monday.addDays(3)]);
      expect(StreakCalculator.compute(focus, _goal, _monday.addDays(3)), const Streak(current: 1, longest: 2));
    });

    test('a working day below the goal breaks the streak', () {
      final focus = {
        ..._focus([_monday, _monday.addDays(2)]),
        _monday.addDays(1): const Duration(minutes: 59),
      };
      expect(StreakCalculator.compute(focus, _goal, _monday.addDays(2)), const Streak(current: 1, longest: 1));
    });

    test('today counts once the goal is reached, and never breaks the streak before the day ends', () {
      final yesterdayAndBefore = _focus([_monday, _monday.addDays(1)]);
      final wednesday = _monday.addDays(2);

      // Nothing yet today.
      expect(StreakCalculator.compute(yesterdayAndBefore, _goal, wednesday), const Streak(current: 2, longest: 2));
      // In progress.
      expect(StreakCalculator.compute({...yesterdayAndBefore, wednesday: const Duration(minutes: 30)}, _goal, wednesday), const Streak(current: 2, longest: 2));
      // Reached.
      expect(StreakCalculator.compute({...yesterdayAndBefore, wednesday: _hour}, _goal, wednesday), const Streak(current: 3, longest: 3));
      // The next day, an unreached Wednesday has broken it.
      expect(StreakCalculator.compute(yesterdayAndBefore, _goal, _monday.addDays(3)), const Streak(current: 0, longest: 2));
    });

    test('days after today are ignored', () {
      final focus = _focus([_monday, _monday.addDays(1), _monday.addDays(2)]);
      expect(StreakCalculator.compute(focus, _goal, _monday.addDays(1)), const Streak(current: 2, longest: 2));
    });

    test('custom working days', () {
      // Only Mondays and Wednesdays count; Tuesday's missing focus time doesn't break anything.
      const goal = FocusGoal(daily: _hour, workingDays: {DateTime.monday, DateTime.wednesday});
      final focus = _focus([_monday, _monday.addDays(2), _monday.addDays(7)]);
      expect(StreakCalculator.compute(focus, goal, _monday.addDays(7)), const Streak(current: 3, longest: 3));
    });

    test('a DST week: days from the session log still line up (clocks change on 25 Oct 2026 in Europe)', () {
      // Mon 19 Oct – Fri 30 Oct 2026, one hour every working day, partly across midnight. In other time zones this is
      // an ordinary fortnight.
      final start = DateTime(2026, 10, 19);
      final sessions = [
        for (var day = start; !day.isAfter(DateTime(2026, 10, 30)); day = day.nextDay)
          if (day.weekday <= DateTime.friday) _session(DateTime(day.year, day.month, day.day, 9), _hour),
        // Sunday night into Monday 26 Oct (the DST day is Sunday): 30 min on each side; Monday also has its own hour.
        _session(DateTime(2026, 10, 25, 23, 30), _hour),
      ];
      final focusByDay = focusTimeByDay(sessions, DateRange(start, DateTime(2026, 10, 30)));

      expect(focusByDay.keys, everyElement(predicate<DateTime>((day) => day == day.dateOnly)), reason: 'keys at local midnight');
      expect(focusByDay[DateTime(2026, 10, 26)], const Duration(minutes: 90));
      expect(StreakCalculator.compute(focusByDay, _goal, DateTime(2026, 10, 30)), const Streak(current: 10, longest: 10));
      // Keys with a time of day (e.g. 01:00 after a DST shift) count for their date.
      final shifted = {for (final entry in focusByDay.entries) entry.key.add(_hour): entry.value};
      expect(StreakCalculator.compute(shifted, _goal, DateTime(2026, 10, 30)), const Streak(current: 10, longest: 10));
    });

    test('the current goal is used for all days, also after changing it', () {
      // Two days with 1 h, then 2 h a day; the goal is raised to 2 h afterwards.
      final focus = {
        ..._focus([_monday, _monday.addDays(1)]),
        ..._focus([_monday.addDays(2), _monday.addDays(3)], hours: 2),
      };
      final today = _monday.addDays(3);

      expect(StreakCalculator.compute(focus, _goal, today), const Streak(current: 4, longest: 4));
      expect(StreakCalculator.compute(focus, const FocusGoal(daily: Duration(hours: 2)), today), const Streak(current: 2, longest: 2));
    });
  });

  test('goalDaysPerMonth counts the days that reached the goal, per month of the year', () {
    final focus = {
      ..._focus([DateTime(2026, 1, 5), DateTime(2026, 1, 6), DateTime(2026, 11, 14)]),
      DateTime(2026, 2, 2): const Duration(minutes: 10),
      DateTime(2025, 12, 31): _hour,
    };
    final perMonth = StreakCalculator.goalDaysPerMonth(focus, _goal, 2026);

    expect(perMonth, hasLength(12));
    expect(perMonth[0], 2);
    expect(perMonth[1], 0, reason: 'below the goal');
    expect(perMonth[10], 1, reason: 'a Saturday counts as a goal day too');
    expect(perMonth.reduce((a, b) => a + b), 3, reason: 'other years are left out');
    expect(StreakCalculator.goalDaysPerMonth(focus, FocusGoal.off, 2026), everyElement(0));
  });

  test('GoalStatus has today\'s progress', () {
    final status = GoalStatus.from({_monday: const Duration(minutes: 45)}, _goal, DateTime(2026, 11, 16, 15));

    expect(status.today, _monday);
    expect(status.todayFocus, const Duration(minutes: 45));
    expect(status.progressToday, 0.75);
    expect(status.reachedToday, isFalse);
    expect(GoalStatus.from({_monday: const Duration(hours: 2)}, _goal, _monday).progressToday, 1);
  });
}
