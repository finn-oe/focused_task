import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/target_alarm.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

/// How to close sessions that were left open (e.g. the app was killed while focusing).
enum SessionRecovery {
  /// Count the time up to the last heartbeat – the safe default.
  untilLastActivity,

  /// Count the time up to now, e.g. when the user kept working while the app was closed.
  untilNow,

  /// Drop the time of the unfinished session.
  discard,
}

class FocusModeState {
  const FocusModeState({
    required this.selectedDay,
    required this.now,
    required this.sessionBaseMs,
    required this.isLoading,
    required this.isPaused,
    this.sessionStartedAt,
    this.currentTask,
    this.error,
    this.shouldShowFinishedForToday = false,
    this.shouldShowAlarm = false,
    this.hasAlarmPlayedForCurrentTask = false,
  });

  factory FocusModeState.initial() {
    final now = clock.now();
    return FocusModeState(selectedDay: now.dateOnly, now: now, sessionBaseMs: 0, isLoading: false, isPaused: true);
  }

  final DateTime selectedDay;
  final DateTime now;
  final int sessionBaseMs;
  final DateTime? sessionStartedAt;
  final bool isLoading;
  final bool isPaused;
  final TaskEntity? currentTask;
  final String? error;
  final bool shouldShowFinishedForToday;
  final bool shouldShowAlarm;

  /// Whether the target alarm already rang (or the target was already exceeded) for [currentTask].
  final bool hasAlarmPlayedForCurrentTask;

  Duration get totalSessionDuration {
    final runningMs = isPaused || sessionStartedAt == null ? 0 : now.difference(sessionStartedAt!).inMilliseconds;
    return Duration(milliseconds: sessionBaseMs + runningMs);
  }

  Duration get currentTaskDuration {
    if (currentTask == null) {
      return Duration.zero;
    }

    return currentTask!.elapsedAt(now);
  }

  FocusModeState copyWith({
    DateTime? selectedDay,
    DateTime? now,
    int? sessionBaseMs,
    DateTime? sessionStartedAt,
    bool? isLoading,
    bool? isPaused,
    TaskEntity? currentTask,
    String? error,
    bool? shouldShowFinishedForToday,
    bool? shouldShowAlarm,
    bool? hasAlarmPlayedForCurrentTask,
    bool clearCurrentTask = false,
    bool clearSessionStartedAt = false,
    bool clearError = false,
  }) {
    return FocusModeState(
      selectedDay: selectedDay ?? this.selectedDay,
      now: now ?? this.now,
      sessionBaseMs: sessionBaseMs ?? this.sessionBaseMs,
      sessionStartedAt: clearSessionStartedAt ? null : sessionStartedAt ?? this.sessionStartedAt,
      isLoading: isLoading ?? this.isLoading,
      isPaused: isPaused ?? this.isPaused,
      currentTask: clearCurrentTask ? null : currentTask ?? this.currentTask,
      error: clearError ? null : error ?? this.error,
      shouldShowFinishedForToday: shouldShowFinishedForToday ?? this.shouldShowFinishedForToday,
      shouldShowAlarm: shouldShowAlarm ?? this.shouldShowAlarm,
      hasAlarmPlayedForCurrentTask: hasAlarmPlayedForCurrentTask ?? this.hasAlarmPlayedForCurrentTask,
    );
  }
}

class FocusModeNotifier extends Notifier<FocusModeState> {
  late ITaskRepository _repository;
  late IFocusSessionRepository _sessions;
  late TargetAlarm _alarm;
  Timer? _ticker;

  /// The open focus session of [FocusModeState.currentTask], or `null` while paused.
  int? _sessionId;
  DateTime? _lastHeartbeat;

  /// How often a running session records that it is still alive.
  static const heartbeatInterval = Duration(seconds: 30);

  @override
  FocusModeState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _sessions = ref.watch(focusSessionRepositoryProvider);
    _alarm = ref.watch(targetAlarmProvider);
    ref.onDispose(_stopTicker);
    return FocusModeState.initial();
  }

  Future<void> initializeForDay(DateTime day) async {
    state = state.copyWith(selectedDay: day.dateOnly, isLoading: true, clearError: true);

    await _loadNextTask();
  }

  /// Time left until [task] reaches its target, or `null` if it has no target.
  static Duration? _remainingUntilTarget(TaskEntity task, DateTime now) {
    final target = task.targetDurationMinutes;
    if (target == null) {
      return null;
    }
    return Duration(minutes: target) - task.elapsedAt(now);
  }

  /// Schedules the OS/background alarm for the running [task] – only if its target is still ahead.
  Future<void> _scheduleTargetAlarm(TaskEntity task, DateTime now) async {
    final remaining = _remainingUntilTarget(task, now);
    if (remaining == null || remaining <= Duration.zero || state.hasAlarmPlayedForCurrentTask) {
      return;
    }
    // Read at schedule time (not watched): switching the language must not reset a running session.
    final l10n = ref.read(appLocalizationsProvider);
    final notification = AlarmNotification(title: l10n.focusTimeIsUp, body: l10n.focusAlarmNotificationBody(task.title), stopButton: l10n.focusAlarmStopButton);
    await _alarm.schedule(notification: notification, at: now.add(remaining));
  }

  Future<void> _loadNextTask() async {
    final task = await _repository.getNextIncompleteTaskForDay(state.selectedDay);
    if (task == null) {
      _stopTicker();
      state = state.copyWith(
        isLoading: false,
        isPaused: true,
        clearCurrentTask: true,
        clearSessionStartedAt: true,
        sessionBaseMs: 0,
        shouldShowFinishedForToday: true,
        shouldShowAlarm: false,
        hasAlarmPlayedForCurrentTask: false,
      );
      return;
    }

    // Continue the task's open session (e.g. after a crash without recovery), otherwise start a new one.
    final open = await _sessions.openSession();
    _sessionId = open != null && open.taskId == task.id ? open.id : (await _sessions.start(taskId: task.id, at: clock.now())).id;
    final current = (await _repository.getTaskById(task.id)) ?? task;

    final now = clock.now();
    final remaining = _remainingUntilTarget(current, now);
    _startTicker();
    state = state.copyWith(
      currentTask: current,
      isPaused: false,
      sessionStartedAt: state.sessionStartedAt ?? now,
      now: now,
      isLoading: false,
      clearError: true,
      shouldShowFinishedForToday: false,
      // A task that is already over its target must not ring again every time focus is (re)entered.
      hasAlarmPlayedForCurrentTask: remaining != null && remaining <= Duration.zero,
    );

    await _scheduleTargetAlarm(current, now);
  }

  /// Pauses the running session; [reason] is recorded in the session log.
  Future<void> pauseSession({EndReason reason = EndReason.paused}) async {
    final task = state.currentTask;
    if (task == null || state.isPaused) {
      return;
    }

    await _alarm.cancel();

    final now = clock.now();
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId != null) {
      await _sessions.end(sessionId, now, reason);
    }

    final updatedTask = await _repository.getTaskById(task.id);
    final runningMs = state.sessionStartedAt == null ? 0 : now.difference(state.sessionStartedAt!).inMilliseconds;

    _stopTicker();
    state = state.copyWith(
      currentTask: updatedTask,
      sessionBaseMs: state.sessionBaseMs + runningMs,
      isPaused: true,
      clearSessionStartedAt: true,
      now: now,
      shouldShowFinishedForToday: false,
    );
  }

  Future<void> resumeSession() async {
    final task = state.currentTask;
    if (task == null || !state.isPaused) {
      return;
    }

    final now = clock.now();
    _sessionId = (await _sessions.start(taskId: task.id, at: now)).id;
    final updatedTask = await _repository.getTaskById(task.id);

    _startTicker();
    state = state.copyWith(currentTask: updatedTask, isPaused: false, sessionStartedAt: now, now: now, shouldShowFinishedForToday: false);

    if (updatedTask != null) {
      await _scheduleTargetAlarm(updatedTask, now);
    }
  }

  Future<void> completeCurrentTask() async {
    final task = state.currentTask;
    if (task == null) {
      return;
    }

    await _alarm.cancel();
    _sessionId = null;
    await _repository.completeTask(taskId: task.id, completedAt: clock.now());

    await _loadNextTask();
  }

  Future<void> exitFocus() async {
    await pauseSession(reason: EndReason.exited);
    await _alarm.cancel();
    _stopTicker();
    state = state.copyWith(clearCurrentTask: true, isPaused: true, clearSessionStartedAt: true, sessionBaseMs: 0, now: clock.now(), shouldShowFinishedForToday: false);
  }

  /// Sessions that were left running, e.g. because the app was killed while focusing.
  Future<List<FocusSession>> loadRecoverableSessions() => _sessions.unfinishedSessions();

  Future<void> recoverSessions({required SessionRecovery recovery, required List<FocusSession> sessions}) async {
    final now = clock.now();
    for (final session in sessions) {
      switch (recovery) {
        case SessionRecovery.untilLastActivity:
          await _sessions.end(session.id, session.lastActivityAt, EndReason.recovered);
        case SessionRecovery.untilNow:
          await _sessions.end(session.id, now, EndReason.recovered);
        case SessionRecovery.discard:
          await _sessions.end(session.id, now, EndReason.discarded);
      }
    }
  }

  Future<void> toggleTodoCompletion(int todoId) async {
    final task = state.currentTask;
    if (task == null) return;

    final todo = task.todos.where((todo) => todo.id == todoId).firstOrNull;
    if (todo == null) return;

    final isCompleted = !todo.isCompleted;
    state = state.copyWith(
      currentTask: task.copyWith(todos: [for (final candidate in task.todos) candidate.id == todoId ? candidate.copyWith(isCompleted: isCompleted) : candidate]),
    );

    await _repository.setTodoCompletion(todoId: todoId, isCompleted: isCompleted);
  }

  Future<void> dismissAlarm() async {
    await _alarm.cancel();
    state = state.copyWith(shouldShowAlarm: false);
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = clock.now();
    final task = state.currentTask;
    final remaining = task == null ? null : _remainingUntilTarget(task, now);
    final reachedTarget = remaining != null && remaining <= Duration.zero && !state.hasAlarmPlayedForCurrentTask;

    if (task != null && !state.isPaused && (_lastHeartbeat == null || now.difference(_lastHeartbeat!) >= heartbeatInterval)) {
      _lastHeartbeat = now;
      final sessionId = _sessionId;
      if (sessionId != null) unawaited(_sessions.heartbeat(sessionId, now));
    }

    // The alarm itself is rung by [TargetAlarm]; here we only show the in-app dialog.
    state = state.copyWith(now: now, shouldShowAlarm: reachedTarget || state.shouldShowAlarm, hasAlarmPlayedForCurrentTask: reachedTarget || state.hasAlarmPlayedForCurrentTask);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _lastHeartbeat = null;
  }

  void clearFinishedForToday() {
    state = state.copyWith(shouldShowFinishedForToday: false);
  }
}
