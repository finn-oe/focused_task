import 'package:drift/drift.dart';

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get assignedDate => dateTime().named('assigned_date')();

  TextColumn get sortOrder => text().named('sort_order')();

  BoolColumn get isCompleted => boolean().named('is_completed').withDefault(const Constant(false))();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  IntColumn get timeSpent => integer().named('time_spent').withDefault(const Constant(0))();

  DateTimeColumn get latestStart => dateTime().named('latest_start').nullable()();

  IntColumn get targetDurationMinutes => integer().nullable()();

  /// Last time the running session was known to be alive (heartbeat). Used to recover crashed sessions.
  DateTimeColumn get lastSeenAt => dateTime().named('last_seen_at').nullable()();
}
