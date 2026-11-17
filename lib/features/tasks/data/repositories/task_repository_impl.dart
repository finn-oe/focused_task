import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart';
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
  Future<void> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate, TaskPriority? priority}) {
    return _database.updateTaskDetails(
      taskId: taskId,
      title: title,
      description: description,
      targetDurationMinutes: targetDurationMinutes,
      assignedDate: assignedDate,
      priority: priority?.value,
    );
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
    final range = DateRange(start, end);
    final tasks = await _database.getTasksInRange(start: range.start, end: range.end);
    final sessions = await _database.getSessionsOverlapping(range.start, range.end.nextDay);
    return TaskStats.from(
      tasks: tasks.map(_taskOnlyToEntity),
      focusByTask: focusTimeByTask(sessions.map(FocusSessionRepositoryImpl.toEntity), range),
      daysInRange: range.start.calendarDaysUntil(range.end) + 1,
    );
  }

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) {
    return _database.completeTask(taskId: taskId, completedAt: completedAt);
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
      latestStart: data.openSession?.startedAt,
      targetDurationMinutes: task.targetDurationMinutes,
      lastSeenAt: data.openSession?.lastSeenAt,
      todos: data.todos.map((todo) => TaskTodoEntity(id: todo.id, title: todo.title, isCompleted: todo.isCompleted, sortOrder: todo.sortOrder)).toList(growable: false),
    );
  }

  TaskEntity _taskOnlyToEntity(Task task) {
    return _toEntity(TaskWithTodos(task, []));
  }
}
