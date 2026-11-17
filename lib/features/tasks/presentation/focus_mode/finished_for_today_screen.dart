import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/routing/app_router.dart';

class FinishedForTodayScreen extends StatelessWidget {
  const FinishedForTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.finishedTitle),
        leading: IconButton(onPressed: () => context.go(AppRoutes.plan), icon: const Icon(Icons.close)),
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
              Text(l10n.finishedHeadline, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(l10n.finishedMessage, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton.icon(onPressed: () => context.go(AppRoutes.stats), icon: const Icon(Icons.insights_outlined), label: Text(l10n.finishedViewStatistics)),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => context.go(AppRoutes.plan), icon: const Icon(Icons.assignment_outlined), label: Text(l10n.finishedBackToPlan)),
            ],
          ),
        ),
      ),
    );
  }
}
