import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form_modal.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_list_item.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _recoveryHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRecoverableSessions();
    });
  }

  String _formatSelectedDate(DateTime selectedDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    final difference = targetDate.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else {
      return '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleRecoverableSessions() async {
    if (_recoveryHandled) {
      return;
    }

    _recoveryHandled = true;
    final repository = ref.read(taskRepositoryProvider);
    final sessions = await repository.getRecoverableSessions();
    if (!mounted || sessions.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final total = sessions.fold<Duration>(Duration.zero, (sum, task) => task.latestStart == null ? sum : sum + now.difference(task.latestStart!));

    final recover = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recover unfinished session?'),
          content: Text(
            'We found ${sessions.length} unfinished focus session(s). '
            'Recover ${total.toFormattedString()} of tracked time?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Discard')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Recover')),
          ],
        );
      },
    );

    if (recover == null) {
      return;
    }

    await ref.read(focusModeNotifierProvider.notifier).recoverOrDiscardSessions(recover: recover, sessions: sessions);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planModeNotifierProvider);
    final notifier = ref.read(planModeNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Mode'),
        actions: [
          IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
          IconButton(
            tooltip: 'Pick Day',
            onPressed: () async {
              final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: state.selectedDay);
              if (selected != null) {
                await notifier.setSelectedDay(selected);
              }
            },
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          IconButton(tooltip: 'Statistics', onPressed: () => context.push('/stats'), icon: const Icon(Icons.insights_outlined)),
          IconButton(tooltip: 'Start Focus', onPressed: () => context.go('/focus'), icon: const Icon(Icons.play_arrow)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Text('Selected day: ${_formatSelectedDate(state.selectedDay)}', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                ? const Center(child: Text('No tasks for this day.'))
                : ReorderableListView.builder(
                    itemCount: state.tasks.length,
                    onReorderItem: notifier.reorderTask,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
                      return TaskListItem(key: ValueKey(task.id), task: task, index: index);
                    },
                  ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => TaskFormModal.show(context), icon: const Icon(Icons.add), label: const Text('Add Task')),
    );
  }
}
