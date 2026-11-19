/// Pomodoro-style work/break cycles (#27): work [work], then a [shortBreak]; every [longBreakEvery]th break is a
/// [longBreak] instead. Off by default.
class IntervalSettings {
  const IntervalSettings({
    this.isEnabled = false,
    this.work = defaultWork,
    this.shortBreak = defaultShortBreak,
    this.longBreak = defaultLongBreak,
    this.longBreakEvery = defaultLongBreakEvery,
    this.autoStart = false,
  });

  static const off = IntervalSettings();

  static const defaultWork = Duration(minutes: 25);
  static const defaultShortBreak = Duration(minutes: 5);
  static const defaultLongBreak = Duration(minutes: 15);
  static const defaultLongBreakEvery = 4;

  /// Durations the settings offer, in minutes.
  static const workOptions = [15, 20, 25, 30, 40, 45, 50, 60, 90];
  static const shortBreakOptions = [3, 5, 10, 15];
  static const longBreakOptions = [10, 15, 20, 25, 30];
  static const longBreakEveryOptions = [2, 3, 4, 5, 6];

  final bool isEnabled;
  final Duration work;
  final Duration shortBreak;
  final Duration longBreak;

  /// Every n-th break is a long one.
  final int longBreakEvery;

  /// Start the next work interval right after a break; otherwise it waits for the user. Breaks always start on their own.
  final bool autoStart;

  IntervalSettings copyWith({bool? isEnabled, Duration? work, Duration? shortBreak, Duration? longBreak, int? longBreakEvery, bool? autoStart}) {
    return IntervalSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      work: work ?? this.work,
      shortBreak: shortBreak ?? this.shortBreak,
      longBreak: longBreak ?? this.longBreak,
      longBreakEvery: longBreakEvery ?? this.longBreakEvery,
      autoStart: autoStart ?? this.autoStart,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IntervalSettings &&
      other.isEnabled == isEnabled &&
      other.work == work &&
      other.shortBreak == shortBreak &&
      other.longBreak == longBreak &&
      other.longBreakEvery == longBreakEvery &&
      other.autoStart == autoStart;

  @override
  int get hashCode => Object.hash(isEnabled, work, shortBreak, longBreak, longBreakEvery, autoStart);
}
