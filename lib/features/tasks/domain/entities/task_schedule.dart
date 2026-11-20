/// Optional start time, deadline and reminder of a task (#10). A task without them behaves as before: times never
/// change the order of the plan, and moving a task to another day keeps its start *time* (now on the new day) and its
/// due date.
class TaskSchedule {
  const TaskSchedule({this.startMinute, this.dueDate, this.dueMinute, this.reminderMinutes, this.reminderOff = false});

  static const none = TaskSchedule();

  /// Start on the task's day, in minutes after local midnight.
  final int? startMinute;

  /// Day of the deadline (a calendar date).
  final DateTime? dueDate;

  /// Time of the deadline in minutes after local midnight; `null` = the default due time from the settings.
  final int? dueMinute;

  /// Lead time of this task's reminder; `null` = the default from the settings.
  final int? reminderMinutes;

  /// No reminder for this task.
  final bool reminderOff;

  bool get hasStart => startMinute != null;

  bool get hasDue => dueDate != null;

  /// Neither a start time nor a deadline.
  bool get isEmpty => startMinute == null && dueDate == null;

  /// The start on [day] (the task's assigned day), or `null` without a start time. Built from the date and the minutes,
  /// so it stays right on days with a DST switch.
  DateTime? startOn(DateTime day) {
    final minute = startMinute;
    return minute == null ? null : DateTime(day.year, day.month, day.day, 0, minute);
  }

  /// The deadline, with [defaultDueMinute] for a due date without a time; `null` without a due date.
  DateTime? dueAt({required int defaultDueMinute}) {
    final date = dueDate;
    return date == null ? null : DateTime(date.year, date.month, date.day, 0, dueMinute ?? defaultDueMinute);
  }

  /// The reminder's lead time, with [defaultLead] when the task has none of its own.
  Duration lead(Duration defaultLead) {
    final minutes = reminderMinutes;
    return minutes == null ? defaultLead : Duration(minutes: minutes);
  }

  TaskSchedule copyWith({
    int? startMinute,
    bool clearStart = false,
    DateTime? dueDate,
    bool clearDue = false,
    int? dueMinute,
    bool clearDueMinute = false,
    int? reminderMinutes,
    bool clearReminderMinutes = false,
    bool? reminderOff,
  }) {
    final date = clearDue ? null : dueDate ?? this.dueDate;
    return TaskSchedule(
      startMinute: clearStart ? null : startMinute ?? this.startMinute,
      dueDate: date == null ? null : DateTime(date.year, date.month, date.day),
      // A due time without a due date means nothing.
      dueMinute: clearDue || clearDueMinute ? null : dueMinute ?? this.dueMinute,
      reminderMinutes: clearReminderMinutes ? null : reminderMinutes ?? this.reminderMinutes,
      reminderOff: reminderOff ?? this.reminderOff,
    );
  }

  @override
  bool operator ==(Object other) {
    final due = dueDate;
    final otherDue = other is TaskSchedule ? other.dueDate : null;
    return other is TaskSchedule &&
        other.startMinute == startMinute &&
        (due == null ? otherDue == null : otherDue != null && otherDue.year == due.year && otherDue.month == due.month && otherDue.day == due.day) &&
        other.dueMinute == dueMinute &&
        other.reminderMinutes == reminderMinutes &&
        other.reminderOff == reminderOff;
  }

  @override
  int get hashCode => Object.hash(startMinute, dueDate?.year, dueDate?.month, dueDate?.day, dueMinute, reminderMinutes, reminderOff);
}
