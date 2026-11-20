import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_expander.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';

const _expander = RecurrenceExpander();

RecurrenceRule _rule(RepeatPattern pattern, DateTime start) => RecurrenceRule(title: 'Task', pattern: pattern, startDate: start);

List<int> _days(List<DateTime> dates) => [for (final date in dates) date.day];

void main() {
  test('daily: every day from the start date, also before it in the range', () {
    final dates = _expander.occurrences(_rule(const RepeatPattern(frequency: RepeatFrequency.daily), DateTime(2026, 3, 3)), DateRange(DateTime(2026, 3, 1), DateTime(2026, 3, 6)));
    expect(_days(dates), [3, 4, 5, 6]);
    expect(dates.every((date) => date == date.dateOnly), isTrue, reason: 'local midnight');
  });

  test('weekdays: Monday to Friday', () {
    // 2026-03-02 is a Monday.
    final dates = _expander.occurrences(
      _rule(const RepeatPattern(frequency: RepeatFrequency.weekdays), DateTime(2026, 3, 1)),
      DateRange(DateTime(2026, 3, 1), DateTime(2026, 3, 14)),
    );
    expect(_days(dates), [2, 3, 4, 5, 6, 9, 10, 11, 12, 13]);
  });

  test('weekly: the days of the weekdays mask', () {
    const pattern = RepeatPattern(frequency: RepeatFrequency.weekly, weekdays: {DateTime.monday, DateTime.thursday});
    expect(pattern.weekdaysMask, 0x9);
    expect(RepeatPattern.weekdaysFromMask(pattern.weekdaysMask), {DateTime.monday, DateTime.thursday});
    final dates = _expander.occurrences(_rule(pattern, DateTime(2026, 3, 1)), DateRange(DateTime(2026, 3, 1), DateTime(2026, 3, 15)));
    expect(_days(dates), [2, 5, 9, 12]);
  });

  test('every N days counts calendar days from the start, across a DST switch', () {
    // Europe/Berlin and the US switch in March; calendar arithmetic doesn't care.
    const pattern = RepeatPattern(frequency: RepeatFrequency.interval, intervalDays: 3);
    final dates = _expander.occurrences(_rule(pattern, DateTime(2026, 3, 25)), DateRange(DateTime(2026, 3, 20), DateTime(2026, 4, 5)));
    expect([for (final date in dates) date.isoDate], ['2026-03-25', '2026-03-28', '2026-03-31', '2026-04-03']);
    expect(dates.every((date) => date.hour == 0 && date.minute == 0), isTrue);
  });

  test('daily across the DST switches keeps one occurrence per calendar day at midnight', () {
    for (final (start, end) in [(DateTime(2026, 3, 27), DateTime(2026, 3, 31)), (DateTime(2026, 10, 23), DateTime(2026, 10, 27))]) {
      final dates = _expander.occurrences(_rule(const RepeatPattern(frequency: RepeatFrequency.daily), start), DateRange(start, end));
      expect(dates, hasLength(5));
      expect(dates.every((date) => date.hour == 0), isTrue);
      expect(dates.toSet(), hasLength(5));
    }
  });

  test('monthly on the 31st falls back to the last day of shorter months', () {
    const pattern = RepeatPattern(frequency: RepeatFrequency.monthly, monthDay: 31);
    final dates = _expander.occurrences(_rule(pattern, DateTime(2026, 1, 31)), DateRange(DateTime(2026, 1, 1), DateTime(2026, 5, 31)));
    expect([for (final date in dates) date.isoDate], ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31']);
  });

  test('monthly on the 29th in a leap year', () {
    const pattern = RepeatPattern(frequency: RepeatFrequency.monthly, monthDay: 29);
    final dates = _expander.occurrences(_rule(pattern, DateTime(2027, 12, 29)), DateRange(DateTime(2028, 1, 1), DateTime(2029, 3, 31)));
    expect([for (final date in dates) date.isoDate].where((iso) => iso.contains('-02-')), ['2028-02-29', '2029-02-28']);
  });

  test('the end date is the last possible day; nothing after it', () {
    final pattern = RepeatPattern(frequency: RepeatFrequency.daily, endDate: DateTime(2026, 3, 4));
    final dates = _expander.occurrences(_rule(pattern, DateTime(2026, 3, 1)), DateRange(DateTime(2026, 3, 1), DateTime(2026, 3, 10)));
    expect(_days(dates), [1, 2, 3, 4]);
    expect(_expander.occurrences(_rule(pattern, DateTime(2026, 3, 1)), DateRange(DateTime(2026, 3, 5), DateTime(2026, 3, 10))), isEmpty);
  });

  test('exceptions (deleted occurrences) are left out', () {
    final dates = _expander.occurrences(
      _rule(const RepeatPattern(frequency: RepeatFrequency.daily), DateTime(2026, 3, 1)),
      DateRange(DateTime(2026, 3, 1), DateTime(2026, 3, 3)),
      exceptions: {DateTime(2026, 3, 2)},
    );
    expect(_days(dates), [1, 3]);
  });

  group('rule from the form', () {
    test('keeps the deadline relative to the day and copies times and reminder', () {
      final draft = TaskDraft.empty(DateTime(2026, 3, 27)).copyWith(
        title: ' Report ',
        schedule: TaskSchedule(startMinute: 9 * 60, dueDate: DateTime(2026, 3, 29), dueMinute: 17 * 60, reminderMinutes: 30),
      );
      final rule = RecurrenceRule.fromDraft(draft, const RepeatPattern(frequency: RepeatFrequency.daily), startDate: DateTime(2026, 3, 27));
      expect((rule.title, rule.dueOffsetDays, rule.startMinute, rule.reminderMinutes), ('Report', 2, 540, 30));
      // Across the DST switch on 2026-03-29 the deadline stays two calendar days later.
      final schedule = rule.scheduleOn(DateTime(2026, 3, 28));
      expect(schedule, TaskSchedule(startMinute: 540, dueDate: DateTime(2026, 3, 30), dueMinute: 1020, reminderMinutes: 30));
      expect(schedule.startOn(DateTime(2026, 3, 29)), DateTime(2026, 3, 29, 9));
    });

    test('without a deadline the occurrences have none', () {
      final draft = TaskDraft.empty(DateTime(2026, 3, 2)).copyWith(title: 'Gym', schedule: const TaskSchedule(reminderOff: true));
      final rule = RecurrenceRule.fromDraft(draft, const RepeatPattern(frequency: RepeatFrequency.weekdays), startDate: DateTime(2026, 3, 2));
      expect(rule.scheduleOn(DateTime(2026, 3, 3)), const TaskSchedule(reminderOff: true));
    });
  });

  test('patterns compare by the details of their frequency', () {
    expect(RepeatPattern.startingOn(RepeatFrequency.daily, DateTime(2026, 3, 2)), RepeatPattern.startingOn(RepeatFrequency.daily, DateTime(2026, 3, 9)));
    expect(RepeatPattern.startingOn(RepeatFrequency.weekly, DateTime(2026, 3, 2)) == RepeatPattern.startingOn(RepeatFrequency.weekly, DateTime(2026, 3, 3)), isFalse);
    expect(const RepeatPattern(frequency: RepeatFrequency.daily) == RepeatPattern(frequency: RepeatFrequency.daily, endDate: DateTime(2026, 4, 1)), isFalse);
  });
}
