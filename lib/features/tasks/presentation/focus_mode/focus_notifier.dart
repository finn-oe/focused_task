import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/services/target_alarm.dart';
import 'package:focused_task/core/utils/date_utils.dart';
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

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  FocusModeNotifier(this._repository, this._alarm) : super(FocusModeState.initial());

  final ITaskRepository _repository;
  final TargetAlarm _alarm;
  Timer? _ticker;
  DateTime? _lastHeartbeat;

  /// How often a running session records that it is still alive.
  static const heartbeatInterval = Duration(seconds: 30);

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
    await _alarm.schedule(taskTitle: task.title, at: now.add(remaining));
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

    var current = task;
    if (!task.isRunning) {
      await _repository.startTaskSession(taskId: task.id, startedAt: clock.now());
      current = (await _repository.getTaskById(task.id)) ?? task;
    }

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

  Future<void> pauseSession() async {
    final task = state.currentTask;
    if (task == null || state.isPaused) {
      return;
    }

    await _alarm.cancel();

    final now = clock.now();
    await _repository.pauseTaskSession(taskId: task.id, pausedAt: now);

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
    await _repository.startTaskSession(taskId: task.id, startedAt: now);
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
    await _repository.completeTask(taskId: task.id, completedAt: clock.now());

    await _loadNextTask();
  }

  Future<void> exitFocus() async {
    await pauseSession();
    await _alarm.cancel();
    _stopTicker();
    state = state.copyWith(clearCurrentTask: true, isPaused: true, clearSessionStartedAt: true, sessionBaseMs: 0, now: clock.now(), shouldShowFinishedForToday: false);
  }

  Future<void> recoverSessions({required SessionRecovery recovery, required List<TaskEntity> sessions}) async {
    final now = clock.now();
    for (final session in sessions) {
      switch (recovery) {
        case SessionRecovery.untilLastActivity:
          await _repository.pauseTaskSession(taskId: session.id, pausedAt: session.lastActivityAt ?? now);
        case SessionRecovery.untilNow:
          await _repository.pauseTaskSession(taskId: session.id, pausedAt: now);
        case SessionRecovery.discard:
          await _repository.discardUnfinishedSession(taskId: session.id);
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
      unawaited(_repository.recordHeartbeat(taskId: task.id, at: now));
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

  void disposeNotifier() {
    _stopTicker();
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
