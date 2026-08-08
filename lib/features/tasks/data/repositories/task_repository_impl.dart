import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class TaskRepositoryImpl implements ITaskRepository {
  TaskRepositoryImpl(this._database);

  final AppDatabase _database;

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  @override
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day) {
    return _database.watchTasksForDay(day).map((tasks) => tasks.map(_toEntity).toList(growable: false));
  }

  @override
  Future<List<TaskEntity>> getTasksForDay(DateTime day) async {
    final tasks = await _database.getTasksForDay(day);
    return tasks.map(_toEntity).toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(int id) async {
    final task = await _database.getTaskById(id);
    return task == null ? null : _toEntity(task);
  }

  @override
  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day) async {
    final task = await _database.getNextIncompleteTaskForDay(day);
    return task == null ? null : _toEntity(task);
  }

  @override
  Future<void> createTask({required String title, String? description, required DateTime assignedDate, required String sortOrder, TaskPriority priority = TaskPriority.low}) {
    return _database.createTask(
      TasksCompanion.insert(title: title, description: Value(description), assignedDate: _dateOnly(assignedDate), sortOrder: sortOrder, priority: Value(priority.value)),
    );
  }

  @override
  Future<void> updateTaskDetails({required int taskId, required String title, String? description}) {
    return _database.updateTaskDetails(taskId: taskId, title: title, description: description);
  }

  @override
  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) {
    return _database.updateTaskOrder(taskId: taskId, sortOrder: sortOrder);
  }

  @override
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted}) {
    return _database.setTaskCompletion(taskId: taskId, isCompleted: isCompleted);
  }

  @override
  Future<TaskStats> getTaskStats({required DateTime start, required DateTime end}) async {
    final tasks = await _database.getTasksInRange(start: start, end: end);
    return TaskStats.fromTasks(tasks.map(_toEntity), daysInRange: start.difference(end).abs().inDays == 0 ? 1 : start.difference(end).abs().inDays + 1);
  }

  @override
  Future<void> startTaskSession({required int taskId, required DateTime startedAt}) {
    return _database.startTaskSession(taskId: taskId, startedAt: startedAt);
  }

  @override
  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt}) {
    return _database.pauseTaskSession(taskId: taskId, pausedAt: pausedAt);
  }

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) {
    return _database.completeTask(taskId: taskId, completedAt: completedAt);
  }

  @override
  Future<void> discardUnfinishedSession({required int taskId}) {
    return _database.discardUnfinishedSession(taskId);
  }

  @override
  Future<List<TaskEntity>> getRecoverableSessions() async {
    final tasks = await _database.getRecoverableSessions();
    return tasks.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> deleteTask(int taskId) {
    return _database.deleteTask(taskId);
  }

  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) {
    final safeDays = days < 1 ? 1 : days;
    final cutoff = _dateOnly(DateTime.now()).subtract(Duration(days: safeDays));
    return _database.deleteCompletedTasksBefore(cutoff);
  }

  TaskEntity _toEntity(Task task) {
    return TaskEntity(
      id: task.id,
      title: task.title,
      description: task.description,
      assignedDate: task.assignedDate,
      sortOrder: task.sortOrder,
      isCompleted: task.isCompleted,
      priority: TaskPriority.fromValue(task.priority),
      timeSpent: task.timeSpent,
      latestStart: task.latestStart,
    );
  }
}
