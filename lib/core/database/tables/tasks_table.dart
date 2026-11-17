import 'package:drift/drift.dart';

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
}
