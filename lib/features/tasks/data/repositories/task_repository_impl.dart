import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/core/utils/date_utils.dart';

class TaskRepositoryImpl implements ITaskRepository {
  TaskRepositoryImpl(this._database);

  final AppDatabase _database;

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
    final data = await _database.getTaskById(id);
    return data == null ? null : _toEntity(data);
  }

  @override
  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day) async {
    final task = await _database.getNextIncompleteTaskForDay(day);
    return task == null ? null : _taskOnlyToEntity(task);
  }

  @override
  Future<int> createTask({
    required String title,
    String? description,
    required DateTime assignedDate,
    required String sortOrder,
    TaskPriority priority = TaskPriority.low,
    int? targetDurationMinutes,
  }) {
    return _database.createTask(
      TasksCompanion.insert(
        title: title,
        description: Value(description),
        assignedDate: assignedDate.dateOnly,
        sortOrder: sortOrder,
        priority: Value(priority.value),
        targetDurationMinutes: Value(targetDurationMinutes),
      ),
    );
  }

  @override
  Future<void> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate}) {
    return _database.updateTaskDetails(taskId: taskId, title: title, description: description, targetDurationMinutes: targetDurationMinutes, assignedDate: assignedDate);
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
    return TaskStats.fromTasks(tasks.map(_taskOnlyToEntity), daysInRange: start.calendarDaysUntil(end).abs() + 1);
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
  Future<void> recordHeartbeat({required int taskId, required DateTime at}) {
    return _database.recordHeartbeat(taskId: taskId, at: at);
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
    return tasks.map(_taskOnlyToEntity).toList(growable: false);
  }

  @override
  Future<void> deleteTask(int taskId) {
    return _database.deleteTask(taskId);
  }

  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) => _database.deleteCompletedTasksBefore(_retentionCutoff(days));

  @override
  Future<int> countCompletedTasksOlderThanDays(int days) => _database.countCompletedTasksBefore(_retentionCutoff(days));

  DateTime _retentionCutoff(int days) => DateTime.now().addDays(-(days < 1 ? 1 : days));

  @override
  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos) async {
    final driftTodos = newTodos.map((t) => TaskTodo(id: t.id ?? 0, taskId: taskId, title: t.title, isCompleted: t.isCompleted, sortOrder: t.sortOrder)).toList();

    await _database.replaceTaskTodos(taskId, driftTodos);
  }

  @override
  Future<void> setTodoCompletion({required int todoId, required bool isCompleted}) {
    return _database.setTodoCompletion(todoId: todoId, isCompleted: isCompleted);
  }

  // Maps a joined Task + Todos object
  TaskEntity _toEntity(TaskWithTodos data) {
    final task = data.task;
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
      targetDurationMinutes: task.targetDurationMinutes,
      lastSeenAt: task.lastSeenAt,
      todos: data.todos.map((todo) => TaskTodoEntity(id: todo.id, title: todo.title, isCompleted: todo.isCompleted, sortOrder: todo.sortOrder)).toList(growable: false),
    );
  }

  TaskEntity _taskOnlyToEntity(Task task) {
    return _toEntity(TaskWithTodos(task, []));
  }
}
