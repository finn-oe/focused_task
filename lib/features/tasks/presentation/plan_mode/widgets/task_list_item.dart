import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/task_form_fields.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_move_feedback.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_schedule_chips.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/core/utils/date_utils.dart';

/// Actions in a past task's "Move or copy" menu.
enum _TaskMenuAction { moveToToday, moveTo, copyTo }

class TaskListItem extends ConsumerWidget {
  const TaskListItem({super.key, required this.task, this.index});

  final TaskEntity task;

  /// Position in the reorderable list for the drag handle; `null` = not reorderable (no handle).
  final int? index;

  Future<void> _onMenuAction(BuildContext context, WidgetRef ref, _TaskMenuAction action, DateTime today) async {
    switch (action) {
      case _TaskMenuAction.moveToToday:
        await _moveTo(context, ref, today);
      case _TaskMenuAction.moveTo:
        final day = await _pickDay(context, initial: today, except: task.assignedDate);
        if (day != null && context.mounted) await _moveTo(context, ref, day);
      case _TaskMenuAction.copyTo:
        final day = await _pickDay(context, initial: today);
        if (day != null && context.mounted) await _showCopyDialog(context, ref, day, today: today);
    }
  }

  Future<DateTime?> _pickDay(BuildContext context, {required DateTime initial, DateTime? except}) {
    return showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
      selectableDayPredicate: except == null ? null : (day) => !day.isSameDate(except),
    );
  }

  Future<void> _moveTo(BuildContext context, WidgetRef ref, DateTime day) async {
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final feedback = TaskMoveFeedback.of(context, notifier);
    feedback.show(await notifier.moveTasks([task.id], day));
  }

  Future<void> _showCopyDialog(BuildContext context, WidgetRef ref, DateTime day, {required DateTime today}) async {
    bool keepTodoCompletion = false;
    bool subtractTimeSpent = true;

    final hasTodos = task.todos.isNotEmpty;
    final hasTargetDuration = task.targetDurationMinutes != null;

    final l10n = context.l10n;
    final dayLabel = relativeDayLabel(context, day, today: today);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.taskCopyToDateTitle(dayLabel)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.taskCopyQuestion),
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
      await notifier.duplicateTaskToDate(task: task, date: day, keepTodoCompletion: keepTodoCompletion, subtractTimeSpent: subtractTimeSpent);
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

    final today = clock.now().dateOnly;
    final isPast = task.assignedDate.dateOnly.isBefore(today);
    final category = ref.watch(categoriesNotifierProvider.select((categories) => categories.byId(task.categoryId)));

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
        onTap: () => context.push(AppRoutes.taskForm, extra: task),
        title: Row(
          children: [
            if (category != null) ...[
              Semantics(
                label: l10n.categoryLabel(category.name),
                child: CategoryDot(key: ValueKey('taskCategoryDot-${task.id}'), colorIndex: category.colorIndex),
              ),
              const SizedBox(width: 6),
            ],
            if (task.priority != TaskPriority.low) ...[PriorityFlag(priority: task.priority, size: 16), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                task.title,
                style: isCompleted ? TextStyle(decoration: TextDecoration.lineThrough, color: colorScheme.onSurfaceVariant) : null,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.description ?? l10n.taskNoDescription, style: isCompleted ? TextStyle(color: colorScheme.onSurfaceVariant) : null),
            TaskScheduleChips(task: task),
          ],
        ),
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

            // Past tasks can be edited too; open ones can be moved (to today first), any can be copied.
            if (isPast)
              PopupMenuButton<_TaskMenuAction>(
                tooltip: l10n.taskMoveOrCopyTooltip,
                icon: Icon(Icons.event_repeat_outlined, color: isCompleted ? colorScheme.onSurfaceVariant : null),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelected: (action) => _onMenuAction(context, ref, action, today),
                itemBuilder: (context) => [
                  if (!isCompleted) ...[
                    PopupMenuItem(
                      value: _TaskMenuAction.moveToToday,
                      child: ListTile(leading: const Icon(Icons.today_outlined), title: Text(l10n.taskMoveToToday), contentPadding: EdgeInsets.zero),
                    ),
                    PopupMenuItem(
                      value: _TaskMenuAction.moveTo,
                      child: ListTile(leading: const Icon(Icons.event_outlined), title: Text(l10n.taskMoveTo), contentPadding: EdgeInsets.zero),
                    ),
                  ],
                  PopupMenuItem(
                    value: _TaskMenuAction.copyTo,
                    child: ListTile(leading: const Icon(Icons.copy_outlined), title: Text(l10n.taskCopyTo), contentPadding: EdgeInsets.zero),
                  ),
                ],
              ),
            IconButton(
              tooltip: l10n.taskEditTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined),
              color: isCompleted ? colorScheme.onSurfaceVariant : null,
              onPressed: () => context.push(AppRoutes.taskForm, extra: task),
            ),
            if (!isCompleted)
              IconButton(
                tooltip: l10n.taskFocusTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.play_circle_outline, color: colorScheme.primary),
                onPressed: () => context.go(AppRoutes.focusFor(FocusRequest(task.assignedDate, startTaskId: task.id))),
              ),

            if (index case final index?)
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
