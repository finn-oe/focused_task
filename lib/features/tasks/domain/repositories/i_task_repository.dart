import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';

abstract class ITaskRepository {
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day);

  Future<List<TaskEntity>> getTasksForDay(DateTime day);

  Future<TaskEntity?> getTaskById(int id);

  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day);

  Future<int> createTask({
    required String title,
    String? description,
    required DateTime assignedDate,
    required String sortOrder,
    TaskPriority priority = TaskPriority.low,
    int? targetDurationMinutes,
  });

  Future<void> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate, TaskPriority? priority});

  Future<void> updateTaskOrder({required int taskId, required String sortOrder});

  Future<void> setTaskCompletion({required int taskId, required bool isCompleted});

  /// Task counts come from the tasks assigned to `[start, end]`; focus time comes from the sessions in that range, by
  /// the time they actually happened (split at local midnight).
  Future<TaskStats> getTaskStats({required DateTime start, required DateTime end});

  /// Marks the task as completed and closes its open focus session.
  Future<void> completeTask({required int taskId, required DateTime completedAt});

  Future<void> deleteTask(int taskId);

  Future<int> deleteCompletedTasksOlderThanDays(int days);

  Future<int> countCompletedTasksOlderThanDays(int days);

  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos);

  /// Checks or unchecks a single sub-task without rewriting the others (IDs stay stable).
  Future<void> setTodoCompletion({required int todoId, required bool isCompleted});
}
