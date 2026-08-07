import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';

class PauseScreen extends ConsumerWidget {
  const PauseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(focusModeNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Paused')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Focus paused while app is in background.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await notifier.resumeSession();
                  if (context.mounted) {
                    context.go('/focus');
                  }
                },
                child: const Text('Resume Focus'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await notifier.exitFocus();
                  if (context.mounted) {
                    context.go('/plan');
                  }
                },
                child: const Text('Exit Focus'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
