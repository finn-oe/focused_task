import 'package:focused_task/features/recurrence/domain/repeat_pattern.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';

export 'package:focused_task/features/recurrence/domain/repeat_pattern.dart';

/// A recurring task (#24): the template every occurrence is created from, and when it repeats.
class RecurrenceRule {
  const RecurrenceRule({
    this.id = 0,
    required this.title,
    this.description,
    this.targetDurationMinutes,
    this.priority = TaskPriority.low,
    this.categoryId,
    this.todoTitles = const [],
    required this.pattern,
    required this.startDate,
    this.startMinute,
    this.dueOffsetDays,
    this.dueMinute,
    this.reminderMinutes,
    this.reminderOff = false,
  });

  /// The rule for [draft] repeating with [pattern] from [startDate] (the occurrence being edited, or the task's day). A
  /// deadline is kept relative to the task's day, so every occurrence gets the same lead.
  factory RecurrenceRule.fromDraft(TaskDraft draft, RepeatPattern pattern, {required DateTime startDate}) {
    final schedule = draft.schedule;
    final due = schedule.dueDate;
    return RecurrenceRule(
      title: draft.title.trim(),
      description: draft.description.trim().isEmpty ? null : draft.description.trim(),
      targetDurationMinutes: draft.targetMinutes,
      priority: draft.priority,
      categoryId: draft.categoryId,
      todoTitles: [
        for (final todo in draft.todos)
          if (todo.title.trim().isNotEmpty) todo.title.trim(),
      ],
      pattern: pattern,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      startMinute: schedule.startMinute,
      dueOffsetDays: due == null ? null : DateTime.utc(due.year, due.month, due.day).difference(DateTime.utc(draft.date.year, draft.date.month, draft.date.day)).inDays,
      dueMinute: due == null ? null : schedule.dueMinute,
      reminderMinutes: schedule.reminderMinutes,
      reminderOff: schedule.reminderOff,
    );
  }

  final int id;
  final String title;
  final String? description;
  final int? targetDurationMinutes;
  final TaskPriority priority;
  final int? categoryId;

  /// Sub-tasks of every occurrence (unchecked).
  final List<String> todoTitles;
  final RepeatPattern pattern;

  /// First day of the series (a calendar date).
  final DateTime startDate;

  /// Start time of every occurrence on its own day (#10).
  final int? startMinute;

  /// Deadline in days after the occurrence's date (#10); `null` = no deadline.
  final int? dueOffsetDays;
  final int? dueMinute;
  final int? reminderMinutes;
  final bool reminderOff;

  /// Start time, deadline and reminder of the occurrence on [date]: the start time is on that day, the deadline
  /// [dueOffsetDays] calendar days later.
  TaskSchedule scheduleOn(DateTime date) {
    final offset = dueOffsetDays;
    return TaskSchedule(
      startMinute: startMinute,
      dueDate: offset == null ? null : DateTime(date.year, date.month, date.day + offset),
      dueMinute: offset == null ? null : dueMinute,
      reminderMinutes: reminderMinutes,
      reminderOff: reminderOff,
    );
  }

  RecurrenceRule copyWith({int? id, RepeatPattern? pattern, DateTime? startDate}) {
    return RecurrenceRule(
      id: id ?? this.id,
      title: title,
      description: description,
      targetDurationMinutes: targetDurationMinutes,
      priority: priority,
      categoryId: categoryId,
      todoTitles: todoTitles,
      pattern: pattern ?? this.pattern,
      startDate: startDate ?? this.startDate,
      startMinute: startMinute,
      dueOffsetDays: dueOffsetDays,
      dueMinute: dueMinute,
      reminderMinutes: reminderMinutes,
      reminderOff: reminderOff,
    );
  }
}
