enum TaskPriority {
  low(0),
  medium(1),
  high(2);

  const TaskPriority(this.value);

  final int value;

  static TaskPriority fromValue(int value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TaskPriority.low,
    );
  }
}

class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    required this.assignedDate,
    required this.sortOrder,
    required this.isCompleted,
    required this.priority,
    required this.timeSpent,
    required this.description,
    required this.latestStart,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime assignedDate;
  final String sortOrder;
  final bool isCompleted;
  final TaskPriority priority;
  final int timeSpent;
  final DateTime? latestStart;

  bool get isRunning => latestStart != null;

  Duration elapsedAt(DateTime now) {
    if (latestStart == null) {
      return Duration(milliseconds: timeSpent);
    }

    return Duration(milliseconds: timeSpent) + now.difference(latestStart!);
  }

  TaskEntity copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? assignedDate,
    String? sortOrder,
    bool? isCompleted,
    TaskPriority? priority,
    int? timeSpent,
    DateTime? latestStart,
    bool clearLatestStart = false,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedDate: assignedDate ?? this.assignedDate,
      sortOrder: sortOrder ?? this.sortOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      timeSpent: timeSpent ?? this.timeSpent,
      latestStart: clearLatestStart ? null : latestStart ?? this.latestStart,
    );
  }
}
