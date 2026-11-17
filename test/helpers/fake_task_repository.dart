import 'dart:async';

import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

/// Simple in-memory [ITaskRepository] for widget and notifier tests.
///
/// It mirrors the behaviour of the Drift implementation closely enough for presentation-layer tests.
/// Repository behaviour itself is tested against a real in-memory database.
class FakeTaskRepository implements ITaskRepository {
  FakeTaskRepository({List<TaskEntity> tasks = const []}) {
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
    _nextId = _tasks.keys.fold(0, (max, id) => id > max ? id : max) + 1;
  }

  final Map<int, TaskEntity> _tasks = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late int _nextId;

  List<TaskEntity> get tasks => _sorted(_tasks.values);

  TaskEntity task(int id) => _tasks[id]!;

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  List<TaskEntity> _sorted(Iterable<TaskEntity> tasks) => tasks.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<TaskEntity> _forDay(DateTime day) => _sorted(_tasks.values.where((task) => _day(task.assignedDate) == _day(day)));

  void _put(TaskEntity task) {
    _tasks[task.id] = task;
    _changes.add(null);
  }

  void _update(int id, TaskEntity Function(TaskEntity task) update) {
    final task = _tasks[id];
    if (task != null) {
      _put(update(task));
    }
  }

  TaskEntity _closeSession(TaskEntity task, DateTime at) {
    if (task.latestStart == null) {
      return task;
    }
    final elapsed = at.difference(task.latestStart!).inMilliseconds;
    return task.copyWith(timeSpent: task.timeSpent + (elapsed < 0 ? 0 : elapsed), clearLatestStart: true);
  }

  @override
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day) async* {
    yield _forDay(day);
    yield* _changes.stream.map((_) => _forDay(day));
  }

  @override
  Future<List<TaskEntity>> getTasksForDay(DateTime day) async => _forDay(day);

  @override
  Future<TaskEntity?> getTaskById(int id) async => _tasks[id];

  @override
  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day) async {
    for (final task in _forDay(day)) {
      if (!task.isCompleted) {
        return task;
      }
    }
    return null;
  }

  @override
  Future<int> createTask({
    required String title,
    String? description,
    required DateTime assignedDate,
    required String sortOrder,
    TaskPriority priority = TaskPriority.low,
    int? targetDurationMinutes,
  }) async {
    final id = _nextId++;
    _put(
      TaskEntity(
        id: id,
        title: title,
        description: description,
        assignedDate: _day(assignedDate),
        sortOrder: sortOrder,
        isCompleted: false,
        priority: priority,
        timeSpent: 0,
        latestStart: null,
        targetDurationMinutes: targetDurationMinutes,
        todos: const [],
      ),
    );
    return id;
  }

  @override
  Future<void> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate}) async {
    _update(
      taskId,
      (task) => task.copyWith(
        title: title,
        description: description,
        targetDurationMinutes: targetDurationMinutes,
        clearTargetDuration: targetDurationMinutes == null,
        assignedDate: assignedDate == null ? null : _day(assignedDate),
      ),
    );
  }

  @override
  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {
    _update(taskId, (task) => task.copyWith(sortOrder: sortOrder));
  }

  @override
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted}) async {
    _update(taskId, (task) => (isCompleted ? _closeSession(task, DateTime.now()) : task).copyWith(isCompleted: isCompleted));
  }

  @override
  Future<TaskStats> getTaskStats({required DateTime start, required DateTime end}) async {
    final inRange = _tasks.values.where((task) => !_day(task.assignedDate).isBefore(_day(start)) && !_day(task.assignedDate).isAfter(_day(end)));
    return TaskStats.fromTasks(inRange, daysInRange: _day(end).difference(_day(start)).inDays + 1);
  }

  @override
  Future<void> startTaskSession({required int taskId, required DateTime startedAt}) async {
    _update(taskId, (task) => task.copyWith(latestStart: startedAt, lastSeenAt: startedAt));
  }

  @override
  Future<void> recordHeartbeat({required int taskId, required DateTime at}) async {
    _update(taskId, (task) => task.isRunning ? task.copyWith(lastSeenAt: at) : task);
  }

  @override
  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt}) async {
    _update(taskId, (task) => _closeSession(task, pausedAt));
  }

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) async {
    _update(taskId, (task) => _closeSession(task, completedAt).copyWith(isCompleted: true));
  }

  @override
  Future<void> deleteTask(int taskId) async {
    _tasks.remove(taskId);
    _changes.add(null);
  }

  @override
  Future<void> discardUnfinishedSession({required int taskId}) async {
    _update(taskId, (task) => task.copyWith(clearLatestStart: true));
  }

  @override
  Future<List<TaskEntity>> getRecoverableSessions() async => _tasks.values.where((task) => task.latestStart != null).toList();

  List<int> _cleanupCandidates(int days) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day - days);
    return _tasks.values.where((task) => task.isCompleted && task.latestStart == null && task.assignedDate.isBefore(cutoff)).map((task) => task.id).toList();
  }

  @override
  Future<int> countCompletedTasksOlderThanDays(int days) async => _cleanupCandidates(days).length;

  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) async {
    final ids = _cleanupCandidates(days);
    ids.forEach(_tasks.remove);
    _changes.add(null);
    return ids.length;
  }

  @override
  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos) async {
    var nextTodoId = 1;
    _update(taskId, (task) => task.copyWith(todos: [for (final todo in newTodos) todo.copyWith(id: todo.id ?? nextTodoId++)]));
  }
}
