import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_range.dart';

// EU daylight-saving switches in 2026. In other time zones these are regular days, and the
// assertions still hold – they only fail with naive `Duration(days: 1)` arithmetic in DST zones.
final _springForward = DateTime(2026, 3, 29);
final _fallBack = DateTime(2026, 10, 25);

void main() {
  group('CalendarDate', () {
    test('nextDay is the following local midnight on DST switch days', () {
      for (final day in [_springForward, _fallBack]) {
        final next = day.nextDay;
        expect(next, DateTime(day.year, day.month, day.day + 1));
        expect(next.hour, 0);
      }
    });

    test('addDays crosses month and year boundaries', () {
      expect(DateTime(2026, 1, 31).addDays(1), DateTime(2026, 2, 1));
      expect(DateTime(2026, 12, 31).addDays(1), DateTime(2027, 1, 1));
      expect(DateTime(2026, 3, 1).addDays(-1), DateTime(2026, 2, 28));
      expect(DateTime(2028, 3, 1).addDays(-1), DateTime(2028, 2, 29));
    });

    test('dateOnly strips the time of day', () {
      expect(DateTime(2026, 5, 4, 23, 59, 59).dateOnly, DateTime(2026, 5, 4));
    });

    test('startOfWeek returns Monday', () {
      expect(DateTime(2026, 11, 17).startOfWeek, DateTime(2026, 11, 16)); // Tuesday
      expect(DateTime(2026, 11, 22).startOfWeek, DateTime(2026, 11, 16)); // Sunday
      expect(DateTime(2026, 11, 16).startOfWeek, DateTime(2026, 11, 16)); // Monday
    });

    test('calendarDaysUntil counts calendar days across DST switches', () {
      expect(DateTime(2026, 3, 1).calendarDaysUntil(DateTime(2026, 3, 31, 23, 59)), 30);
      expect(DateTime(2026, 10, 1).calendarDaysUntil(DateTime(2026, 10, 31, 23, 59)), 30);
      expect(DateTime(2026, 3, 30).calendarDaysUntil(DateTime(2026, 3, 29)), -1);
    });
  });

  group('statsDateRange', () {
    test('covers the whole week and month, inclusive', () {
      final now = DateTime(2026, 10, 14, 15, 30);

      final day = statsDateRange(StatsRange.day, now);
      expect((day.start, day.end), (DateTime(2026, 10, 14), DateTime(2026, 10, 14)));

      final week = statsDateRange(StatsRange.week, now);
      expect((week.start, week.end), (DateTime(2026, 10, 12), DateTime(2026, 10, 18)));

      final month = statsDateRange(StatsRange.month, now);
      expect((month.start, month.end), (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
    });
  });

  group('AppDatabase day filter on DST switch days', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    for (final day in [_springForward, _fallBack]) {
      test('only returns tasks of ${day.month}/${day.day}', () async {
        await database.createTask(TasksCompanion.insert(title: 'before', assignedDate: day.addDays(-1), sortOrder: 'a0'));
        await database.createTask(TasksCompanion.insert(title: 'on day', assignedDate: day, sortOrder: 'a1'));
        await database.createTask(TasksCompanion.insert(title: 'after', assignedDate: day.nextDay, sortOrder: 'a2'));

        final tasks = await database.getTasksForDay(day);
        expect(tasks.map((t) => t.task.title), ['on day']);

        final watched = await database.watchTasksForDay(day).first;
        expect(watched.map((t) => t.task.title), ['on day']);
      });
    }
  });
}
