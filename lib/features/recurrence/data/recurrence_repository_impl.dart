import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/recurrence/domain/i_recurrence_repository.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_expander.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

class RecurrenceRepositoryImpl implements IRecurrenceRepository {
  RecurrenceRepositoryImpl(this._database);

  final AppDatabase _database;

  static const _expander = RecurrenceExpander();

  @override
  Future<RecurrenceRule?> getRule(int id) async {
    final row = await _database.getRecurrenceRule(id);
    return row == null ? null : toEntity(row);
  }

  @override
  Future<int> createRule(RecurrenceRule rule, {int? taskId}) => _database.createRecurrenceRule(toCompanion(rule), taskId: taskId);

  @override
  Future<int?> replaceFrom({required int ruleId, required DateTime from, required int taskId, RecurrenceRule? next}) {
    return _database.splitRecurrenceRule(ruleId: ruleId, from: from, taskId: taskId, next: next == null ? null : toCompanion(next));
  }

  @override
  Future<void> endBefore({required int ruleId, required DateTime from, required int taskId}) async {
    await _database.splitRecurrenceRule(ruleId: ruleId, from: from, taskId: taskId, deleteTask: true);
  }

  @override
  Future<void> ensureOccurrences(DateRange range) async {
    final today = clock.now().dateOnly;
    if (range.end.isBefore(today)) return;
    final days = DateRange(range.start.isBefore(today) ? today : range.start, range.end);
    final rules = (await _database.getRecurrenceRulesOverlapping(days.start, days.end)).map(toEntity).toList();
    if (rules.isEmpty) return;
    final ids = [for (final rule in rules) rule.id];
    final exceptions = <int, Set<DateTime>>{};
    for (final row in await _database.getRecurrenceExceptions(ids, days.start, days.end)) {
      exceptions.putIfAbsent(row.ruleId, () => {}).add(row.date.dateOnly);
    }
    final existing = await _database.getExistingOccurrences(ids, days.start, days.end);
    for (final rule in rules) {
      for (final date in _expander.occurrences(rule, days, exceptions: exceptions[rule.id] ?? const {})) {
        if (existing.contains((rule.id, date))) continue;
        await _database.insertOccurrence(_occurrence(rule, date), rule.todoTitles);
      }
    }
  }

  /// The task of [rule] on [date]; `sort_order` is set when it is inserted.
  static TasksCompanion _occurrence(RecurrenceRule rule, DateTime date) {
    final schedule = rule.scheduleOn(date);
    return TasksCompanion.insert(
      title: rule.title,
      description: Value(rule.description),
      assignedDate: date,
      sortOrder: '',
      priority: Value(rule.priority.value),
      targetDurationMinutes: Value(rule.targetDurationMinutes),
      categoryId: Value(rule.categoryId),
      startMinute: Value(schedule.startMinute),
      dueDate: Value(schedule.dueDate),
      dueMinute: Value(schedule.dueMinute),
      reminderMinutes: Value(schedule.reminderMinutes),
      reminderOff: Value(schedule.reminderOff),
      recurrenceId: Value(rule.id),
      occurrenceDate: Value(date),
    );
  }

  static RecurrenceRulesCompanion toCompanion(RecurrenceRule rule) {
    final pattern = rule.pattern;
    return RecurrenceRulesCompanion.insert(
      title: rule.title,
      description: Value(rule.description),
      targetDurationMinutes: Value(rule.targetDurationMinutes),
      priority: Value(rule.priority.value),
      categoryId: Value(rule.categoryId),
      todosJson: Value(jsonEncode(rule.todoTitles)),
      frequency: pattern.frequency.name,
      intervalDays: Value(pattern.frequency == RepeatFrequency.interval ? pattern.intervalDays : null),
      weekdaysMask: Value(pattern.frequency == RepeatFrequency.weekly ? pattern.weekdaysMask : null),
      monthDay: Value(pattern.frequency == RepeatFrequency.monthly ? pattern.monthDay : null),
      startDate: rule.startDate.dateOnly,
      endDate: Value(pattern.endDate?.dateOnly),
      startMinute: Value(rule.startMinute),
      dueOffsetDays: Value(rule.dueOffsetDays),
      dueMinute: Value(rule.dueOffsetDays == null ? null : rule.dueMinute),
      reminderMinutes: Value(rule.reminderMinutes),
      reminderOff: Value(rule.reminderOff),
    );
  }

  static RecurrenceRule toEntity(RecurrenceRuleRow row) {
    final decoded = jsonDecode(row.todosJson);
    return RecurrenceRule(
      id: row.id,
      title: row.title,
      description: row.description,
      targetDurationMinutes: row.targetDurationMinutes,
      priority: TaskPriority.fromValue(row.priority),
      categoryId: row.categoryId,
      todoTitles: decoded is List ? [for (final title in decoded) '$title'] : const [],
      pattern: RepeatPattern(
        frequency: RepeatFrequency.values.asNameMap()[row.frequency] ?? RepeatFrequency.daily,
        intervalDays: row.intervalDays ?? RepeatPattern.minIntervalDays,
        weekdays: RepeatPattern.weekdaysFromMask(row.weekdaysMask ?? 1 << (row.startDate.weekday - 1)),
        monthDay: row.monthDay ?? row.startDate.day,
        endDate: row.endDate,
      ),
      startDate: row.startDate,
      startMinute: row.startMinute,
      dueOffsetDays: row.dueOffsetDays,
      dueMinute: row.dueMinute,
      reminderMinutes: row.reminderMinutes,
      reminderOff: row.reminderOff,
    );
  }
}
