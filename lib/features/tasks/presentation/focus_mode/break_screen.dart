import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/core/utils/lifecycle_observer.dart';
import 'package:focused_task/features/breaks/domain/interval_planner.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

/// The break of a work/break cycle (#27): a countdown with a hint to step away, then "Ready? Continue with …".
///
/// The break keeps running in the background (that is the point of it); only closing the app ends it.
class BreakScreen extends ConsumerStatefulWidget {
  const BreakScreen({super.key});

  @override
  ConsumerState<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends ConsumerState<BreakScreen> {
  @override
  void initState() {
    super.initState();
    // The break may already be over (auto-start after the app was suspended), or there is no cycle at all (e.g. a
    // reload on web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(focusModeNotifierProvider);
      if (!mounted || state.isOnBreak || state.isBreakOver) return;
      if (state.currentTask != null && !state.isPaused) {
        _backToFocus();
      } else {
        context.go(AppRoutes.plan);
      }
    });
  }

  Future<void> _exitToPlan() async {
    await ref.read(focusModeNotifierProvider.notifier).exitFocus();
    if (mounted) context.go(AppRoutes.plan);
  }

  void _backToFocus() {
    final request = ref.read(focusModeNotifierProvider).request;
    context.go(request == null ? AppRoutes.focus : AppRoutes.focusFor(request));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FocusModeState>(focusModeNotifierProvider, (previous, next) {
      // Work goes on (skipped, continued or auto-started): back to the task.
      bool isWorking(FocusModeState? state) => state != null && state.currentTask != null && !state.isPaused && !state.isOnBreak && !state.isBreakOver;
      if (mounted && !isWorking(previous) && isWorking(next)) _backToFocus();
    });

    final state = ref.watch(focusModeNotifierProvider);
    final notifier = ref.read(focusModeNotifierProvider.notifier);
    final l10n = context.l10n;

    return FocusLifecycleObserver(
      pauseOnBackground: false,
      onBackground: () {},
      onResume: () {},
      // Closing the desktop window must not leave the break session open.
      onExitRequested: notifier.exitFocus,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitToPlan();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(state.intervals?.phase == IntervalPhase.longBreak ? l10n.breakLongTitle : l10n.breakShortTitle),
            leading: IconButton(tooltip: l10n.focusExitTooltip, onPressed: _exitToPlan, icon: const Icon(Icons.close)),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: state.isBreakOver
                      ? _ReadyView(taskTitle: state.currentTask?.title, onContinue: notifier.continueAfterBreak, onExit: _exitToPlan)
                      : _CountdownView(remaining: state.intervals?.remaining(state.now) ?? Duration.zero, onSkip: notifier.skipBreak, onExit: _exitToPlan),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  const _CountdownView({required this.remaining, required this.onSkip, required this.onExit});

  final Duration remaining;
  final VoidCallback onSkip;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.self_improvement, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(remaining.toClockString(), key: const Key('breakCountdown'), textAlign: TextAlign.center, style: theme.textTheme.displayMedium),
        const SizedBox(height: 16),
        Text(l10n.breakHint, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 32),
        FilledButton.tonal(onPressed: onSkip, child: Text(l10n.breakSkip)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onExit, child: Text(l10n.focusExit)),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.taskTitle, required this.onContinue, required this.onExit});

  final String? taskTitle;
  final VoidCallback onContinue;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final title = taskTitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.play_circle_outline, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(l10n.breakReadyTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        if (title != null) ...[const SizedBox(height: 8), Text(l10n.breakContinueWith(title), textAlign: TextAlign.center, style: theme.textTheme.titleMedium)],
        const SizedBox(height: 32),
        FilledButton(onPressed: onContinue, child: Text(l10n.breakContinue)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onExit, child: Text(l10n.focusExit)),
      ],
    );
  }
}
