import 'package:focused_task/features/tasks/domain/entities/task.dart';

abstract class ITaskRepository {
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day);

  Future<List<TaskEntity>> getTasksForDay(DateTime day);

  Future<TaskEntity?> getTaskById(int id);

  Future<TaskEntity?> getNextIncompleteTaskForDay(DateTime day);

  Future<void> createTask({required String title, String? description, required DateTime assignedDate, required String sortOrder, TaskPriority priority = TaskPriority.low});

  Future<void> updateTaskOrder({required int taskId, required String sortOrder});

  Future<void> startTaskSession({required int taskId, required DateTime startedAt});

  Future<void> pauseTaskSession({required int taskId, required DateTime pausedAt});

  Future<void> completeTask({required int taskId, required DateTime completedAt});

  Future<void> discardUnfinishedSession({required int taskId});

  Future<List<TaskEntity>> getRecoverableSessions();
}
