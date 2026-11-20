/// What a change to an occurrence of a recurring task (#24) applies to.
enum RepeatScope { onlyThis, thisAndFuture }

/// How often a task repeats (#24).
enum RepeatFrequency {
  daily,

  /// Monday to Friday.
  weekdays,

  /// On the chosen days of the week.
  weekly,

  /// Every N days from the start date.
  interval,

  /// On one day of the month; months without that day use their last day.
  monthly,
}

/// The repeat setting of the task form: a frequency with its details and an optional last day.
class RepeatPattern {
  const RepeatPattern({required this.frequency, this.intervalDays = 2, this.weekdays = const {}, this.monthDay = 1, this.endDate});

  /// The default pattern for [frequency] on a task of [day]: weekly on its weekday, monthly on its day of the month.
  factory RepeatPattern.startingOn(RepeatFrequency frequency, DateTime day) {
    return RepeatPattern(frequency: frequency, weekdays: {day.weekday}, monthDay: day.day);
  }

  static const minIntervalDays = 2;
  static const maxIntervalDays = 365;

  final RepeatFrequency frequency;

  /// Days between occurrences ([RepeatFrequency.interval]).
  final int intervalDays;

  /// [DateTime.weekday] values ([RepeatFrequency.weekly]).
  final Set<int> weekdays;

  /// Day of the month, 1–31 ([RepeatFrequency.monthly]).
  final int monthDay;

  /// Last day that can have an occurrence (a calendar date); `null` = no end.
  final DateTime? endDate;

  /// Bit `weekday - 1` for each of [weekdays].
  int get weekdaysMask => weekdays.fold(0, (mask, weekday) => mask | 1 << (weekday - 1));

  static Set<int> weekdaysFromMask(int mask) => {
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (mask & 1 << (weekday - 1) != 0) weekday,
  };

  /// Whether [date] (a calendar date on or after [start], the first day of the series) matches the pattern. The end
  /// date is not checked here.
  bool matches(DateTime date, {required DateTime start}) {
    switch (frequency) {
      case RepeatFrequency.daily:
        return true;
      case RepeatFrequency.weekdays:
        return date.weekday <= DateTime.friday;
      case RepeatFrequency.weekly:
        return weekdays.contains(date.weekday);
      case RepeatFrequency.interval:
        final days = DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
        return days % intervalDays == 0;
      case RepeatFrequency.monthly:
        final lastDay = DateTime(date.year, date.month + 1, 0).day;
        return date.day == (monthDay < lastDay ? monthDay : lastDay);
    }
  }

  RepeatPattern copyWith({RepeatFrequency? frequency, int? intervalDays, Set<int>? weekdays, int? monthDay, DateTime? endDate, bool clearEndDate = false}) {
    final end = clearEndDate ? null : endDate ?? this.endDate;
    return RepeatPattern(
      frequency: frequency ?? this.frequency,
      intervalDays: intervalDays ?? this.intervalDays,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      endDate: end == null ? null : DateTime(end.year, end.month, end.day),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! RepeatPattern || other.frequency != frequency) return false;
    final end = endDate;
    final otherEnd = other.endDate;
    final sameEnd = end == null ? otherEnd == null : otherEnd != null && otherEnd.year == end.year && otherEnd.month == end.month && otherEnd.day == end.day;
    // Only the details of the frequency count.
    return sameEnd &&
        switch (frequency) {
          RepeatFrequency.daily || RepeatFrequency.weekdays => true,
          RepeatFrequency.weekly => other.weekdaysMask == weekdaysMask,
          RepeatFrequency.interval => other.intervalDays == intervalDays,
          RepeatFrequency.monthly => other.monthDay == monthDay,
        };
  }

  @override
  int get hashCode => Object.hash(frequency, endDate?.year, endDate?.month, endDate?.day);
}
