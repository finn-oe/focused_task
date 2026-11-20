import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/ui/keyboard.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Title with validation: a task needs a title.
class TaskTitleField extends StatelessWidget {
  const TaskTitleField({super.key, required this.controller, required this.autofocus, required this.onChanged});

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      onTapOutside: unfocusOnTapOutside,
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: l10n.taskFormTitleLabel, border: const OutlineInputBorder()),
      validator: (value) => (value ?? '').trim().isEmpty ? l10n.taskFormTitleRequired : null,
      onChanged: onChanged,
    );
  }
}

/// The task's day, formatted for the locale. Tap to pick another day.
class TaskDateField extends StatelessWidget {
  const TaskDateField({super.key, required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date);
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: context.l10n.taskFormDateLabel, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.event_outlined)),
        child: Text(DateFormat.yMMMMEEEEd(locale).format(date)),
      ),
    );
  }
}

/// Low / Medium / High.
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({super.key, required this.priority, required this.onChanged});

  final TaskPriority priority;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<TaskPriority>(
      segments: [
        ButtonSegment(value: TaskPriority.low, label: Text(l10n.priorityLow)),
        ButtonSegment(
          value: TaskPriority.medium,
          label: Text(l10n.priorityMedium),
          icon: const PriorityFlag(priority: TaskPriority.medium),
        ),
        ButtonSegment(
          value: TaskPriority.high,
          label: Text(l10n.priorityHigh),
          icon: const PriorityFlag(priority: TaskPriority.high),
        ),
      ],
      selected: {priority},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Small flag for Medium (tertiary) and High (error) priority; nothing for Low.
class PriorityFlag extends StatelessWidget {
  const PriorityFlag({super.key, required this.priority, this.size = 18});

  final TaskPriority priority;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final (color, label) = switch (priority) {
      TaskPriority.low => (null, null),
      TaskPriority.medium => (colorScheme.tertiary, l10n.taskPriorityMedium),
      TaskPriority.high => (colorScheme.error, l10n.taskPriorityHigh),
    };
    if (color == null) return const SizedBox.shrink();
    return Icon(Icons.flag, size: size, color: color, semanticLabel: label);
  }
}
