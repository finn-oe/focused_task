import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/lifecycle_observer.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/widgets/timer_box.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(focusModeNotifierProvider.notifier).initializeForDay(DateTime.now());

      final settings = ref.read(settingsNotifierProvider);
      if (settings.enableWakelock) {
        WakelockPlus.enable();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _exitToPlan() async {
    await ref.read(focusModeNotifierProvider.notifier).exitFocus();
    if (!mounted) return;
    context.go('/plan');
  }

  Future<void> _showAlarmDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.focusTimeIsUp),
          content: Text(l10n.focusTargetReached),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.focusStopAlarmAndContinue))],
        );
      },
    );

    if (!mounted) return;
    await ref.read(focusModeNotifierProvider.notifier).dismissAlarm();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FocusModeState>(focusModeNotifierProvider, (previous, next) {
      if (!mounted) return;
      if (previous?.shouldShowFinishedForToday != true && next.shouldShowFinishedForToday && !next.isLoading) {
        ref.read(focusModeNotifierProvider.notifier).clearFinishedForToday();
        context.go('/finished-for-today');
      }
      if (previous?.shouldShowAlarm != true && next.shouldShowAlarm) {
        _showAlarmDialog();
      }
    });

    final state = ref.watch(focusModeNotifierProvider);
    final notifier = ref.read(focusModeNotifierProvider.notifier);
    final settings = ref.watch(settingsNotifierProvider);

    return FocusLifecycleObserver(
      pauseOnBackground: settings.pauseOnBackground,
      // Closing the desktop window must not leave the session running.
      onExitRequested: notifier.pauseSession,
      onBackground: () async {
        await notifier.pauseSession();
        if (settings.enableWakelock) await WakelockPlus.disable();
        if (!context.mounted) return;
        context.go('/pause');
      },
      onResume: () {},
      child: PopScope(
        canPop: false,
        // Android back gesture / browser back: end the session properly instead of leaving it running.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitToPlan();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.focusTitle),
            scrolledUnderElevation: 0.0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(tooltip: context.l10n.focusExitTooltip, onPressed: _exitToPlan, icon: const Icon(Icons.close)),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _FocusBody(
                  state: state,
                  onComplete: () async {
                    await notifier.completeCurrentTask();
                  },
                  onExit: _exitToPlan,
                ),
        ),
      ),
    );
  }
}

class _FocusBody extends ConsumerWidget {
  const _FocusBody({required this.state, required this.onComplete, required this.onExit});

  final FocusModeState state;
  final VoidCallback onComplete;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = state.currentTask;
    if (task == null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.focusNoUnfinishedTasks)),
      );
    }

    final hasTodos = task.todos.isNotEmpty;
    final totalTodos = task.todos.length;
    final completedTodos = task.todos.where((t) => t.isCompleted).length;
    final progress = hasTodos ? (completedTodos / totalTodos) : 0.0;
    final percentage = hasTodos ? (progress * 100).toInt() : 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TaskTimer(elapsed: state.currentTaskDuration, targetMinutes: task.targetDurationMinutes),
              ),
              const SizedBox(width: 12),
              Expanded(child: SessionTimer(duration: state.totalSessionDuration)),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Column(
              children: [
                // --- Progress Bar ---
                if (hasTodos) ...[
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(width: 12),
                      Text(context.l10n.commonPercent(percentage), style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // --- Task Header ---
                Text(task.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(task.description!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 24),

                if (hasTodos)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: ListView.builder(
                        itemCount: task.todos.length,
                        itemBuilder: (context, index) {
                          final todo = task.todos[index];
                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              todo.title,
                              style: TextStyle(
                                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                color: todo.isCompleted ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                              ),
                            ),
                            value: todo.isCompleted,
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(focusModeNotifierProvider.notifier).toggleTodoCompletion(todo.id!);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),

          const SizedBox(height: 16),
          FilledButton(onPressed: onComplete, child: Text(context.l10n.focusCompleteTask)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onExit, child: Text(context.l10n.focusExit)),
        ],
      ),
    );
  }
}
