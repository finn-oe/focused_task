import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Builds a [TaskEntity] with sensible defaults so tests only specify what they care about.
TaskEntity buildTask({
  int id = 1,
  String title = 'Task',
  String? description,
  DateTime? assignedDate,
  String sortOrder = 'a0',
  bool isCompleted = false,
  TaskPriority priority = TaskPriority.low,
  int timeSpent = 0,
  DateTime? latestStart,
  int? targetDurationMinutes,
  List<TaskTodoEntity> todos = const [],
  int? categoryId,
  TaskSchedule schedule = TaskSchedule.none,
  int? recurrenceId,
  DateTime? occurrenceDate,
}) {
  return TaskEntity(
    id: id,
    title: title,
    description: description,
    assignedDate: assignedDate ?? DateTime(2026, 1, 1),
    sortOrder: sortOrder,
    isCompleted: isCompleted,
    priority: priority,
    timeSpent: timeSpent,
    latestStart: latestStart,
    targetDurationMinutes: targetDurationMinutes,
    todos: todos,
    categoryId: categoryId,
    schedule: schedule,
    recurrenceId: recurrenceId,
    occurrenceDate: occurrenceDate ?? (recurrenceId == null ? null : assignedDate ?? DateTime(2026, 1, 1)),
  );
}
