import 'package:drift/drift.dart';

import 'package:focused_task/core/database/tables/tasks_table.dart';

/// Every focus (or break) interval. `tasks.time_spent` caches the sum of a task's closed focus sessions.
@DataClassName('FocusSessionRow')
@TableIndex(name: 'focus_sessions_started_at', columns: {#startedAt})
class FocusSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Set to `NULL` when the task is deleted, so its time stays in the statistics.
  IntColumn get taskId => integer().named('task_id').nullable().references(Tasks, #id, onDelete: KeyAction.setNull)();

  /// `focus` or `break`.
  TextColumn get kind => text().withDefault(const Constant('focus'))();

  DateTimeColumn get startedAt => dateTime().named('started_at')();

  /// `NULL` while running or when the session was never closed (crash).
  DateTimeColumn get endedAt => dateTime().named('ended_at').nullable()();

  /// Heartbeat of the running session.
  DateTimeColumn get lastSeenAt => dateTime().named('last_seen_at')();

  /// paused | completed | exited | background | recovered | discarded | manual | migrated
  TextColumn get endReason => text().named('end_reason').nullable()();

  IntColumn get interruptions => integer().withDefault(const Constant(0))();
}
