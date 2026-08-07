import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

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
  });

  factory FocusModeState.initial() {
    final now = DateTime.now();
    return FocusModeState(
      selectedDay: DateTime(now.year, now.month, now.day),
      now: now,
      sessionBaseMs: 0,
      isLoading: false,
      isPaused: true,
    );
  }

  final DateTime selectedDay;
  final DateTime now;
  final int sessionBaseMs;
  final DateTime? sessionStartedAt;
  final bool isLoading;
  final bool isPaused;
  final TaskEntity? currentTask;
  final String? error;

  Duration get totalSessionDuration {
    final runningMs = isPaused || sessionStartedAt == null
        ? 0
        : now.difference(sessionStartedAt!).inMilliseconds;
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
    bool clearCurrentTask = false,
    bool clearSessionStartedAt = false,
    bool clearError = false,
  }) {
    return FocusModeState(
      selectedDay: selectedDay ?? this.selectedDay,
      now: now ?? this.now,
      sessionBaseMs: sessionBaseMs ?? this.sessionBaseMs,
      sessionStartedAt: clearSessionStartedAt
          ? null
          : sessionStartedAt ?? this.sessionStartedAt,
      isLoading: isLoading ?? this.isLoading,
      isPaused: isPaused ?? this.isPaused,
      currentTask: clearCurrentTask ? null : currentTask ?? this.currentTask,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class FocusModeNotifier extends StateNotifier<FocusModeState> {
  FocusModeNotifier(this._repository) : super(FocusModeState.initial());

  final ITaskRepository _repository;
  Timer? _ticker;

  Future<void> initializeForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    state = state.copyWith(
      selectedDay: normalized,
      isLoading: true,
      clearError: true,
    );

    await _loadNextTask();
  }

  Future<void> _loadNextTask() async {
    final task = await _repository.getNextIncompleteTaskForDay(state.selectedDay);
    if (task == null) {
      _stopTicker();
      state = state.copyWith(
        currentTask: null,
        isLoading: false,
        isPaused: true,
        clearSessionStartedAt: true,
      );
      return;
    }

    TaskEntity current = task;
    if (task.latestStart == null) {
      final now = DateTime.now();
      await _repository.startTaskSession(taskId: task.id, startedAt: now);
      current = (await _repository.getTaskById(task.id)) ?? task;
    }

    _startTicker();
    state = state.copyWith(
      currentTask: current,
      isPaused: false,
      sessionStartedAt: state.sessionStartedAt ?? DateTime.now(),
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> pauseSession() async {
    final task = state.currentTask;
    if (task == null || state.isPaused) {
      return;
    }

    final now = DateTime.now();
    await _repository.pauseTaskSession(taskId: task.id, pausedAt: now);

    final updatedTask = await _repository.getTaskById(task.id);
    final runningMs = state.sessionStartedAt == null
        ? 0
        : now.difference(state.sessionStartedAt!).inMilliseconds;

    state = state.copyWith(
      currentTask: updatedTask,
      sessionBaseMs: state.sessionBaseMs + runningMs,
      isPaused: true,
      clearSessionStartedAt: true,
      now: now,
    );
  }

  Future<void> resumeSession() async {
    final task = state.currentTask;
    if (task == null || !state.isPaused) {
      return;
    }

    final now = DateTime.now();
    await _repository.startTaskSession(taskId: task.id, startedAt: now);
    final updatedTask = await _repository.getTaskById(task.id);

    _startTicker();
    state = state.copyWith(
      currentTask: updatedTask,
      isPaused: false,
      sessionStartedAt: now,
      now: now,
    );
  }

  Future<void> completeCurrentTask() async {
    final task = state.currentTask;
    if (task == null) {
      return;
    }

    await _repository.completeTask(
      taskId: task.id,
      completedAt: DateTime.now(),
    );

    await _loadNextTask();
  }

  Future<void> exitFocus() async {
    await pauseSession();
    _stopTicker();
    state = state.copyWith(
      clearCurrentTask: true,
      isPaused: true,
      clearSessionStartedAt: true,
      sessionBaseMs: 0,
      now: DateTime.now(),
    );
  }

  Future<void> recoverOrDiscardSessions({
    required bool recover,
    required List<TaskEntity> sessions,
  }) async {
    final now = DateTime.now();
    for (final session in sessions) {
      if (recover) {
        await _repository.pauseTaskSession(taskId: session.id, pausedAt: now);
      } else {
        await _repository.discardUnfinishedSession(taskId: session.id);
      }
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(now: DateTime.now());
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
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
