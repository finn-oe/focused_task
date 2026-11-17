import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';

import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/core/utils/date_utils.dart';

class PlanModeState {
  const PlanModeState({required this.selectedDay, required this.tasks, required this.isLoading, this.error});

  factory PlanModeState.initial() {
    return PlanModeState(selectedDay: clock.now().dateOnly, tasks: const [], isLoading: true);
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
}

class PlanModeNotifier extends Notifier<PlanModeState> {
  late ITaskRepository _repository;
  StreamSubscription<List<TaskEntity>>? _subscription;

  @override
  PlanModeState build() {
    _repository = ref.watch(taskRepositoryProvider);
    ref.onDispose(() => _subscription?.cancel());

    final initial = PlanModeState.initial();
    _subscribe(initial.selectedDay);
    return initial;
  }

  void _bind(DateTime day) {
    state = state.copyWith(isLoading: true, clearError: true);
    _subscribe(day);
  }

  void _subscribe(DateTime day) {
    _subscription?.cancel();

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
    final normalized = day.dateOnly;
    if (normalized == state.selectedDay) {
      return;
    }

    state = state.copyWith(selectedDay: normalized);
    _bind(normalized);
  }

  Future<void> addTask({required String title, String? description, int? targetDurationMinutes, required List<TaskTodoEntity> todos, required DateTime assignedDate}) async {
    final lastSort = state.tasks.isEmpty ? null : state.tasks.last.sortOrder;
    final nextSort = FractionalIndexer.between(lastSort, null);

    final taskId = await _repository.createTask(
      title: title,
      description: description,
      assignedDate: assignedDate,
      sortOrder: nextSort,
      targetDurationMinutes: targetDurationMinutes,
    );
    if (todos.isNotEmpty) {
      await _repository.replaceTaskTodos(taskId, todos);
    }
  }

  Future<void> duplicateTaskToDate({required TaskEntity task, required DateTime date, required bool keepTodoCompletion, required bool subtractTimeSpent}) async {
    int? newTargetDuration = task.targetDurationMinutes;
    if (subtractTimeSpent && newTargetDuration != null && task.timeSpent > 0) {
      final timeSpentMinutes = Duration(milliseconds: task.timeSpent).inMinutes;
      newTargetDuration = newTargetDuration - timeSpentMinutes;
      if (newTargetDuration < 0) {
        newTargetDuration = 0;
      }
    }
    final newTodos = task.todos.map((todo) {
      if (keepTodoCompletion) {
        return todo;
      }
      return todo.copyWith(isCompleted: false);
    }).toList();

    await addTask(title: task.title, description: task.description, targetDurationMinutes: newTargetDuration, todos: newTodos, assignedDate: date);
  }

  Future<void> updateTask({
    required int id,
    required String title,
    String? description,
    int? targetDurationMinutes,
    required List<TaskTodoEntity> todos,
    required DateTime assignedDate,
  }) async {
    await _repository.updateTaskDetails(taskId: id, title: title, description: description, targetDurationMinutes: targetDurationMinutes, assignedDate: assignedDate);
    if (todos.isNotEmpty) {
      await _repository.replaceTaskTodos(id, todos);
    } else {
      await _repository.replaceTaskTodos(id, []);
    }
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
  }

  Future<void> reorderTask(int oldIndex, int newIndex) async {
    if (state.tasks.isEmpty) {
      return;
    }
    final tasks = [...state.tasks];
    final movedTask = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, movedTask);

    // Optimistic UI update so it doesn't snap back
    state = state.copyWith(tasks: tasks);

    final before = newIndex > 0 ? tasks[newIndex - 1] : null;
    final after = newIndex < tasks.length - 1 ? tasks[newIndex + 1] : null;

    final nextSort = FractionalIndexer.between(before?.sortOrder, after?.sortOrder);

    await _repository.updateTaskOrder(taskId: movedTask.id, sortOrder: nextSort);
  }

  Future<void> toggleTaskCompletion(TaskEntity task) async {
    final updatedTasks = state.tasks.map((candidate) => candidate.id == task.id ? candidate.copyWith(isCompleted: !task.isCompleted) : candidate).toList(growable: false);
    state = state.copyWith(tasks: updatedTasks);

    await _repository.setTaskCompletion(taskId: task.id, isCompleted: !task.isCompleted);
  }
}
