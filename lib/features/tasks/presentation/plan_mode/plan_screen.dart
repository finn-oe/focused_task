import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_list_item.dart';

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
            'Recover ${_formatDuration(total)} of tracked time?',
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
            child: Text(
              'Selected day: ${state.selectedDay.year}-${state.selectedDay.month.toString().padLeft(2, '0')}-${state.selectedDay.day.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
                      return ReorderableDragStartListener(
                        key: ValueKey(task.id),
                        index: index,
                        child: TaskListItem(task: task),
                      );
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddTaskDialog(context, notifier), icon: const Icon(Icons.add), label: const Text('Add Task')),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, PlanModeNotifier notifier) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }

                await notifier.addTask(title: title, description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim());

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
