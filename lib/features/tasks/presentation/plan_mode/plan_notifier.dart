import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class PlanModeState {
  const PlanModeState({required this.selectedDay, required this.tasks, required this.isLoading, this.error});

  factory PlanModeState.initial() {
    return PlanModeState(selectedDay: _dateOnly(DateTime.now()), tasks: const [], isLoading: true);
  }

  final DateTime selectedDay;
  final List<TaskEntity> tasks;
  final bool isLoading;
  final String? error;

  PlanModeState copyWith({DateTime? selectedDay, List<TaskEntity>? tasks, bool? isLoading, String? error, bool clearError = false}) {
    return PlanModeState(
      selectedDay: selectedDay ?? this.selectedDay,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class PlanModeNotifier extends StateNotifier<PlanModeState> {
  PlanModeNotifier(this._repository) : super(PlanModeState.initial()) {
    _bind(state.selectedDay);
  }

  final ITaskRepository _repository;
  StreamSubscription<List<TaskEntity>>? _subscription;

  void _bind(DateTime day) {
    _subscription?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    _subscription = _repository
        .watchTasksForDay(day)
        .listen(
          (tasks) {
            state = state.copyWith(tasks: tasks, isLoading: false, clearError: true);
          },
          onError: (Object error) {
            state = state.copyWith(isLoading: false, error: error.toString());
          },
        );
  }

  Future<void> setSelectedDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized == state.selectedDay) {
      return;
    }

    state = state.copyWith(selectedDay: normalized);
    _bind(normalized);
  }

  Future<void> addTask({required String title, String? description, int? targetDurationMinutes}) async {
    final lastSort = state.tasks.isEmpty ? null : state.tasks.last.sortOrder;
    final nextSort = FractionalIndexer.between(lastSort, null);

    await _repository.createTask(title: title, description: description, assignedDate: state.selectedDay, sortOrder: nextSort, targetDurationMinutes: targetDurationMinutes);
  }

  Future<void> updateTask({required int id, required String title, String? description, int? targetDurationMinutes}) async {
    await _repository.updateTaskDetails(taskId: id, title: title, description: description, targetDurationMinutes: targetDurationMinutes);
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
  }

  Future<void> reorderTask(int oldIndex, int newIndex) async {
    if (state.tasks.isEmpty) {
      return;
    }

    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final tasks = [...state.tasks];
    final movedTask = tasks.removeAt(oldIndex);
    tasks.insert(adjustedNewIndex, movedTask);

    final before = adjustedNewIndex > 0 ? tasks[adjustedNewIndex - 1] : null;
    final after = adjustedNewIndex < tasks.length - 1 ? tasks[adjustedNewIndex + 1] : null;

    final nextSort = FractionalIndexer.between(before?.sortOrder, after?.sortOrder);

    await _repository.updateTaskOrder(taskId: movedTask.id, sortOrder: nextSort);
  }

  Future<void> toggleTaskCompletion(TaskEntity task) async {
    final updatedTasks = state.tasks.map((candidate) => candidate.id == task.id ? candidate.copyWith(isCompleted: !task.isCompleted) : candidate).toList(growable: false);
    state = state.copyWith(tasks: updatedTasks);

    await _repository.setTaskCompletion(taskId: task.id, isCompleted: !task.isCompleted);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
