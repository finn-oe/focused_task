import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/domain/entities/day_summary.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

abstract class ITaskRepository {
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day);

  Future<List<TaskEntity>> getTasksForDay(DateTime day);

  Future<TaskEntity?> getTaskById(int id);

  /// Tasks assigned to the days of [range], ordered by day and sort order. Sub-tasks and running state are not loaded.
  Stream<List<TaskEntity>> watchTasksInRange(DateRange range);

  /// Summary of every day of [range] that has tasks or focus time (other days are omitted). Task counts come from
  /// the tasks assigned to the day; focus time from the session log, on the day it happened (split at local midnight).
  Future<Map<DateTime, DaySummary>> getDaySummaries(DateRange range);

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

  /// Open tasks assigned to `[start, end]` (calendar dates, inclusive), by day and then plan order.
  Future<List<TaskEntity>> getOpenTasksBetween({required DateTime start, required DateTime end});

  /// Moves the open tasks among [taskIds] to the day [to], after the tasks already there (in the given order), in one
  /// transaction. Completed tasks and tasks already on [to] are left alone. The task keeps its id, sub-tasks, tracked
  /// time and focus sessions; sessions stay on the day they happened.
  ///
  /// Returns the ids of the tasks that moved.
  Future<List<int>> moveTasks({required List<int> taskIds, required DateTime to});

  Future<void> setTaskCompletion({required int taskId, required bool isCompleted});

  /// Statistics of `query.range`: task counts come from the tasks assigned to the range; focus time comes from the
  /// sessions in that range, by the time they actually happened (split at local midnight). Days after today don't count
  /// for averages.
  Future<StatsReport> getStatsReport(StatsQuery query);

  /// Marks the task as completed and closes its open focus session.
  Future<void> completeTask({required int taskId, required DateTime completedAt});

  Future<void> deleteTask(int taskId);

  Future<int> deleteCompletedTasksOlderThanDays(int days);

  Future<int> countCompletedTasksOlderThanDays(int days);

  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos);

  /// Checks or unchecks a single sub-task without rewriting the others (IDs stay stable).
  Future<void> setTodoCompletion({required int todoId, required bool isCompleted});
}
