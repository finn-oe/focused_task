import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/session_recovery_dialog.dart';
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

  Future<void> _handleRecoverableSessions() async {
    if (_recoveryHandled) {
      return;
    }

    _recoveryHandled = true;
    final focus = ref.read(focusModeNotifierProvider.notifier);
    final sessions = await focus.loadRecoverableSessions();
    if (!mounted || sessions.isEmpty) {
      return;
    }

    final recovery = await showSessionRecoveryDialog(context, sessions: sessions, now: DateTime.now());
    if (recovery == null) {
      return;
    }

    await focus.recoverSessions(recovery: recovery, sessions: sessions);
  }

  Future<void> _pickDay() async {
    final state = ref.read(planModeNotifierProvider);
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: state.selectedDay);
    if (selected != null) {
      await notifier.setSelectedDay(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(planModeNotifierProvider);
    final notifier = ref.read(planModeNotifierProvider.notifier);

    final now = DateTime.now();
    final totalTimeSpentMs = state.tasks.fold<int>(0, (sum, task) => sum + task.elapsedAt(now).inMilliseconds);
    final totalDuration = Duration(milliseconds: totalTimeSpentMs);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTitle),
        actions: [
          IconButton(tooltip: l10n.planSettingsTooltip, onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
          IconButton(tooltip: l10n.planPickDayTooltip, onPressed: _pickDay, icon: const Icon(Icons.calendar_today_outlined)),
          IconButton(tooltip: l10n.planStatisticsTooltip, onPressed: () => context.push('/stats'), icon: const Icon(Icons.insights_outlined)),
          IconButton(tooltip: l10n.planStartFocusTooltip, onPressed: () => context.go('/focus'), icon: const Icon(Icons.play_arrow)),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: InkWell(
              onTap: _pickDay,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.planSelectedDay(relativeDayLabel(context, state.selectedDay, today: now)), style: Theme.of(context).textTheme.titleMedium),
                    if (totalTimeSpentMs > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            totalDuration.toFormattedString(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                ? Center(child: Text(l10n.planNoTasks))
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
              child: Text(l10n.planLoadError(state.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/task-form'), icon: const Icon(Icons.add), label: Text(l10n.planAddTask)),
    );
  }
}
