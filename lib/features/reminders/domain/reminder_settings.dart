/// Settings of the reminders (#10): task reminders, the daily planning nudge and the inactivity reminder. Times of day
/// are minutes after local midnight; working days come from the focus goal (#21).
class ReminderSettings {
  const ReminderSettings({
    this.taskReminders = true,
    this.defaultLead = defaultLeadTime,
    this.defaultDueMinute = defaultDueTime,
    this.dailyPlanning = false,
    this.dailyPlanningMinute = defaultDailyPlanningTime,
    this.inactivity = false,
    this.workStartMinute = defaultWorkStart,
    this.workEndMinute = defaultWorkEnd,
    this.idle = defaultIdle,
  });

  static const defaults = ReminderSettings();

  static const defaultLeadTime = Duration(minutes: 15);
  static const defaultDueTime = 17 * 60;
  static const defaultDailyPlanningTime = 8 * 60 + 30;
  static const defaultWorkStart = 9 * 60;
  static const defaultWorkEnd = 17 * 60;
  static const defaultIdle = Duration(minutes: 60);

  /// Lead times offered for task reminders, in minutes.
  static const leadOptions = [5, 10, 15, 30, 60];

  /// Idle times offered for the inactivity reminder, in minutes.
  static const idleOptions = [30, 45, 60, 90, 120];

  /// Reminders for tasks with a start time or deadline.
  final bool taskReminders;

  /// Lead time of a task reminder when the task has none of its own.
  final Duration defaultLead;

  /// Time of a deadline that has only a date.
  final int defaultDueMinute;

  /// "Plan your day" at [dailyPlanningMinute] on working days when the day has no tasks yet.
  final bool dailyPlanning;
  final int dailyPlanningMinute;

  /// "Ready for the next focus block?" after [idle] without a focus session, within the working hours.
  final bool inactivity;
  final int workStartMinute;
  final int workEndMinute;
  final Duration idle;

  ReminderSettings copyWith({
    bool? taskReminders,
    Duration? defaultLead,
    int? defaultDueMinute,
    bool? dailyPlanning,
    int? dailyPlanningMinute,
    bool? inactivity,
    int? workStartMinute,
    int? workEndMinute,
    Duration? idle,
  }) {
    return ReminderSettings(
      taskReminders: taskReminders ?? this.taskReminders,
      defaultLead: defaultLead ?? this.defaultLead,
      defaultDueMinute: defaultDueMinute ?? this.defaultDueMinute,
      dailyPlanning: dailyPlanning ?? this.dailyPlanning,
      dailyPlanningMinute: dailyPlanningMinute ?? this.dailyPlanningMinute,
      inactivity: inactivity ?? this.inactivity,
      workStartMinute: workStartMinute ?? this.workStartMinute,
      workEndMinute: workEndMinute ?? this.workEndMinute,
      idle: idle ?? this.idle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderSettings &&
        other.taskReminders == taskReminders &&
        other.defaultLead == defaultLead &&
        other.defaultDueMinute == defaultDueMinute &&
        other.dailyPlanning == dailyPlanning &&
        other.dailyPlanningMinute == dailyPlanningMinute &&
        other.inactivity == inactivity &&
        other.workStartMinute == workStartMinute &&
        other.workEndMinute == workEndMinute &&
        other.idle == idle;
  }

  @override
  int get hashCode => Object.hash(taskReminders, defaultLead, defaultDueMinute, dailyPlanning, dailyPlanningMinute, inactivity, workStartMinute, workEndMinute, idle);
}
