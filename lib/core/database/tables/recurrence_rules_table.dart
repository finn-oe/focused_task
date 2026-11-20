import 'package:drift/drift.dart';

import 'package:focused_task/core/database/tables/categories_table.dart';

/// Recurring tasks (#24): a template plus a repeat pattern. Occurrences are ordinary `tasks` rows that point back here
/// (`recurrence_id`, `occurrence_date`) and are created lazily for the days that are shown.
@DataClassName('RecurrenceRuleRow')
class RecurrenceRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  IntColumn get targetDurationMinutes => integer().named('target_duration_minutes').nullable()();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  IntColumn get categoryId => integer().named('category_id').nullable().references(Categories, #id, onDelete: KeyAction.setNull)();

  /// Titles of the sub-tasks every occurrence gets, as a JSON list of strings.
  TextColumn get todosJson => text().named('todos_json').withDefault(const Constant('[]'))();

  /// `daily`, `weekdays`, `weekly`, `interval` or `monthly`.
  TextColumn get frequency => text()();

  /// Days between occurrences for `interval`.
  IntColumn get intervalDays => integer().named('interval_days').nullable()();

  /// Days of the week for `weekly`: bit `weekday - 1` (Monday = bit 0).
  IntColumn get weekdaysMask => integer().named('weekdays_mask').nullable()();

  /// Day of the month for `monthly`; months without it use their last day.
  IntColumn get monthDay => integer().named('month_day').nullable()();

  DateTimeColumn get startDate => dateTime().named('start_date')();

  /// Last day with an occurrence; `NULL` = no end.
  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();

  /// Start time of every occurrence on its day, in minutes after local midnight (#10).
  IntColumn get startMinute => integer().named('start_minute').nullable()();

  /// Deadline of an occurrence in days after its date (#10).
  IntColumn get dueOffsetDays => integer().named('due_offset_days').nullable()();

  IntColumn get dueMinute => integer().named('due_minute').nullable()();

  IntColumn get reminderMinutes => integer().named('reminder_minutes').nullable()();

  BoolColumn get reminderOff => boolean().named('reminder_off').withDefault(const Constant(false))();
}

/// Days of a rule whose occurrence was deleted, so it isn't created again.
@DataClassName('RecurrenceExceptionRow')
class RecurrenceExceptions extends Table {
  IntColumn get ruleId => integer().named('rule_id').references(RecurrenceRules, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get date => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ruleId, date};
}
