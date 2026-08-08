import 'package:flutter/material.dart';

class TaskTimer extends StatelessWidget {
  const TaskTimer({super.key, required this.elapsed, this.targetMinutes});

  final Duration elapsed;
  final int? targetMinutes;

  @override
  Widget build(BuildContext context) {
    String label = 'Task';
    String value;
    Color? activeColor;

    if (targetMinutes == null) {
      value = _format(elapsed);
    } else {
      final targetMs = targetMinutes! * 60 * 1000;
      final remainingMs = targetMs - elapsed.inMilliseconds;

      if (remainingMs >= 0) {
        label = 'Remaining';
        value = _format(Duration(milliseconds: remainingMs));
      } else {
        label = 'Overdue';
        value = '+${_format(Duration(milliseconds: remainingMs.abs()))}';
        activeColor = Theme.of(context).colorScheme.error; // Turns red when time is up
      }
    }

    return _TimerBox(label: label, value: value, color: activeColor);
  }
}

class _TimerBox extends StatelessWidget {
  const _TimerBox({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final contentColor = color ?? Theme.of(context).colorScheme.onSurface;
    final borderColor = color ?? Theme.of(context).colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: contentColor)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: contentColor)),
        ],
      ),
    );
  }
}

String _format(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
