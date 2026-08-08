class TaskStats {
  const TaskStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalFocusMinutes,
    required this.averageTaskDurationMinutes,
    required this.focusMinutesPerDay,
    required this.completionScore,
  });

  final int totalTasks;
  final int completedTasks;
  final int totalFocusMinutes;
  final int averageTaskDurationMinutes;
  final int focusMinutesPerDay;
  final double completionScore;

  factory TaskStats.fromTasks(Iterable<dynamic> tasks, {required int daysInRange}) {
    final taskList = tasks.toList(growable: false);
    final completedTasks = taskList.where((task) => task.isCompleted).toList(growable: false);

    final now = DateTime.now();

    final tasksWithTime = taskList.where((task) => task.elapsedAt(now).inMilliseconds > 0).toList(growable: false);
    int totalMilliseconds = 0;
    for (final task in tasksWithTime) {
      totalMilliseconds += task.elapsedAt(now).inMilliseconds as int;
    }
    final totalFocusMinutes = totalMilliseconds ~/ 60000;
    final completedCount = completedTasks.length;
    final totalTaskCount = taskList.length;
    final averageDuration = tasksWithTime.isEmpty ? 0 : (totalMilliseconds ~/ tasksWithTime.length) ~/ 60000;
    final minutesPerDay = daysInRange <= 0 ? 0 : (totalMilliseconds ~/ daysInRange) ~/ 60000;
    final completionScore = totalTaskCount == 0 ? 0.0 : (completedCount / totalTaskCount) * 100;

    return TaskStats(
      totalTasks: totalTaskCount,
      completedTasks: completedCount,
      totalFocusMinutes: totalFocusMinutes,
      averageTaskDurationMinutes: averageDuration,
      focusMinutesPerDay: minutesPerDay,
      completionScore: double.parse(completionScore.toStringAsFixed(1)),
    );
  }
}
