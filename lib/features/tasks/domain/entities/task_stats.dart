import 'package:focused_task/features/tasks/domain/entities/task.dart';

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

  /// [tasks] are the tasks assigned to the range (for the counts); [focusByTask] is the focus time spent in the range
  /// per task (`null` = deleted tasks), wherever those tasks are planned.
  factory TaskStats.from({required Iterable<TaskEntity> tasks, required Map<int?, Duration> focusByTask, required int daysInRange}) {
    final taskList = tasks.toList(growable: false);
    final completedCount = taskList.where((task) => task.isCompleted).length;
    final totalTaskCount = taskList.length;

    final worked = focusByTask.values.where((time) => time > Duration.zero).toList(growable: false);
    final totalMilliseconds = worked.fold(0, (sum, time) => sum + time.inMilliseconds);
    final averageDuration = worked.isEmpty ? 0 : (totalMilliseconds ~/ worked.length) ~/ 60000;
    final minutesPerDay = daysInRange <= 0 ? 0 : (totalMilliseconds ~/ daysInRange) ~/ 60000;
    final completionScore = totalTaskCount == 0 ? 0.0 : (completedCount / totalTaskCount) * 100;

    return TaskStats(
      totalTasks: totalTaskCount,
      completedTasks: completedCount,
      totalFocusMinutes: totalMilliseconds ~/ 60000,
      averageTaskDurationMinutes: averageDuration,
      focusMinutesPerDay: minutesPerDay,
      completionScore: double.parse(completionScore.toStringAsFixed(1)),
    );
  }
}
