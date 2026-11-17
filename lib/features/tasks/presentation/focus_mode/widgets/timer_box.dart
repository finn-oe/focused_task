import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/duration_extensions.dart';

/// Labeled timer value used in focus mode.
class TimerBox extends StatelessWidget {
  const TimerBox({super.key, required this.label, required this.value, this.color, this.outlined = false});

  final String label;
  final String value;

  /// Overrides text and border colour, e.g. to highlight an overdue task.
  final Color? color;

  /// Outlined boxes use the surface colour with a border; filled boxes use a container colour.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = color ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: outlined ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: color ?? theme.colorScheme.outlineVariant) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: contentColor)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(color: contentColor)),
        ],
      ),
    );
  }
}

/// Total time of the current focus session.
class SessionTimer extends StatelessWidget {
  const SessionTimer({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) => TimerBox(label: 'Session', value: duration.toClockString());
}

/// Time spent on the current task, or the time remaining until / exceeding its target.
class TaskTimer extends StatelessWidget {
  const TaskTimer({super.key, required this.elapsed, this.targetMinutes});

  final Duration elapsed;
  final int? targetMinutes;

  @override
  Widget build(BuildContext context) {
    final target = targetMinutes;
    if (target == null) {
      return TimerBox(label: 'Task', value: elapsed.toClockString(), outlined: true);
    }

    final remaining = Duration(minutes: target) - elapsed;
    if (remaining.isNegative) {
      return TimerBox(label: 'Overdue', value: '+${remaining.toClockString()}', color: Theme.of(context).colorScheme.error, outlined: true);
    }
    return TimerBox(label: 'Remaining', value: remaining.toClockString(), outlined: true);
  }
}
