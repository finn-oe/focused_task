import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/core/ui/progress_ring.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/completed_section_header.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/task_form_fields.dart';

/// Width from which the groups are columns side by side instead of sections below each other.
const _columnsWidth = 720.0;
const _columnWidth = 300.0;

/// The day's tasks grouped by category: columns on wide screens, sections on narrow ones. Dragging a task (by its
/// handle) to another group changes its category.
class CategoryBoard extends ConsumerWidget {
  const CategoryBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planModeNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider).all;
    final groups = state.boardGroups(categories);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _columnsWidth) {
          return ListView(
            key: const Key('planBoard'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            children: [
              for (final group in groups)
                SizedBox(
                  width: _columnWidth,
                  child: _GroupTarget(group: group, day: state.selectedDay, column: true),
                ),
            ],
          );
        }
        return ListView(
          key: const Key('planBoard'),
          padding: const EdgeInsets.only(top: 4, bottom: 88), // keep the last task clear of the add button
          children: [for (final group in groups) _GroupTarget(group: group, day: state.selectedDay, column: false)],
        );
      },
    );
  }
}

/// One group, highlighted while a task from another group is dragged over it.
class _GroupTarget extends ConsumerWidget {
  const _GroupTarget({required this.group, required this.day, required this.column});

  final BoardGroup group;
  final DateTime day;

  /// Shown as a column (its tasks scroll inside it) rather than a section of the page.
  final bool column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryId = group.category?.id;

    return DragTarget<TaskEntity>(
      onWillAcceptWithDetails: (details) => details.data.categoryId != categoryId,
      onAcceptWithDetails: (details) => ref.read(planModeNotifierProvider.notifier).setTaskCategory(details.data, categoryId),
      builder: (context, candidates, _) {
        final state = ref.watch(planModeNotifierProvider);
        // With "Collapse completed tasks" (#58), the done ones go into a section that can be shown or hidden.
        final collapse = ref.watch(collapseCompletedProvider) && group.completedCount > 0;
        final expanded = state.expandedBoardGroups.contains(categoryId);
        final tasks = [
          for (final task in collapse ? group.openTasks : group.tasks) _BoardTaskCard(key: ValueKey(task.id), task: task),
          if (group.tasks.isEmpty) _DropHint(highlighted: candidates.isNotEmpty),
          if (collapse) ...[
            CompletedSectionHeader(
              key: ValueKey('boardCompleted-${categoryId ?? 'none'}'),
              count: group.completedCount,
              expanded: expanded,
              dense: true,
              onToggle: () => ref.read(planModeNotifierProvider.notifier).toggleBoardGroupCompleted(categoryId),
            ),
            if (expanded)
              for (final task in group.completedTasks) _BoardTaskCard(key: ValueKey(task.id), task: task),
          ],
        ];
        return AnimatedContainer(
          key: ValueKey('boardGroup-${categoryId ?? 'none'}'),
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(color: candidates.isNotEmpty ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: column ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _GroupHeader(group: group, day: day),
              if (column)
                Expanded(
                  child: ListView(padding: const EdgeInsets.only(bottom: 8), children: tasks),
                )
              else ...[
                ...tasks,
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Completion ring (dot while empty), name, number of open tasks, tracked time and "Focus on …".
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.day});

  final BoardGroup group;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final category = group.category;
    final name = category?.name ?? l10n.planNoCategory;
    final tracked = group.trackedAt(clock.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          _GroupProgress(group: group),
          const SizedBox(width: 8),
          // Name and open count give way first (ellipsis), so ring, time and focus button always fit.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Text(name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.planCategoryOpenTasks(group.openCount),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (tracked >= const Duration(minutes: 1)) _TrackedTime(key: ValueKey('boardGroupTracked-${category?.id ?? 'none'}'), tracked: tracked),
          // Without a category, "Start focus" in the app bar already covers all tasks.
          if (category != null && group.openCount > 0)
            IconButton(
              tooltip: l10n.planFocusOnCategory(category.name),
              icon: Icon(Icons.play_circle_outline, color: theme.colorScheme.primary),
              onPressed: () => context.go(AppRoutes.focusFor(FocusRequest(day, categoryId: category.id))),
            )
          else
            const SizedBox(height: kMinInteractiveDimension, width: 8),
        ],
      ),
    );
  }
}

/// How many of the group's tasks are done, as a ring in the category colour; the plain dot while the group is empty.
class _GroupProgress extends StatelessWidget {
  const _GroupProgress({required this.group});

  final BoardGroup group;

  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    final category = group.category;
    final rate = group.completionRate;
    if (rate == null) {
      // Same width as the ring, so the names line up.
      return SizedBox(
        width: _size,
        child: category == null ? null : Center(child: CategoryDot(colorIndex: category.colorIndex, size: 12)),
      );
    }

    final label = context.l10n.planCategoryProgress(group.completedCount, group.totalCount, (rate * 100).round());
    return Tooltip(
      key: ValueKey('boardGroupRing-${category?.id ?? 'none'}'),
      message: label,
      child: ProgressRing(progress: rate, done: group.openCount == 0, size: _size, color: category == null ? null : CategoryColor.of(category.colorIndex).color(context)),
    );
  }
}

/// The group's tracked time, `HH:MM`.
class _TrackedTime extends StatelessWidget {
  const _TrackedTime({super.key, required this.tracked});

  final Duration tracked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = tracked.toFormattedString();
    return Tooltip(
      message: context.l10n.planCategoryTracked(text),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 2),
          Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

class _DropHint extends StatelessWidget {
  const _DropHint({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        context.l10n.planBoardDropHere,
        style: theme.textTheme.bodyMedium?.copyWith(color: highlighted ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A compact task card: complete, open (tap), focus, and a handle to drag it to another group.
class _BoardTaskCard extends ConsumerWidget {
  const _BoardTaskCard({super.key, required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final isCompleted = task.isCompleted;

    final title = Row(
      children: [
        if (task.priority != TaskPriority.low) ...[PriorityFlag(priority: task.priority, size: 16), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            task.title,
            overflow: TextOverflow.ellipsis,
            style: isCompleted ? TextStyle(decoration: TextDecoration.lineThrough, color: colorScheme.onSurfaceVariant) : null,
          ),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 4),
        leading: Checkbox(value: isCompleted, semanticLabel: isCompleted ? l10n.taskMarkIncomplete : l10n.taskMarkComplete, onChanged: (_) => notifier.toggleTaskCompletion(task)),
        title: title,
        onTap: () => context.push(AppRoutes.taskForm, extra: task),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompleted)
              IconButton(
                tooltip: l10n.taskFocusTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.play_circle_outline, color: colorScheme.primary),
                onPressed: () => context.go(AppRoutes.focusFor(FocusRequest(task.assignedDate, startTaskId: task.id))),
              ),
            Draggable<TaskEntity>(
              data: task,
              feedback: _DragFeedback(title: task.title),
              childWhenDragging: Icon(Icons.drag_indicator, color: colorScheme.outlineVariant),
              child: Tooltip(
                message: l10n.planBoardDragTooltip,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(title, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}
