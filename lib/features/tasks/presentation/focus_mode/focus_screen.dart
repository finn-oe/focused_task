import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/keyboard.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/core/utils/lifecycle_observer.dart';
import 'package:focused_task/features/breaks/domain/interval_planner.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/widgets/timer_box.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, required this.request});

  final FocusRequest request;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(focusModeNotifierProvider.notifier).start(widget.request);

      final settings = ref.read(settingsNotifierProvider);
      if (settings.enableWakelock) {
        WakelockPlus.enable();
      }
      // Focus mode is the first feature that needs notifications (target alarm), so ask here, once.
      ref.read(settingsNotifierProvider.notifier).ensureNotificationPermission();
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
    // "Parked for later" and the like belong to focus; they must not cover the plan.
    ScaffoldMessenger.of(context).clearSnackBars();
    context.go(AppRoutes.plan);
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
        context.go(AppRoutes.finishedForToday);
      }
      if (previous?.shouldShowAlarm != true && next.shouldShowAlarm) {
        _showAlarmDialog();
      }
      if (previous?.isOnBreak != true && next.isOnBreak) {
        context.go(AppRoutes.breakTime);
      }
      showWelcomeBack(context, ref, next);
    });

    final state = ref.watch(focusModeNotifierProvider);
    final notifier = ref.read(focusModeNotifierProvider.notifier);
    final settings = ref.watch(settingsNotifierProvider);
    final category = ref.watch(categoriesNotifierProvider.select((categories) => categories.byId(widget.request.categoryId)));
    final minimal = settings.focusMinimalLayout;

    return FocusLifecycleObserver(
      pauseOnBackground: settings.pauseOnBackground,
      // Closing the desktop window must not leave the session running.
      onExitRequested: () => notifier.pauseSession(reason: EndReason.exited),
      onBackground: () async {
        await notifier.pauseSession(reason: EndReason.background);
        if (settings.enableWakelock) await WakelockPlus.disable();
        if (!context.mounted) return;
        context.go(AppRoutes.pause);
      },
      onResume: () {},
      onLeave: notifier.appLeft,
      onReturn: notifier.appReturned,
      child: PopScope(
        canPop: false,
        // Android back gesture / browser back: end the session properly instead of leaving it running.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitToPlan();
        },
        child: Scaffold(
          appBar: minimal
              ? null
              : AppBar(
                  title: Text(category == null ? context.l10n.focusTitle : context.l10n.focusTitleCategory(category.name)),
                  scrolledUnderElevation: 0.0,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  leading: IconButton(tooltip: context.l10n.focusExitTooltip, onPressed: _exitToPlan, icon: const Icon(Icons.close)),
                  actions: [
                    if (state.currentTask != null) const _DistractedButton(),
                    IconButton(
                      tooltip: context.l10n.focusMinimalLayout,
                      onPressed: () => ref.read(settingsNotifierProvider.notifier).setFocusMinimalLayout(true),
                      icon: const Icon(Icons.fullscreen),
                    ),
                  ],
                ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : minimal
              ? _MinimalFocusBody(state: state, onComplete: notifier.completeCurrentTask)
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
          if (state.intervals case final intervals? when intervals.phase == IntervalPhase.work) ...[
            const SizedBox(height: 8),
            _BreakCountdown(remaining: intervals.remaining(state.now)),
          ],
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
                const _QuickSubTaskField(),
                const SizedBox(height: 8),
                const _ParkThoughtField(),
              ],
            ),
          ),

          if (state.upNext case final next?) ...[const SizedBox(height: 12), _UpNextCard(task: next)],
          const SizedBox(height: 16),
          Row(
            children: [
              if (state.upNext != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(focusModeNotifierProvider.notifier).skipCurrentTask(),
                    icon: const Icon(Icons.skip_next),
                    label: Text(context.l10n.focusSkip),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(onPressed: onComplete, child: Text(context.l10n.focusCompleteTask)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onExit, child: Text(context.l10n.focusExit)),
        ],
      ),
    );
  }
}

/// "You were away 4 min." after returning to a running session; the focus and the pause screen both show it.
void showWelcomeBack(BuildContext context, WidgetRef ref, FocusModeState state) {
  final away = state.awayFor;
  if (away == null) return;
  ref.read(focusModeNotifierProvider.notifier).clearAwayFor();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.focusAwayFor(context.l10n.durationLabel(away)))));
}

/// "I got distracted": counts an interruption and nudges back to the task.
class _DistractedButton extends ConsumerWidget {
  const _DistractedButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.focusDistracted,
      icon: const Icon(Icons.psychology_alt_outlined),
      onPressed: () async {
        final task = ref.read(focusModeNotifierProvider).currentTask;
        await ref.read(focusModeNotifierProvider.notifier).recordDistraction();
        if (!context.mounted || task == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.focusDistractedNoted(task.title))));
      },
    );
  }
}

/// Minimal layout: a large timer, the task title, the main button and the thought inbox – nothing else.
class _MinimalFocusBody extends ConsumerWidget {
  const _MinimalFocusBody({required this.state, required this.onComplete});

  final FocusModeState state;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final task = state.currentTask;
    final target = task?.targetDurationMinutes;
    final elapsed = state.currentTaskDuration;
    final remaining = target == null ? null : Duration(minutes: target) - elapsed;
    final overdue = remaining != null && remaining.isNegative;
    final timer = remaining == null ? elapsed.toClockString() : (overdue ? '+${remaining.toClockString()}' : remaining.toClockString());

    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timer,
                        key: const Key('focusMinimalTimer'),
                        style: theme.textTheme.displayLarge?.copyWith(color: overdue ? theme.colorScheme.error : null),
                      ),
                    ),
                    if (state.intervals case final intervals? when intervals.phase == IntervalPhase.work) ...[
                      const SizedBox(height: 8),
                      _BreakCountdown(remaining: intervals.remaining(state.now)),
                    ],
                    const SizedBox(height: 24),
                    Text(task?.title ?? l10n.focusNoUnfinishedTasks, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                    if (task != null) ...[
                      const SizedBox(height: 32),
                      FilledButton(onPressed: onComplete, child: Text(l10n.focusCompleteTask)),
                      const SizedBox(height: 16),
                      const _ParkThoughtField(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: l10n.focusFullLayout,
              onPressed: () => ref.read(settingsNotifierProvider.notifier).setFocusMinimalLayout(false),
              icon: const Icon(Icons.fullscreen_exit),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parks a thought in the distraction inbox; Enter saves, the field clears and keeps the focus.
class _ParkThoughtField extends ConsumerStatefulWidget {
  const _ParkThoughtField();

  @override
  ConsumerState<_ParkThoughtField> createState() => _ParkThoughtFieldState();
}

class _ParkThoughtFieldState extends ConsumerState<_ParkThoughtField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _park() async {
    final text = _controller.text;
    _controller.clear();
    _focus.requestFocus();
    if (text.trim().isEmpty) return;
    final l10n = context.l10n;
    await ref.read(focusModeNotifierProvider.notifier).parkThought(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.focusThoughtParked), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onTapOutside: unfocusOnTapOutside,
      key: const Key('focusParkThought'),
      controller: _controller,
      focusNode: _focus,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(hintText: context.l10n.focusParkThought, prefixIcon: const Icon(Icons.lightbulb_outline), isDense: true),
      onEditingComplete: _park,
    );
  }
}

/// Time left in the work interval until the next break.
class _BreakCountdown extends StatelessWidget {
  const _BreakCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.self_improvement, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          context.l10n.focusBreakIn(remaining.toClockString()),
          key: const Key('focusBreakIn'),
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "Up next": the next task in the queue.
class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.queue_play_next),
        title: Text(context.l10n.focusUpNext, style: theme.textTheme.labelMedium),
        subtitle: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

/// Adds a sub-task to the current task without leaving focus.
class _QuickSubTaskField extends ConsumerStatefulWidget {
  const _QuickSubTaskField();

  @override
  ConsumerState<_QuickSubTaskField> createState() => _QuickSubTaskFieldState();
}

class _QuickSubTaskFieldState extends ConsumerState<_QuickSubTaskField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text;
    _controller.clear();
    _focus.requestFocus();
    await ref.read(focusModeNotifierProvider.notifier).addSubTask(title);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onTapOutside: unfocusOnTapOutside,
      controller: _controller,
      focusNode: _focus,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(hintText: context.l10n.taskFormNewSubTask, prefixIcon: const Icon(Icons.add), isDense: true),
      onEditingComplete: _add,
    );
  }
}
