/// What happened on one calendar day: tasks assigned to it and focus time worked on it.
class DaySummary {
  const DaySummary({this.total = 0, this.completed = 0, this.focusTime = Duration.zero});

  static const empty = DaySummary();

  /// Tasks assigned to the day.
  final int total;

  /// Completed tasks among [total].
  final int completed;

  /// Focus time recorded on the day (sessions split at local midnight), whatever task it was for.
  final Duration focusTime;

  bool get isEmpty => total == 0 && focusTime == Duration.zero;

  DaySummary copyWith({int? total, int? completed, Duration? focusTime}) {
    return DaySummary(total: total ?? this.total, completed: completed ?? this.completed, focusTime: focusTime ?? this.focusTime);
  }

  @override
  bool operator ==(Object other) => other is DaySummary && other.total == total && other.completed == completed && other.focusTime == focusTime;

  @override
  int get hashCode => Object.hash(total, completed, focusTime);

  @override
  String toString() => 'DaySummary($completed/$total, $focusTime)';
}
