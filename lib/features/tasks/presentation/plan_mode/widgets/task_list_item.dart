import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:go_router/go_router.dart';

class TaskListItem extends ConsumerWidget {
  const TaskListItem({super.key, required this.task, required this.index});

  final TaskEntity task;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final isCompleted = task.isCompleted;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey(task.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Semantics(
          label: isCompleted ? 'Mark task as incomplete' : 'Mark task as complete',
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
              child: isCompleted ? const Icon(Icons.check, size: 18, color: Colors.white) : Icon(Icons.circle_outlined, size: 18, color: colorScheme.outline),
            ),
          ),
        ),
        title: Text(
          task.title,
          style: isCompleted ? TextStyle(decoration: TextDecoration.lineThrough, color: colorScheme.onSurfaceVariant) : null,
        ),
        subtitle: Text(task.description ?? 'No description', style: isCompleted ? TextStyle(color: colorScheme.onSurfaceVariant) : null),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Show time spent in red if the task is completed
            if (isCompleted && task.timeSpent > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  Duration(milliseconds: task.timeSpent).toFormattedString(),
                  style: const TextStyle(color: Color.fromARGB(255, 0, 168, 8), fontWeight: FontWeight.w500),
                ),
              ),
            IconButton(
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
