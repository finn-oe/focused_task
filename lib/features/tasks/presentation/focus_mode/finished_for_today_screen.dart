import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FinishedForTodayScreen extends StatelessWidget {
  const FinishedForTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Done'),
        leading: IconButton(onPressed: () => context.go('/plan'), icon: const Icon(Icons.close)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Finished for Today!', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Great work — you completed everything planned for today.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  router.go('/plan');
                  router.push('/stats');
                },
                icon: const Icon(Icons.insights_outlined),
                label: const Text('View Statistics'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => context.go('/plan'), icon: const Icon(Icons.assignment_outlined), label: const Text('Back to Plan')),
            ],
          ),
        ),
      ),
    );
  }
}
