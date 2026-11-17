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

  Future<void> updateTaskDetails({required int taskId, required String title, String? description, int? targetDurationMinutes, DateTime? assignedDate});

  Future<void> updateTaskOrder({required int taskId, required String sortOrder});

  Future<void> setTaskCompletion({required int taskId, required bool isCompleted});

  Future<TaskStats> getTaskStats({required DateTime start, required DateTime end});

  Future<void> startTaskSession({required int taskId, required DateTime startedAt});

  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt});

  /// Marks the running session of [taskId] as alive at [at] (see [TaskEntity.lastSeenAt]).
  Future<void> recordHeartbeat({required int taskId, required DateTime at});

  Future<void> completeTask({required int taskId, required DateTime completedAt});

  Future<void> deleteTask(int taskId);

  Future<void> discardUnfinishedSession({required int taskId});

  Future<List<TaskEntity>> getRecoverableSessions();

  Future<int> deleteCompletedTasksOlderThanDays(int days);

  Future<int> countCompletedTasksOlderThanDays(int days);

  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos);
}
