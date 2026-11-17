extension DurationFormatting on Duration {
  /// `HH:MM`, e.g. `01:05` – for totals.
  String toFormattedString() {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = (inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// `HH:MM:SS`, e.g. `01:05:09` – for running timers. Negative durations are formatted by magnitude.
  String toClockString() {
    final value = isNegative ? -this : this;
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
