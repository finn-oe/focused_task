import 'package:drift/drift.dart';

import 'package:focused_task/core/database/tables/focus_sessions_table.dart';

/// Distraction inbox (#28): thoughts parked during focus, to be reviewed afterwards.
@DataClassName('InboxItemRow')
class InboxItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The parked thought. (`text` would clash with [Table.text].)
  TextColumn get content => text().named('text')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// The focus session it was parked in; `NULL` if parked outside focus or the session is gone.
  IntColumn get sessionId => integer().named('session_id').nullable().references(FocusSessions, #id, onDelete: KeyAction.setNull)();

  /// When it was turned into a task or dismissed; `NULL` while it waits for review.
  DateTimeColumn get resolvedAt => dateTime().named('resolved_at').nullable()();
}
