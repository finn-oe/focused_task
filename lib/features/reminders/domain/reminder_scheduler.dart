import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// What a task reminder points at.
enum TaskReminderKind { start, due }

/// When a task's reminder is due, and the start or deadline ([anchor]) it reminds of.
class TaskReminderTime {
  const TaskReminderTime(this.kind, this.at, this.anchor);

  final TaskReminderKind kind;
  final DateTime at;
  final DateTime anchor;

  @override
  bool operator ==(Object other) => other is TaskReminderTime && other.kind == kind && other.at == at && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(kind, at, anchor);

  @override
  String toString() => 'TaskReminderTime($kind, $at, $anchor)';
}

/// A reminder that was handed to the system (scheduled for [at], or shown at [at]) for the start or deadline [anchor].
/// Remembered across restarts, so a reminder whose time has passed is not shown twice.
class DeliveredReminder {
  const DeliveredReminder({required this.at, required this.anchor});

  final DateTime at;
  final DateTime anchor;
}

/// A task reminder to hand to the system: at [time.at], or right now when [immediate].
class PlannedTaskReminder {
  const PlannedTaskReminder(this.task, this.time, {required this.immediate});

  final TaskEntity task;
  final TaskReminderTime time;
  final bool immediate;
}

/// Pure rules for when reminders fire (#10). All times are local; days are built with `DateTime(y, m, d, 0, minute)`
/// so DST switches don't shift them.
class ReminderScheduler {
  const ReminderScheduler();

  /// At most this many task reminders are scheduled at once (iOS keeps only 64 pending notifications).
  static const maxTaskReminders = 40;

  /// How many days ahead the daily planning and inactivity reminders look for their next time.
  static const lookAheadDays = 8;

  /// The reminder of [task], ignoring the current time: before the start if it has one, otherwise before the deadline
  /// minus the work still left (estimate − tracked, never negative). `null` for completed tasks, tasks without times
  /// and tasks whose reminder is off.
  TaskReminderTime? reminderFor(TaskEntity task, ReminderSettings settings) {
    final schedule = task.schedule;
    if (task.isCompleted || schedule.reminderOff) return null;
    final lead = schedule.lead(settings.defaultLead);
    final start = task.startAt;
    if (start != null) return TaskReminderTime(TaskReminderKind.start, start.subtract(lead), start);
    final due = schedule.dueAt(defaultDueMinute: settings.defaultDueMinute);
    if (due == null) return null;
    final estimate = Duration(minutes: task.targetDurationMinutes ?? 0);
    final left = estimate - Duration(milliseconds: task.timeSpent);
    return TaskReminderTime(TaskReminderKind.due, due.subtract(left.isNegative ? Duration.zero : left).subtract(lead), due);
  }

  /// The task reminders to hand to the system at [now], earliest first and at most [maxTaskReminders].
  ///
  /// A reminder in the future is scheduled. One whose time has passed while its start or deadline is still ahead is
  /// shown right away, once: [delivered] (by task id) tells which were already scheduled or shown for that anchor.
  /// Nothing is planned once the start or deadline itself has passed.
  List<PlannedTaskReminder> planTasks(Iterable<TaskEntity> tasks, ReminderSettings settings, DateTime now, {Map<int, DeliveredReminder> delivered = const {}}) {
    if (!settings.taskReminders) return const [];
    final planned = <PlannedTaskReminder>[];
    for (final task in tasks) {
      final time = reminderFor(task, settings);
      if (time == null || !time.anchor.isAfter(now)) continue;
      if (time.at.isAfter(now)) {
        planned.add(PlannedTaskReminder(task, time, immediate: false));
        continue;
      }
      final previous = delivered[task.id];
      final alreadyFired = previous != null && previous.anchor == time.anchor && !previous.at.isAfter(now);
      if (!alreadyFired) planned.add(PlannedTaskReminder(task, time, immediate: true));
    }
    planned.sort((a, b) => a.time.at.compareTo(b.time.at));
    return planned.length > maxTaskReminders ? planned.sublist(0, maxTaskReminders) : planned;
  }

  /// Next "Plan your day" after [now]: at the chosen time on the next working day that has no tasks (by
  /// [daysWithTasks], calendar dates). `null` when it is off.
  DateTime? nextDailyPlanning(ReminderSettings settings, {required Set<int> workingDays, required Set<DateTime> daysWithTasks, required DateTime now}) {
    if (!settings.dailyPlanning) return null;
    for (var offset = 0; offset < lookAheadDays; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final at = DateTime(day.year, day.month, day.day, 0, settings.dailyPlanningMinute);
      if (!at.isAfter(now) || !workingDays.contains(day.weekday) || daysWithTasks.contains(day)) continue;
      return at;
    }
    return null;
  }

  /// Next "Ready for the next focus block?": [ReminderSettings.idle] after [lastActivity] (the end of the last focus
  /// session, or when the app was opened), counted from the start of the working hours on a working day and only if it
  /// falls within them. `null` while a session runs or when it is off.
  DateTime? nextInactivity(ReminderSettings settings, {required Set<int> workingDays, required DateTime lastActivity, required bool sessionRunning, required DateTime now}) {
    if (!settings.inactivity || sessionRunning) return null;
    final from = lastActivity.isAfter(now) ? now : lastActivity;
    for (var offset = 0; offset < lookAheadDays + (now.difference(from).inDays); offset++) {
      final day = DateTime(from.year, from.month, from.day + offset);
      if (!workingDays.contains(day.weekday)) continue;
      final start = DateTime(day.year, day.month, day.day, 0, settings.workStartMinute);
      final end = DateTime(day.year, day.month, day.day, 0, settings.workEndMinute);
      if (!end.isAfter(start)) continue;
      final at = (from.isAfter(start) ? from : start).add(settings.idle);
      if (at.isAfter(end) || !at.isAfter(now)) continue;
      return at;
    }
    return null;
  }
}
