import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/lifecycle_observer.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/widgets/session_timer.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/widgets/task_timer.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusModeNotifierProvider);
    final notifier = ref.read(focusModeNotifierProvider.notifier);

    return FocusLifecycleObserver(
      onPause: () async {
        await notifier.pauseSession();
        if (!context.mounted) return;
        context.go('/pause');
      },
      onResume: () {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Focus Mode'),
          leading: IconButton(
            onPressed: () async {
              await notifier.exitFocus();
              if (!context.mounted) return;
              context.go('/plan');
            },
            icon: const Icon(Icons.close),
          ),
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _FocusBody(
                state: state,
                onComplete: () async {
                  await notifier.completeCurrentTask();
                  final latest = ref.read(focusModeNotifierProvider);
                  if (!context.mounted) return;
                  if (latest.currentTask == null) {
                    context.go('/plan');
                  }
                },
                onExit: () async {
                  await notifier.exitFocus();
                  if (!context.mounted) return;
                  context.go('/plan');
                },
              ),
      ),
    );
  }
}

class _FocusBody extends StatelessWidget {
  const _FocusBody({required this.state, required this.onComplete, required this.onExit});

  final FocusModeState state;
  final VoidCallback onComplete;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final task = state.currentTask;
    if (task == null) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('No unfinished tasks for today.')),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: TaskTimer(duration: state.currentTaskDuration)),
              const SizedBox(width: 12),
              Expanded(child: SessionTimer(duration: state.totalSessionDuration)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(task.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  Text(task.description ?? 'No description', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          FilledButton(onPressed: onComplete, child: const Text('Complete Task')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onExit, child: const Text('Exit Focus')),
        ],
      ),
    );
  }
}
