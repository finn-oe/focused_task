import 'package:clock/clock.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart' as focus_time;
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';

class FocusSessionRepositoryImpl implements IFocusSessionRepository {
  FocusSessionRepositoryImpl(this._database);

  final AppDatabase _database;

  /// Maps a database row to the domain entity.
  static FocusSession toEntity(FocusSessionRow row, {String? taskTitle, int? taskCategoryId}) {
    return FocusSession(
      id: row.id,
      taskId: row.taskId,
      kind: SessionKind.fromStorage(row.kind),
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      lastSeenAt: row.lastSeenAt,
      endReason: EndReason.fromStorage(row.endReason),
      interruptions: row.interruptions,
      taskTitle: taskTitle,
      taskCategoryId: taskCategoryId,
    );
  }

  @override
  Future<FocusSession> start({int? taskId, SessionKind kind = SessionKind.focus, required DateTime at}) async {
    return toEntity(await _database.startSession(taskId: taskId, kind: kind.storageName, at: at));
  }

  @override
  Future<void> heartbeat(int id, DateTime at) => _database.sessionHeartbeat(id, at);

  @override
  Future<void> end(int id, DateTime at, EndReason reason) => _database.endSession(id, at, reason.name);

  @override
  Future<void> addInterruption(int id) => _database.addInterruption(id);

  @override
  Future<FocusSession?> openSession() async {
    final row = await _database.getOpenSession();
    return row == null ? null : toEntity(row);
  }

  @override
  Future<List<FocusSession>> unfinishedSessions() async {
    final rows = await _database.getUnfinishedSessions();
    return [for (final row in rows) toEntity(row.session, taskTitle: row.taskTitle)];
  }

  @override
  Stream<List<FocusSession>> watchInRange(DateTime start, DateTime endExclusive) {
    return _database.watchSessionsOverlapping(start, endExclusive).map((rows) => rows.map(toEntity).toList(growable: false));
  }

  @override
  Future<Map<DateTime, Duration>> focusTimeByDay(DateRange range) async {
    final rows = await _database.getSessionsOverlapping(range.start, range.end.nextDay);
    return focus_time.focusTimeByDay(rows.map(toEntity), range);
  }

  @override
  Future<void> addManualTime({required int taskId, required DateTime day, required Duration duration}) {
    if (duration <= Duration.zero) return Future.value();
    final start = DateTime(day.year, day.month, day.day, 12);
    // Never in the future: time worked today ends now at the latest.
    final now = clock.now();
    final latestStart = now.subtract(duration);
    return _database.addManualSession(taskId: taskId, start: start.isAfter(latestStart) ? latestStart : start, duration: duration);
  }
}
