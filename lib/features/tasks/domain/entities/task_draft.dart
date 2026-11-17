import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// The editable values of a task in the form. Value equality tells whether there are unsaved changes.
class TaskDraft {
  const TaskDraft({required this.title, required this.description, required this.date, required this.targetMinutes, required this.priority, required this.todos});

  /// An empty task on [date].
  factory TaskDraft.empty(DateTime date) {
    return TaskDraft(title: '', description: '', date: date, targetMinutes: null, priority: TaskPriority.low, todos: const []);
  }

  factory TaskDraft.fromTask(TaskEntity task) {
    return TaskDraft(
      title: task.title,
      description: task.description ?? '',
      date: task.assignedDate,
      targetMinutes: task.targetDurationMinutes,
      priority: task.priority,
      todos: List.unmodifiable(task.todos),
    );
  }

  /// Longest target the form allows.
  static const maxTargetMinutes = 12 * 60;

  final String title;
  final String description;
  final DateTime date;
  final int? targetMinutes;
  final TaskPriority priority;
  final List<TaskTodoEntity> todos;

  bool get hasTitle => title.trim().isNotEmpty;

  TaskDraft copyWith({String? title, String? description, DateTime? date, int? targetMinutes, bool clearTarget = false, TaskPriority? priority, List<TaskTodoEntity>? todos}) {
    return TaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      targetMinutes: clearTarget ? null : targetMinutes ?? this.targetMinutes,
      priority: priority ?? this.priority,
      todos: todos == null ? this.todos : List.unmodifiable(todos),
    );
  }

  static bool _sameTodos(List<TaskTodoEntity> a, List<TaskTodoEntity> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].title != b[i].title || a[i].isCompleted != b[i].isCompleted) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is TaskDraft &&
        other.title.trim() == title.trim() &&
        other.description.trim() == description.trim() &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day &&
        other.targetMinutes == targetMinutes &&
        other.priority == priority &&
        _sameTodos(other.todos, todos);
  }

  @override
  int get hashCode => Object.hash(title.trim(), description.trim(), date.year, date.month, date.day, targetMinutes, priority, todos.length);
}
