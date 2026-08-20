extension DurationFormatting on Duration {
  String toFormattedString() {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = (inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
