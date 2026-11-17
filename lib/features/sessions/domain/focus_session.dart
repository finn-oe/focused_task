/// What a session was used for. Breaks (#27) don't count as focus time.
enum SessionKind {
  focus,
  breakTime;

  /// Value stored in the database.
  String get storageName => switch (this) {
    SessionKind.focus => 'focus',
    SessionKind.breakTime => 'break',
  };

  static SessionKind fromStorage(String value) => value == 'break' ? SessionKind.breakTime : SessionKind.focus;
}

/// Why a session ended. Stored by [name]; `skipped` = the task was moved to the end of the focus queue.
enum EndReason {
  paused,
  completed,
  skipped,
  exited,
  background,
  recovered,
  discarded,
  manual,
  migrated;

  static EndReason? fromStorage(String? value) => value == null ? null : EndReason.values.asNameMap()[value];
}

/// One continuous interval of focus (or break) time.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.kind,
    required this.startedAt,
    required this.lastSeenAt,
    this.endedAt,
    this.endReason,
    this.interruptions = 0,
    this.taskTitle,
  });

  final int id;

  /// `null` if the task was deleted (the time still counts in the statistics) or the session belongs to no task.
  final int? taskId;
  final SessionKind kind;
  final DateTime startedAt;

  /// `null` while the session is running or was never closed (e.g. the app was killed).
  final DateTime? endedAt;

  /// Last heartbeat of the running session.
  final DateTime lastSeenAt;
  final EndReason? endReason;
  final int interruptions;

  /// Title of [taskId], if loaded with the session (e.g. for the recovery dialog).
  final String? taskTitle;

  bool get isOpen => endedAt == null;

  /// When the session was last known to be alive: [lastSeenAt], but never before [startedAt].
  DateTime get lastActivityAt => lastSeenAt.isAfter(startedAt) ? lastSeenAt : startedAt;

  /// End used for statistics: the real end, or the last heartbeat of an open session.
  DateTime get effectiveEnd => endedAt ?? lastActivityAt;

  Duration get duration {
    final value = effectiveEnd.difference(startedAt);
    return value.isNegative ? Duration.zero : value;
  }

  FocusSession copyWith({DateTime? endedAt, DateTime? lastSeenAt, EndReason? endReason, int? taskId, bool clearTaskId = false}) {
    return FocusSession(
      id: id,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
      kind: kind,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      endReason: endReason ?? this.endReason,
      interruptions: interruptions,
      taskTitle: taskTitle,
    );
  }
}
