import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/tasks/domain/entities/day_summary.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

/// Tasks and day summaries of the days the calendar shows.
class CalendarState {
  const CalendarState({this.tasksByDay = const {}, this.summaries = const {}, this.isLoading = true, this.error});

  /// Tasks per day (local midnight keys), in their plan order. Days without tasks are missing.
  final Map<DateTime, List<TaskEntity>> tasksByDay;

  /// Summaries per day; days without tasks or focus time are missing.
  final Map<DateTime, DaySummary> summaries;
  final bool isLoading;
  final String? error;

  List<TaskEntity> tasksOn(DateTime day) => tasksByDay[day.dateOnly] ?? const [];

  DaySummary summaryOf(DateTime day) => summaries[day.dateOnly] ?? DaySummary.empty;

  /// Longest focus time of a single day, to scale the focus bars.
  Duration get maxFocusTime => summaries.values.fold(Duration.zero, (max, summary) => summary.focusTime > max ? summary.focusTime : max);

  CalendarState copyWith({Map<DateTime, List<TaskEntity>>? tasksByDay, Map<DateTime, DaySummary>? summaries, bool? isLoading, String? error, bool clearError = false}) {
    return CalendarState(
      tasksByDay: tasksByDay ?? this.tasksByDay,
      summaries: summaries ?? this.summaries,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Keeps the calendar of one [DateRange] up to date: reloads whenever tasks or focus sessions in it change.
class CalendarNotifier extends Notifier<CalendarState> {
  CalendarNotifier(this.range);

  /// The days shown.
  final DateRange range;

  late ITaskRepository _repository;
  int _generation = 0;

  @override
  CalendarState build() {
    _repository = ref.watch(taskRepositoryProvider);
    final sessions = ref.watch(focusSessionRepositoryProvider);

    final subscriptions = [
      _repository.watchTasksInRange(range).listen(_onTasks, onError: _onError),
      // Focus time of a day changes when a session in it starts, beats or ends.
      sessions.watchInRange(range.start, range.end.nextDay).listen((_) => _reloadSummaries(), onError: _onError),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
    return const CalendarState();
  }

  void _onTasks(List<TaskEntity> tasks) {
    final byDay = <DateTime, List<TaskEntity>>{};
    for (final task in tasks) {
      byDay.putIfAbsent(task.assignedDate.dateOnly, () => []).add(task);
    }
    state = state.copyWith(tasksByDay: byDay);
    _reloadSummaries();
  }

  void _onError(Object error) {
    state = state.copyWith(isLoading: false, error: error.toString());
  }

  Future<void> _reloadSummaries() async {
    final generation = ++_generation;
    try {
      final summaries = await _repository.getDaySummaries(range);
      // A newer reload has started meanwhile; its result wins.
      if (generation != _generation || !ref.mounted) return;
      state = state.copyWith(summaries: summaries, isLoading: false, clearError: true);
    } catch (error) {
      if (generation == _generation && ref.mounted) _onError(error);
    }
  }

  /// Moves [task] to the end of [day]'s tasks. Moving it onto its own day does nothing.
  Future<void> moveTask(TaskEntity task, DateTime day) async {
    final target = day.dateOnly;
    if (task.assignedDate.isSameDate(target)) return;

    final existing = (await _repository.getTasksForDay(target)).where((candidate) => candidate.id != task.id);
    final sortOrder = FractionalIndexer.between(existing.lastOrNull?.sortOrder, null);
    final moved = task.copyWith(assignedDate: target, sortOrder: sortOrder);

    // Optimistic update, so the task doesn't jump back until the database reports the change.
    if (ref.mounted) {
      final byDay = {
        for (final entry in state.tasksByDay.entries)
          entry.key: [
            for (final candidate in entry.value)
              if (candidate.id != task.id) candidate,
          ],
      };
      if (!target.isBefore(range.start) && !target.isAfter(range.end)) byDay[target] = [...?byDay[target], moved];
      state = state.copyWith(tasksByDay: byDay);
    }

    await _repository.updateTaskDetails(
      taskId: task.id,
      title: task.title,
      description: task.description,
      targetDurationMinutes: task.targetDurationMinutes,
      assignedDate: target,
      priority: task.priority,
      categoryId: task.categoryId,
    );
    await _repository.updateTaskOrder(taskId: task.id, sortOrder: sortOrder);
  }
}
