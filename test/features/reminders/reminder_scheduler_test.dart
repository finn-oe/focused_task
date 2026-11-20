import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/reminders/domain/reminder_scheduler.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

import '../../helpers/task_builders.dart';

void main() {
  const scheduler = ReminderScheduler();
  const settings = ReminderSettings.defaults; // 15 min lead, deadlines without time at 17:00
  // Wednesday.
  final day = DateTime(2026, 11, 18);
  DateTime at(int hour, [int minute = 0, DateTime? on]) {
    final date = on ?? day;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  TaskEntity task({int id = 1, TaskSchedule schedule = TaskSchedule.none, int? estimate, Duration tracked = Duration.zero, bool completed = false, DateTime? assigned}) {
    return buildTask(id: id, assignedDate: assigned ?? day, schedule: schedule, targetDurationMinutes: estimate, timeSpent: tracked.inMilliseconds, isCompleted: completed);
  }

  group('reminderFor', () {
    test('start set: lead time before the start, on the task day', () {
      final time = scheduler.reminderFor(task(schedule: const TaskSchedule(startMinute: 14 * 60)), settings);
      expect(time, TaskReminderTime(TaskReminderKind.start, at(13, 45), at(14)));
    });

    test('the start wins over a deadline', () {
      final time = scheduler.reminderFor(
        task(
          schedule: TaskSchedule(startMinute: 10 * 60, dueDate: day.add(const Duration(days: 2))),
        ),
        settings,
      );
      expect(time?.kind, TaskReminderKind.start);
    });

    test('due without estimate: lead time before the deadline (default due time for a date only)', () {
      final time = scheduler.reminderFor(task(schedule: TaskSchedule(dueDate: day)), settings);
      expect(time, TaskReminderTime(TaskReminderKind.due, at(16, 45), at(17)));
    });

    test('due with an estimate: early enough for the work still left', () {
      final time = scheduler.reminderFor(
        task(
          schedule: TaskSchedule(dueDate: day, dueMinute: 18 * 60),
          estimate: 120,
        ),
        settings,
      );
      expect(time?.at, at(15, 45));
    });

    test('tracked time moves the due reminder later; more tracked than estimated counts as nothing left', () {
      final schedule = TaskSchedule(dueDate: day, dueMinute: 18 * 60);
      expect(scheduler.reminderFor(task(schedule: schedule, estimate: 120, tracked: const Duration(minutes: 90)), settings)?.at, at(17, 15));
      expect(scheduler.reminderFor(task(schedule: schedule, estimate: 60, tracked: const Duration(minutes: 90)), settings)?.at, at(17, 45));
    });

    test('a task lead time overrides the default', () {
      final time = scheduler.reminderFor(task(schedule: const TaskSchedule(startMinute: 14 * 60, reminderMinutes: 60)), settings);
      expect(time?.at, at(13));
      final custom = scheduler.reminderFor(task(schedule: const TaskSchedule(startMinute: 14 * 60)), settings.copyWith(defaultLead: const Duration(minutes: 5)));
      expect(custom?.at, at(13, 55));
    });

    test('no reminder without times, for completed tasks or when it is off', () {
      expect(scheduler.reminderFor(task(), settings), isNull);
      expect(scheduler.reminderFor(task(schedule: const TaskSchedule(startMinute: 600), completed: true), settings), isNull);
      expect(scheduler.reminderFor(task(schedule: const TaskSchedule(startMinute: 600, reminderOff: true)), settings), isNull);
    });

    test('on a DST day the start keeps its wall-clock time', () {
      // Clocks change in the night to 29 March (EU) and 8 March (US) 2026; either way the time of day stays.
      for (final dstDay in [DateTime(2026, 3, 29), DateTime(2026, 3, 8), DateTime(2026, 10, 25), DateTime(2026, 11, 1)]) {
        final time = scheduler.reminderFor(
          task(
            assigned: dstDay,
            schedule: const TaskSchedule(startMinute: 9 * 60),
          ),
          settings,
        )!;
        expect((time.anchor.hour, time.anchor.minute, time.anchor.day), (9, 0, dstDay.day));
        expect((time.at.hour, time.at.minute), (8, 45));
      }
    });
  });

  group('planTasks', () {
    final start14 = task(schedule: const TaskSchedule(startMinute: 14 * 60));

    test('a future reminder is scheduled', () {
      final planned = scheduler.planTasks([start14], settings, at(9));
      expect(planned.single.immediate, isFalse);
      expect(planned.single.time.at, at(13, 45));
    });

    test('a passed reminder time with the start still ahead is shown at once – only once', () {
      final now = at(13, 50);
      final planned = scheduler.planTasks([start14], settings, now);
      expect(planned.single.immediate, isTrue);

      final again = scheduler.planTasks(
        [start14],
        settings,
        now.add(const Duration(minutes: 1)),
        delivered: {1: DeliveredReminder(at: now, anchor: at(14))},
      );
      expect(again, isEmpty);
    });

    test('a reminder that was scheduled and fired is not shown again', () {
      final planned = scheduler.planTasks(
        [start14],
        settings,
        at(13, 55),
        delivered: {1: DeliveredReminder(at: at(13, 45), anchor: at(14))},
      );
      expect(planned, isEmpty);
    });

    test('a new start time after a fired reminder gets its own reminder', () {
      final moved = task(schedule: const TaskSchedule(startMinute: 14 * 60 + 5));
      final planned = scheduler.planTasks(
        [moved],
        settings,
        at(13, 55),
        delivered: {1: DeliveredReminder(at: at(13, 45), anchor: at(14))},
      );
      expect(planned.single.immediate, isTrue);
    });

    test('nothing once the start or deadline has passed, nothing when task reminders are off', () {
      expect(scheduler.planTasks([start14], settings, at(14, 1)), isEmpty);
      expect(scheduler.planTasks([start14], settings.copyWith(taskReminders: false), at(9)), isEmpty);
    });

    test('earliest first, at most maxTaskReminders', () {
      final many = [
        for (var id = 1; id <= ReminderScheduler.maxTaskReminders + 5; id++)
          task(
            id: id,
            assigned: day.add(Duration(days: id)),
            schedule: const TaskSchedule(startMinute: 600),
          ),
      ];
      final planned = scheduler.planTasks(many.reversed, settings, at(9));
      expect(planned, hasLength(ReminderScheduler.maxTaskReminders));
      expect(planned.first.task.id, 1);
    });
  });

  group('nextDailyPlanning', () {
    final on = settings.copyWith(dailyPlanning: true); // 08:30
    const weekdays = {1, 2, 3, 4, 5};

    test('today at the chosen time when today has no tasks', () {
      expect(scheduler.nextDailyPlanning(on, workingDays: weekdays, daysWithTasks: const {}, now: at(7)), at(8, 30));
    });

    test('skips days that already have tasks and days after the time', () {
      expect(scheduler.nextDailyPlanning(on, workingDays: weekdays, daysWithTasks: {day}, now: at(7)), at(8, 30, DateTime(2026, 11, 19)));
      expect(scheduler.nextDailyPlanning(on, workingDays: weekdays, daysWithTasks: const {}, now: at(9)), at(8, 30, DateTime(2026, 11, 19)));
    });

    test('skips weekends (not working days)', () {
      // Friday after the time → Monday.
      expect(scheduler.nextDailyPlanning(on, workingDays: weekdays, daysWithTasks: const {}, now: at(9, 0, DateTime(2026, 11, 20))), at(8, 30, DateTime(2026, 11, 23)));
    });

    test('off: nothing', () {
      expect(scheduler.nextDailyPlanning(settings, workingDays: weekdays, daysWithTasks: const {}, now: at(7)), isNull);
    });
  });

  group('nextInactivity', () {
    final on = settings.copyWith(inactivity: true); // 09:00–17:00, 60 min
    const weekdays = {1, 2, 3, 4, 5};

    test('idle time after the last activity, within working hours', () {
      expect(scheduler.nextInactivity(on, workingDays: weekdays, lastActivity: at(10, 20), sessionRunning: false, now: at(10, 30)), at(11, 20));
    });

    test('activity before the working hours counts from their start', () {
      expect(scheduler.nextInactivity(on, workingDays: weekdays, lastActivity: at(7), sessionRunning: false, now: at(7, 5)), at(10));
    });

    test('too late for today: the next working day, skipping the weekend', () {
      // Friday 16:30 + 60 min is after 17:00 → Monday 10:00.
      final friday = DateTime(2026, 11, 20);
      expect(
        scheduler.nextInactivity(on, workingDays: weekdays, lastActivity: at(16, 30, friday), sessionRunning: false, now: at(16, 31, friday)),
        at(10, 0, DateTime(2026, 11, 23)),
      );
    });

    test('a passed time is not repeated the same day', () {
      expect(scheduler.nextInactivity(on, workingDays: weekdays, lastActivity: at(9), sessionRunning: false, now: at(11)), at(10, 0, DateTime(2026, 11, 19)));
    });

    test('nothing while a session runs, or when it is off', () {
      expect(scheduler.nextInactivity(on, workingDays: weekdays, lastActivity: at(9), sessionRunning: true, now: at(9, 5)), isNull);
      expect(scheduler.nextInactivity(settings, workingDays: weekdays, lastActivity: at(9), sessionRunning: false, now: at(9, 5)), isNull);
    });

    test('working hours on a DST day keep their wall-clock times', () {
      // Sunday 29 March 2026 made a working day for the test.
      final dstDay = DateTime(2026, 3, 29);
      final next = scheduler.nextInactivity(on, workingDays: {DateTime.sunday}, lastActivity: at(6, 0, dstDay), sessionRunning: false, now: at(6, 0, dstDay))!;
      expect((next.day, next.hour, next.minute), (29, 10, 0));
    });
  });
}
