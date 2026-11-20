import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/schedule_labels.dart';

/// Small chips with a task's start time and deadline (#10); nothing for a task without them. The deadline turns to the
/// warning colour within a day and to the error colour once it has passed (for open tasks).
class TaskScheduleChips extends ConsumerWidget {
  const TaskScheduleChips({super.key, required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = task.schedule;
    if (schedule.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final dueMinute = ref.watch(reminderSettingsProvider.select((settings) => settings.defaultDueMinute));
    final now = clock.now();
    final start = schedule.startMinute;
    final due = schedule.dueAt(defaultDueMinute: dueMinute);

    final (dueBackground, dueForeground) = switch (due) {
      null => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
      _ when task.isCompleted => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
      final DateTime due when due.isBefore(now) => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      final DateTime due when due.difference(now) <= const Duration(days: 1) => (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      _ => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
    };
    final overdue = due != null && task.isOverdueAt(now, defaultDueMinute: dueMinute);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (start != null)
            _Chip(
              key: ValueKey('taskStartChip-${task.id}'),
              icon: Icons.schedule,
              label: timeOfDayLabel(context, start),
              semanticLabel: l10n.taskStartsAt(timeOfDayLabel(context, start)),
              background: colorScheme.surfaceContainerHighest,
              foreground: colorScheme.onSurfaceVariant,
            ),
          if (due != null)
            _Chip(
              key: ValueKey('taskDueChip-${task.id}'),
              icon: overdue ? Icons.warning_amber_rounded : Icons.flag_outlined,
              label: l10n.taskScheduleDue(dueDayLabel(context, due, now: now)),
              semanticLabel: overdue ? l10n.taskOverdueDue(momentLabel(context, due, now: now)) : l10n.taskScheduleDue(momentLabel(context, due, now: now)),
              background: dueBackground,
              foreground: dueForeground,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.label, required this.semanticLabel, required this.background, required this.foreground});

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 3),
              Text(label, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2 tasks overdue" above today's plan (#10); opens the list of overdue tasks, from any day.
class OverdueBanner extends ConsumerWidget {
  const OverdueBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueTasksProvider).value ?? const [];
    if (overdue.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Card(
      key: const Key('overdueBanner'),
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
        title: Text(l10n.planOverdueBanner(overdue.length), style: TextStyle(color: colorScheme.onErrorContainer)),
        trailing: TextButton(
          onPressed: () => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (context) => const _OverdueSheet()),
          child: Text(l10n.planOverdueShow),
        ),
      ),
    );
  }
}

class _OverdueSheet extends ConsumerWidget {
  const _OverdueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overdue = ref.watch(overdueTasksProvider).value ?? const [];
    final today = clock.now();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.planOverdueSheetTitle, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final task in overdue)
                    ListTile(
                      key: ValueKey('overdueTask-${task.id}'),
                      title: Text(task.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.planOverduePlannedFor(relativeDayLabel(context, task.assignedDate, today: today))),
                          TaskScheduleChips(task: task),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        // The overdue list has no sub-tasks; the form needs the whole task.
                        final full = await ref.read(planModeNotifierProvider.notifier).taskById(task.id);
                        if (full != null) await router.push<void>(AppRoutes.taskForm, extra: full);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
