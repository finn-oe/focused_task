import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_calculator.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

import '../../../helpers/task_builders.dart';

const _minute = Duration(minutes: 1);

var _nextId = 1;

FocusSession _session(
  DateTime start,
  Duration length, {
  int? taskId = 1,
  SessionKind kind = SessionKind.focus,
  bool open = false,
  String? title,
  int interruptions = 0,
  int? categoryId,
}) {
  final end = start.add(length);
  return FocusSession(
    id: _nextId++,
    taskId: taskId,
    kind: kind,
    startedAt: start,
    lastSeenAt: end,
    endedAt: open ? null : end,
    endReason: open ? null : EndReason.paused,
    taskTitle: title,
    interruptions: interruptions,
    taskCategoryId: categoryId,
  );
}

void main() {
  const calculator = StatsCalculator();
  // Monday, 16 Nov 2026 – Sunday, 22 Nov 2026.
  final monday = DateTime(2026, 11, 16);
  final week = StatsQuery(range: DateRange(monday, monday.addDays(6)), granularity: StatsGranularity.day);

  group('StatsCalculator', () {
    test('empty data gives zeros and no ratios', () {
      final report = calculator.compute(week, tasks: const [], sessions: const [], today: monday.addDays(2));

      expect(report.isEmpty, isTrue);
      expect(report.focusTotal, Duration.zero);
      expect(report.averagePerElapsedDay, Duration.zero);
      expect(report.sessionCount, 0);
      expect(report.averageSessionLength, Duration.zero);
      expect(report.completionRate, isNull);
      expect(report.plannedVsActual.taskCount, 0);
      expect(report.plannedVsActual.estimationAccuracy, isNull);
      expect(report.interruptionsPerFocusHour, isNull);
      expect(report.topTasks, isEmpty);
      expect(report.buckets.map((bucket) => bucket.focus), List.filled(7, Duration.zero));
      expect(report.focusByWeekdayHour, everyElement(Duration.zero));
      expect(report.focusByWeekdayHour, hasLength(7 * 24));
    });

    test('averages over the elapsed days only', () {
      final sessions = [_session(monday.add(const Duration(hours: 9)), _minute * 60), _session(monday.addDays(2).add(const Duration(hours: 9)), _minute * 30)];

      // Wednesday: Monday to Wednesday have elapsed.
      final current = calculator.compute(week, tasks: const [], sessions: sessions, today: monday.addDays(2).add(const Duration(hours: 18)));
      expect(current.elapsedDays, 3);
      expect(current.focusTotal, _minute * 90);
      expect(current.averagePerElapsedDay, _minute * 30);

      final past = calculator.compute(week, tasks: const [], sessions: sessions, today: monday.addDays(30));
      expect(past.elapsedDays, 7);

      final future = calculator.compute(week, tasks: const [], sessions: const [], today: monday.addDays(-1));
      expect(future.elapsedDays, 0);
      expect(future.averagePerElapsedDay, Duration.zero);
    });

    test('compares target durations with tracked time; accuracy is the median over completed tasks', () {
      final tasks = [
        buildTask(id: 1, assignedDate: monday, targetDurationMinutes: 60, timeSpent: (_minute * 90).inMilliseconds, isCompleted: true),
        buildTask(id: 2, assignedDate: monday, targetDurationMinutes: 30, timeSpent: (_minute * 15).inMilliseconds, isCompleted: true),
        // Not completed: counts for the sums, not for the accuracy.
        buildTask(id: 3, assignedDate: monday, targetDurationMinutes: 30, isCompleted: false),
        // No target: ignored.
        buildTask(id: 4, assignedDate: monday, timeSpent: (_minute * 60).inMilliseconds),
      ];
      // Task 3 is running: its open session counts as tracked time.
      final sessions = [_session(monday.add(const Duration(hours: 10)), _minute * 20, taskId: 3, open: true)];

      final report = calculator.compute(week, tasks: tasks, sessions: sessions, today: monday);

      expect(report.plannedVsActual.taskCount, 3);
      expect(report.plannedVsActual.planned, _minute * 120);
      expect(report.plannedVsActual.actual, _minute * 125);
      expect(report.plannedVsActual.estimationAccuracy, 1.0, reason: 'median of 1.5 and 0.5');
      expect(report.tasksPlanned, 4);
      expect(report.tasksCompleted, 2);
      expect(report.completionRate, 0.5);
    });

    test('a session across midnight lands in both days and both weekday/hour buckets', () {
      final sessions = [_session(monday.add(const Duration(hours: 23, minutes: 30)), _minute * 75)];

      final report = calculator.compute(week, tasks: const [], sessions: sessions, today: monday.addDays(6));

      expect(report.focusAt(DateTime.monday, 23), _minute * 30);
      expect(report.focusAt(DateTime.tuesday, 0), _minute * 45);
      expect(report.buckets[0].focus, _minute * 30);
      expect(report.buckets[1].focus, _minute * 45);
      expect(report.sessionCount, 1);
    });

    test('clips sessions to the range and ignores breaks', () {
      final sessions = [
        // Sunday before the week, 23:00 – Monday 01:00: one hour counts.
        _session(monday.add(const Duration(hours: -1)), _minute * 120),
        _session(monday.add(const Duration(hours: 12)), _minute * 30, kind: SessionKind.breakTime),
      ];

      final report = calculator.compute(week, tasks: const [], sessions: sessions, today: monday);

      expect(report.focusTotal, _minute * 60);
      expect(report.sessionCount, 1);
      expect(report.averageSessionLength, _minute * 60);
      expect(report.focusAt(DateTime.sunday, 23), Duration.zero);
      expect(report.focusAt(DateTime.monday, 0), _minute * 60);
    });

    test('top tasks: the five with most time, with titles of tasks planned elsewhere and deleted ones', () {
      final tasks = [buildTask(id: 1, title: 'Planned here', assignedDate: monday)];
      final sessions = [
        for (var id = 1; id <= 6; id++)
          _session(
            monday.add(Duration(hours: id)),
            _minute * (id * 10),
            taskId: id,
            title: id == 1 ? null : 'Task $id',
          ),
        _session(monday.addDays(1), _minute * 45, taskId: null),
      ];

      final report = calculator.compute(week, tasks: tasks, sessions: sessions, today: monday);

      expect(report.topTasks.map((task) => (task.taskId, task.title, task.focus.inMinutes)), [
        (6, 'Task 6', 60),
        (5, 'Task 5', 50),
        (null, null, 45),
        (4, 'Task 4', 40),
        (3, 'Task 3', 30),
      ]);
    });

    test('hour buckets for a day and month buckets for a year', () {
      final sessions = [_session(monday.add(const Duration(hours: 9, minutes: 45)), _minute * 30)];

      final day = calculator.compute(
        StatsQuery(range: DateRange(monday, monday), granularity: StatsGranularity.hour),
        tasks: const [],
        sessions: sessions,
        today: monday,
      );
      expect(day.buckets, hasLength(24));
      expect(day.buckets[9].focus, _minute * 15);
      expect(day.buckets[10].focus, _minute * 15);

      final year = calculator.compute(
        StatsQuery(range: DateRange(DateTime(2026), DateTime(2026, 12, 31)), granularity: StatsGranularity.month),
        tasks: const [],
        sessions: sessions,
        today: monday,
      );
      expect(year.buckets.map((bucket) => bucket.start.month), List.generate(12, (index) => index + 1));
      expect(year.buckets[10].focus, _minute * 30);
      expect(year.elapsedDays, DateTime(2026).calendarDaysUntil(monday) + 1);
    });

    test('a 23-hour DST day still has 24 hour buckets and counts its real length', () {
      // Clocks go forward in Europe on 29 Mar 2026; in other zones this is an ordinary day.
      final day = DateTime(2026, 3, 29);
      final sessions = [_session(day, const Duration(hours: 5))];

      final report = calculator.compute(
        StatsQuery(range: DateRange(day, day), granularity: StatsGranularity.hour),
        tasks: const [],
        sessions: sessions,
        today: day,
      );

      expect(report.buckets, hasLength(24));
      expect(report.buckets.fold(Duration.zero, (sum, bucket) => sum + bucket.focus), report.focusTotal);
    });

    test('interruptions per focus hour', () {
      final sessions = [_session(monday.add(const Duration(hours: 9)), _minute * 120, interruptions: 3)];

      expect(calculator.compute(week, tasks: const [], sessions: sessions, today: monday).interruptionsPerFocusHour, 1.5);
    });

    test('focus time per category, most first; the category comes with the session or from the task', () {
      final nine = monday.add(const Duration(hours: 9));
      final sessions = [
        _session(nine, _minute * 20, taskId: 1, categoryId: 7),
        _session(nine.add(const Duration(hours: 1)), _minute * 30, taskId: 2),
        _session(nine.add(const Duration(hours: 2)), _minute * 15, taskId: 3),
        _session(nine.add(const Duration(hours: 3)), _minute * 10, taskId: null),
        _session(nine.add(const Duration(hours: 4)), _minute * 60, taskId: 1, kind: SessionKind.breakTime, categoryId: 7),
      ];
      final tasks = [buildTask(id: 2, assignedDate: monday, categoryId: 7), buildTask(id: 3, assignedDate: monday, categoryId: 8)];

      final report = calculator.compute(week, tasks: tasks, sessions: sessions, today: monday);

      expect(report.focusByCategory.map((entry) => (entry.categoryId, entry.focus)), [(7, _minute * 50), (8, _minute * 15), (null, _minute * 10)]);
      expect(report.hasCategorizedFocus, isTrue);
      expect(calculator.compute(week, tasks: const [], sessions: [_session(nine, _minute * 5)], today: monday).hasCategorizedFocus, isFalse);
    });

    test('break time is reported separately and never counts as focus time', () {
      final nine = monday.add(const Duration(hours: 9));
      final sessions = [
        _session(nine, _minute * 25),
        _session(nine.add(_minute * 25), _minute * 5, taskId: null, kind: SessionKind.breakTime),
        _session(nine.add(_minute * 30), _minute * 25),
        // Before the range: only the part inside counts.
        _session(monday.subtract(_minute * 10), _minute * 15, taskId: null, kind: SessionKind.breakTime),
      ];
      final report = calculator.compute(week, tasks: const [], sessions: sessions, today: monday);

      expect(report.focusTotal, _minute * 50);
      expect(report.sessionCount, 2);
      expect(report.breakTotal, _minute * 10);
    });
  });
}
