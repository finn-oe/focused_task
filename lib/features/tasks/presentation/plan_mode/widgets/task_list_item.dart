import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/core/utils/date_utils.dart';

class TaskListItem extends ConsumerWidget {
  const TaskListItem({super.key, required this.task, required this.index});

  final TaskEntity task;
  final int index;

  Future<void> _showCopyToTodayDialog(BuildContext context, WidgetRef ref, DateTime today) async {
    bool keepTodoCompletion = false;
    bool subtractTimeSpent = true;

    final hasTodos = task.todos.isNotEmpty;
    final hasTargetDuration = task.targetDurationMinutes != null;

    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.taskCopyToTodayTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.taskCopyToTodayQuestion),
                  const SizedBox(height: 16),

                  if (hasTodos)
                    SwitchListTile(
                      title: Text(l10n.taskKeepCompletedTodos),
                      subtitle: Text(l10n.taskKeepCompletedTodosHint),
                      value: keepTodoCompletion,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => keepTodoCompletion = value),
                    ),

                  if (hasTargetDuration)
                    SwitchListTile(
                      title: Text(l10n.taskSubtractTimeSpent),
                      subtitle: Text(l10n.taskSubtractTimeSpentHint),
                      value: subtractTimeSpent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => subtractTimeSpent = value),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonCopy)),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final notifier = ref.read(planModeNotifierProvider.notifier);
      await notifier.duplicateTaskToDate(task: task, date: today, keepTodoCompletion: keepTodoCompletion, subtractTimeSpent: subtractTimeSpent);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final isCompleted = task.isCompleted;
    final colorScheme = Theme.of(context).colorScheme;

    final totalTodos = task.todos.length;
    final completedTodos = task.todos.where((t) => t.isCompleted).length;

    final shouldShowProgress = totalTodos > 0 && task.timeSpent > 0 && !task.isCompleted;

    final today = DateTime.now().dateOnly;
    final isPast = task.assignedDate.dateOnly.isBefore(today);

    return Card(
      key: ValueKey(task.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Semantics(
          label: isCompleted ? l10n.taskMarkIncomplete : l10n.taskMarkComplete,
          button: true,
          child: GestureDetector(
            onTap: () => notifier.toggleTaskCompletion(task),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isCompleted ? colorScheme.primary : colorScheme.outline),
                color: isCompleted ? colorScheme.primary : Colors.transparent,
              ),
              child: isCompleted ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary) : Icon(Icons.circle_outlined, size: 18, color: colorScheme.outline),
            ),
          ),
        ),
        title: Text(
          task.title,
          style: isCompleted ? TextStyle(decoration: TextDecoration.lineThrough, color: colorScheme.onSurfaceVariant) : null,
        ),
        subtitle: Text(task.description ?? l10n.taskNoDescription, style: isCompleted ? TextStyle(color: colorScheme.onSurfaceVariant) : null),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shouldShowProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  l10n.taskTodoProgress(completedTodos, totalTodos),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
                ),
              ),
            if (isCompleted && task.timeSpent > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  Duration(milliseconds: task.timeSpent).toFormattedString(),
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ),

            if (isPast)
              IconButton(
                tooltip: l10n.taskCopyToTodayTooltip,
                icon: const Icon(Icons.today_outlined),
                color: isCompleted ? colorScheme.onSurfaceVariant : null,
                onPressed: () => _showCopyToTodayDialog(context, ref, today),
              )
            else
              IconButton(
                tooltip: l10n.taskEditTooltip,
                icon: const Icon(Icons.edit_outlined),
                color: isCompleted ? colorScheme.onSurfaceVariant : null,
                onPressed: () => context.push('/task-form', extra: task),
              ),

            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: isCompleted ? colorScheme.onSurfaceVariant : null),
            ),
          ],
        ),
      ),
    );
  }
}
