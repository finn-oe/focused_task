import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';

/// Log of focus sessions. At most one session is open at a time.
abstract class IFocusSessionRepository {
  /// Starts a session at [at]. A session that is still open is closed first at its last activity (reason
  /// [EndReason.recovered]), so the time after the last heartbeat is never counted twice.
  Future<FocusSession> start({int? taskId, SessionKind kind = SessionKind.focus, required DateTime at});

  /// Records that the open session [id] is still alive at [at].
  Future<void> heartbeat(int id, DateTime at);

  /// Ends session [id] at [at] and adds its duration to the task's tracked time. [EndReason.discarded] drops the
  /// time (the session ends where it started). Ending a session that is already closed does nothing.
  Future<void> end(int id, DateTime at, EndReason reason);

  /// Counts one interruption (#28) on session [id] (also after it has ended).
  Future<void> addInterruption(int id);

  /// The currently open session, if any.
  Future<FocusSession?> openSession();

  /// Sessions that were never closed (e.g. the app was killed), with their task titles.
  Future<List<FocusSession>> unfinishedSessions();

  /// Sessions overlapping `[start, endExclusive)`.
  Stream<List<FocusSession>> watchInRange(DateTime start, DateTime endExclusive);

  /// Focus time per day of [range], split at local midnight.
  Future<Map<DateTime, Duration>> focusTimeByDay(DateRange range);

  /// Adds [duration] of manually tracked time to [taskId] on [day] (e.g. work done without the app).
  Future<void> addManualTime({required int taskId, required DateTime day, required Duration duration});
}
