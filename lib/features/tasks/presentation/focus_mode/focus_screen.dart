import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:just_audio/just_audio.dart';

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

      // Check setting and apply Wakelock
      final settings = ref.read(settingsNotifierProvider);
      if (settings.enableWakelock) {
        WakelockPlus.enable();
      }
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _showAlarmDialog() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/alarm.mp3');
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio playback failed: $e');
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Time is up!'),
          content: const Text('You have reached your target duration for this task.'),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Stop Alarm & Continue'))],
        );
      },
    );

    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }

    ref.read(focusModeNotifierProvider.notifier).dismissAlarm();
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
    final settings = ref.watch(settingsNotifierProvider); // Watch settings for lifecycle pref

    return FocusLifecycleObserver(
      pauseOnInactive: settings.pauseOnInactive,
      onBackground: () async {
        await notifier.pauseSession();
        if (!context.mounted) return;

        // If wakelock was enabled, disable it while paused
        if (settings.enableWakelock) WakelockPlus.disable();

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
              Expanded(
                child: TaskTimer(elapsed: state.currentTaskDuration, targetMinutes: task.targetDurationMinutes),
              ),
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
