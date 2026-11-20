import 'package:drift/drift.dart';

import 'package:focused_task/core/database/tables/categories_table.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get assignedDate => dateTime().named('assigned_date')();

  TextColumn get sortOrder => text().named('sort_order')();

  BoolColumn get isCompleted => boolean().named('is_completed').withDefault(const Constant(false))();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// Cached sum of the task's closed focus sessions in milliseconds (see `focus_sessions`).
  IntColumn get timeSpent => integer().named('time_spent').withDefault(const Constant(0))();

  IntColumn get targetDurationMinutes => integer().nullable()();

  /// Set to `NULL` when the category is deleted, so the task stays (uncategorised).
  IntColumn get categoryId => integer().named('category_id').nullable().references(Categories, #id, onDelete: KeyAction.setNull)();

  /// Start time on `assigned_date` in minutes after local midnight (#10).
  IntColumn get startMinute => integer().named('start_minute').nullable()();

  /// Deadline day (#10).
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();

  /// Deadline time in minutes after local midnight; `NULL` = the default due time from the settings.
  IntColumn get dueMinute => integer().named('due_minute').nullable()();

  /// Reminder lead time; `NULL` = the default from the settings.
  IntColumn get reminderMinutes => integer().named('reminder_minutes').nullable()();

  BoolColumn get reminderOff => boolean().named('reminder_off').withDefault(const Constant(false))();
}
