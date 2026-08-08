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
    final tasksWithTime = taskList.where((task) => task.elapsedAt(DateTime.now()).inMilliseconds > 0).toList(growable: false);
    var totalFocusMinutes = 0;

    for (final task in tasksWithTime) {
      final int minutes = task.elapsedAt(DateTime.now()).inMilliseconds ~/ 60000;
      totalFocusMinutes += minutes;
    }

    final completedCount = completedTasks.length;
    final totalTaskCount = taskList.length;
    final averageDuration = tasksWithTime.isEmpty ? 0 : totalFocusMinutes ~/ tasksWithTime.length;
    final completionScore = totalTaskCount == 0 ? 0 : (completedCount / totalTaskCount) * 100;

    return TaskStats(
      totalTasks: totalTaskCount,
      completedTasks: completedCount,
      totalFocusMinutes: totalFocusMinutes,
      averageTaskDurationMinutes: averageDuration,
      focusMinutesPerDay: daysInRange <= 0 ? 0 : totalFocusMinutes ~/ daysInRange,
      completionScore: double.parse(completionScore.toStringAsFixed(1)),
    );
  }
}
