enum TaskPriority {
  low(0),
  medium(1),
  high(2);

  const TaskPriority(this.value);

  final int value;

  static TaskPriority fromValue(int value) {
    return TaskPriority.values.firstWhere((priority) => priority.value == value, orElse: () => TaskPriority.low);
  }
}

class TaskTodoEntity {
  const TaskTodoEntity({this.id, required this.title, required this.isCompleted, required this.sortOrder});

  final int? id;
  final String title;
  final bool isCompleted;
  final String sortOrder;

  TaskTodoEntity copyWith({int? id, String? title, bool? isCompleted, String? sortOrder}) {
    return TaskTodoEntity(id: id ?? this.id, title: title ?? this.title, isCompleted: isCompleted ?? this.isCompleted, sortOrder: sortOrder ?? this.sortOrder);
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
    this.targetDurationMinutes,
    this.lastSeenAt,
    required this.todos,
    this.categoryId,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime assignedDate;
  final String sortOrder;
  final bool isCompleted;
  final TaskPriority priority;

  /// Tracked time of all closed focus sessions in milliseconds.
  final int timeSpent;

  /// Start of the task's open focus session, or `null` if none is running.
  final DateTime? latestStart;
  final int? targetDurationMinutes;

  /// Last heartbeat of the open focus session.
  final DateTime? lastSeenAt;
  final List<TaskTodoEntity> todos;

  /// The task's category, `null` if it has none.
  final int? categoryId;

  bool get isRunning => latestStart != null;

  /// Time of the last sign of life of an unfinished session: the heartbeat, or the session start
  /// when no heartbeat was ever written. `null` if no session is running.
  DateTime? get lastActivityAt {
    if (latestStart == null) return null;
    final seen = lastSeenAt;
    return seen != null && seen.isAfter(latestStart!) ? seen : latestStart;
  }

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
    bool clearTargetDuration = false,
    int? targetDurationMinutes,
    DateTime? lastSeenAt,
    List<TaskTodoEntity>? todos,
    int? categoryId,
    bool clearCategory = false,
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
      targetDurationMinutes: clearTargetDuration ? null : targetDurationMinutes ?? this.targetDurationMinutes,
      lastSeenAt: clearLatestStart ? null : lastSeenAt ?? this.lastSeenAt,
      todos: todos ?? this.todos,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    );
  }
}
