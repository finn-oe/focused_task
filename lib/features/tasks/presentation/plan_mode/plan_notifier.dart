import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';

import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/categories/domain/i_category_repository.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/core/utils/date_utils.dart';

/// How the plan shows the day: the ordered list, or the board grouped by category (#2).
enum PlanView { list, board }

class PlanModeState {
  const PlanModeState({required this.selectedDay, required this.tasks, required this.isLoading, this.error, this.view = PlanView.list, this.categoryFilter});

  factory PlanModeState.initial({PlanView view = PlanView.list}) {
    return PlanModeState(selectedDay: clock.now().dateOnly, tasks: const [], isLoading: true, view: view);
  }

  final DateTime selectedDay;
  final List<TaskEntity> tasks;
  final bool isLoading;
  final String? error;
  final PlanView view;

  /// The list shows only the tasks of this category; `null` = all tasks.
  final int? categoryFilter;

  /// The day's tasks grouped for the board, in plan order within a group: one group per active category (also empty
  /// ones, so tasks can be dropped there), archived categories that still have tasks here, and "no category" last.
  List<BoardGroup> boardGroups(List<TaskCategory> categories) {
    final known = {for (final category in categories) category.id: category};
    final byCategory = <int?, List<TaskEntity>>{};
    for (final task in tasks) {
      final key = known.containsKey(task.categoryId) ? task.categoryId : null;
      byCategory.putIfAbsent(key, () => []).add(task);
    }
    return [
      for (final category in categories)
        if (!category.archived || byCategory.containsKey(category.id)) BoardGroup(category, byCategory[category.id] ?? const []),
      BoardGroup(null, byCategory[null] ?? const []),
    ];
  }

  /// Tasks the list shows: all of the day, or those of [categoryFilter].
  List<TaskEntity> get visibleTasks => categoryFilter == null ? tasks : tasks.where((task) => task.categoryId == categoryFilter).toList(growable: false);

  PlanModeState copyWith({
    DateTime? selectedDay,
    List<TaskEntity>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
    PlanView? view,
    int? categoryFilter,
    bool clearCategoryFilter = false,
  }) {
    return PlanModeState(
      selectedDay: selectedDay ?? this.selectedDay,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      view: view ?? this.view,
      categoryFilter: clearCategoryFilter ? null : categoryFilter ?? this.categoryFilter,
    );
  }
}

/// Tasks of one [category] (`null` = no category) on the board.
class BoardGroup {
  const BoardGroup(this.category, this.tasks);

  final TaskCategory? category;
  final List<TaskEntity> tasks;

  int get openCount => tasks.where((task) => !task.isCompleted).length;

  int get completedCount => tasks.length - openCount;

  int get totalCount => tasks.length;

  /// Share of completed tasks (0–1); `null` for an empty group.
  double? get completionRate => tasks.isEmpty ? null : completedCount / tasks.length;

  /// Time tracked on the group's tasks at [now], a running session included – the same sum as the list's day total.
  Duration trackedAt(DateTime now) => tasks.fold(Duration.zero, (sum, task) => sum + task.elapsedAt(now));
}

/// What "Start focus" in the plan should do for the shown day.
sealed class FocusStart {
  const FocusStart();
}

/// Start right away on [day].
class FocusStartNow extends FocusStart {
  const FocusStartNow(this.day);
  final DateTime day;
}

/// [day] is in the future: ask before working ahead.
class FocusStartAhead extends FocusStart {
  const FocusStartAhead(this.day);
  final DateTime day;
}

/// [day] is in the past (or it's yesterday, when today has nothing open) and has [openTasks]: offer to move them to
/// today and focus on them.
class FocusStartMoveToToday extends FocusStart {
  const FocusStartMoveToToday(this.day, this.openTasks, {required this.fromYesterday});
  final DateTime day;
  final int openTasks;

  /// Offered because today has nothing open (rather than because a past day is shown).
  final bool fromYesterday;
}

/// Tasks that were moved to [to], as they were before (day and position), so the move can be undone.
class TaskMove {
  const TaskMove(this.to, this.previous);

  final DateTime to;
  final List<TaskEntity> previous;

  int get count => previous.length;
  bool get isEmpty => previous.isEmpty;
}

class PlanModeNotifier extends Notifier<PlanModeState> {
  /// Day (`YYYY-MM-DD`) on which the rollover prompt was last offered.
  static const String rolloverPromptedKey = 'plan.rollover_prompted_on';

  /// How many past days the rollover prompt looks at.
  static const int rolloverDays = 7;

  /// The chosen [PlanView] (by name).
  static const String viewKey = 'plan.view';

  late ITaskRepository _repository;
  late ICategoryRepository _categories;
  late IFocusSessionRepository _sessions;
  late SharedPreferences _prefs;
  StreamSubscription<List<TaskEntity>>? _subscription;

  @override
  PlanModeState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _sessions = ref.watch(focusSessionRepositoryProvider);
    _prefs = ref.watch(sharedPreferencesProvider);
    _categories = ref.watch(categoryRepositoryProvider);
    ref.onDispose(() => _subscription?.cancel());
    // A filter by a category that was archived or deleted would hide tasks for no visible reason.
    ref.listen(categoriesNotifierProvider, (_, categories) {
      final filter = state.categoryFilter;
      if (filter != null && !categories.isLoading && !categories.active.any((category) => category.id == filter)) {
        state = state.copyWith(clearCategoryFilter: true);
      }
    });

    final view = PlanView.values.asNameMap()[_prefs.getString(viewKey)] ?? PlanView.list;
    final initial = PlanModeState.initial(view: view);
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

  /// Switches between list and board; remembered across restarts.
  Future<void> setView(PlanView view) async {
    state = state.copyWith(view: view);
    await _prefs.setString(viewKey, view.name);
  }

  /// Shows only the tasks of [categoryId] in the list; `null` shows all.
  void setCategoryFilter(int? categoryId) {
    state = categoryId == null ? state.copyWith(clearCategoryFilter: true) : state.copyWith(categoryFilter: categoryId);
  }

  /// Puts [task] into [categoryId] (`null` = no category), e.g. by dragging it to another board group.
  Future<void> setTaskCategory(TaskEntity task, int? categoryId) async {
    if (task.categoryId == categoryId) return;
    state = state.copyWith(
      tasks: [for (final candidate in state.tasks) candidate.id == task.id ? candidate.copyWith(categoryId: categoryId, clearCategory: categoryId == null) : candidate],
    );
    await _categories.setTaskCategory(taskId: task.id, categoryId: categoryId);
  }

  Future<void> addTask({
    required String title,
    String? description,
    int? targetDurationMinutes,
    TaskPriority priority = TaskPriority.low,
    required List<TaskTodoEntity> todos,
    required DateTime assignedDate,
    int? categoryId,
  }) async {
    final lastSort = state.tasks.isEmpty ? null : state.tasks.last.sortOrder;
    final nextSort = FractionalIndexer.between(lastSort, null);

    final taskId = await _repository.createTask(
      title: title,
      description: description,
      assignedDate: assignedDate,
      sortOrder: nextSort,
      priority: priority,
      targetDurationMinutes: targetDurationMinutes,
      categoryId: categoryId,
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

    await addTask(
      title: task.title,
      description: task.description,
      targetDurationMinutes: newTargetDuration,
      priority: task.priority,
      todos: newTodos,
      assignedDate: date,
      categoryId: task.categoryId,
    );
  }

  /// Saves the form: updates the task with [id], or creates a new one when [id] is `null`.
  Future<void> saveDraft(TaskDraft draft, {int? id}) async {
    final title = draft.title.trim();
    final description = draft.description.trim().isEmpty ? null : draft.description.trim();
    final todos = [
      for (final (index, todo) in draft.todos.indexed)
        if (todo.title.trim().isNotEmpty) todo.copyWith(title: todo.title.trim(), sortOrder: index.toString().padLeft(5, '0')),
    ];

    if (id == null) {
      await addTask(
        title: title,
        description: description,
        targetDurationMinutes: draft.targetMinutes,
        priority: draft.priority,
        todos: todos,
        assignedDate: draft.date,
        categoryId: draft.categoryId,
      );
      return;
    }
    await _repository.updateTaskDetails(
      taskId: id,
      title: title,
      description: description,
      targetDurationMinutes: draft.targetMinutes,
      assignedDate: draft.date,
      priority: draft.priority,
      categoryId: draft.categoryId,
    );
    await _repository.replaceTaskTodos(id, todos);
  }

  /// Creates a copy of [draft] with all sub-tasks unchecked.
  Future<void> duplicateDraft(TaskDraft draft) {
    return saveDraft(
      draft.copyWith(
        todos: [for (final todo in draft.todos) TaskTodoEntity(title: todo.title, isCompleted: false, sortOrder: todo.sortOrder)],
      ),
    );
  }

  /// Decides what "Start focus" does for [day] (see [FocusStart]).
  Future<FocusStart> focusStartFor(DateTime day) async {
    final today = clock.now().dateOnly;
    final shown = day.dateOnly;
    Future<int> openOn(DateTime date) async => (await _repository.getTasksForDay(date)).where((task) => !task.isCompleted).length;

    if (shown.isAfter(today)) return FocusStartAhead(shown);
    if (shown.isBefore(today)) {
      final open = await openOn(shown);
      return open > 0 ? FocusStartMoveToToday(shown, open, fromYesterday: false) : FocusStartNow(today);
    }
    if (await openOn(today) == 0) {
      final yesterday = today.addDays(-1);
      final open = await openOn(yesterday);
      if (open > 0) return FocusStartMoveToToday(yesterday, open, fromYesterday: true);
    }
    return FocusStartNow(today);
  }

  /// Moves the open tasks among [ids] to the day [to] (after the tasks already there, in the given order). Completed
  /// tasks can't be moved, only copied. Keeps sub-tasks, tracked time and focus sessions.
  Future<TaskMove> moveTasks(List<int> ids, DateTime to) async {
    final before = <int, TaskEntity>{};
    for (final id in ids) {
      final task = await _repository.getTaskById(id);
      if (task != null) before[id] = task;
    }
    final moved = await _repository.moveTasks(taskIds: ids, to: to.dateOnly);
    return TaskMove(to.dateOnly, [for (final id in moved) before[id]!]);
  }

  /// Moves the open tasks of [from] to [to] (after the tasks already there, in their order).
  Future<TaskMove> moveOpenTasks({required DateTime from, required DateTime to}) async {
    final open = (await _repository.getTasksForDay(from)).where((task) => !task.isCompleted);
    return moveTasks([for (final task in open) task.id], to);
  }

  /// Puts the tasks of [move] back on their old day and position (unless they were completed in the meantime).
  Future<void> undoMove(TaskMove move) async {
    for (final task in move.previous) {
      final moved = await _repository.moveTasks(taskIds: [task.id], to: task.assignedDate);
      if (moved.isNotEmpty) await _repository.updateTaskOrder(taskId: task.id, sortOrder: task.sortOrder);
    }
  }

  /// Open tasks of the last [rolloverDays] days to offer on the first call of a day, or nothing when the prompt was
  /// already offered today or is turned off in the settings. Calling it counts as offering the prompt.
  Future<List<TaskEntity>> takeRolloverCandidates() async {
    if (!ref.read(settingsNotifierProvider).askToMoveUnfinished) return const [];
    final today = clock.now().dateOnly;
    if (_prefs.getString(rolloverPromptedKey) == today.isoDate) return const [];
    await _prefs.setString(rolloverPromptedKey, today.isoDate);
    return _repository.getOpenTasksBetween(start: today.addDays(-rolloverDays), end: today.addDays(-1));
  }

  /// Adds manually tracked time to [task]: on its day if that is in the past, otherwise today (never in the future).
  Future<void> addManualTime({required TaskEntity task, required Duration duration}) {
    final today = clock.now().dateOnly;
    final day = task.assignedDate.isBefore(today) ? task.assignedDate : today;
    return _sessions.addManualTime(taskId: task.id, day: day, duration: duration);
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
  }

  /// Moves the task at [oldIndex] of the shown list ([PlanModeState.visibleTasks]) to [newIndex]. With a category
  /// filter, the task lands between its visible neighbours; the hidden tasks keep their places.
  Future<void> reorderTask(int oldIndex, int newIndex) async {
    final visible = [...state.visibleTasks];
    if (visible.isEmpty) {
      return;
    }
    final movedTask = visible.removeAt(oldIndex);
    visible.insert(newIndex, movedTask);

    final before = newIndex > 0 ? visible[newIndex - 1] : null;
    final after = newIndex < visible.length - 1 ? visible[newIndex + 1] : null;

    final nextSort = FractionalIndexer.between(before?.sortOrder, after?.sortOrder);

    // Optimistic UI update so it doesn't snap back
    final tasks = [...state.tasks.where((task) => task.id != movedTask.id)];
    final anchor = before != null
        ? tasks.indexWhere((task) => task.id == before.id) + 1
        : after != null
        ? tasks.indexWhere((task) => task.id == after.id)
        : tasks.length;
    tasks.insert(anchor, movedTask.copyWith(sortOrder: nextSort));
    state = state.copyWith(tasks: tasks);

    await _repository.updateTaskOrder(taskId: movedTask.id, sortOrder: nextSort);
  }

  Future<void> toggleTaskCompletion(TaskEntity task) async {
    final updatedTasks = state.tasks.map((candidate) => candidate.id == task.id ? candidate.copyWith(isCompleted: !task.isCompleted) : candidate).toList(growable: false);
    state = state.copyWith(tasks: updatedTasks);

    await _repository.setTaskCompletion(taskId: task.id, isCompleted: !task.isCompleted);
  }
}
