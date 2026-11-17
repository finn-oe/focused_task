import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';

class PauseScreen extends ConsumerWidget {
  const PauseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(focusModeNotifierProvider.notifier);

    Future<void> exitToPlan() async {
      await notifier.exitFocus();
      if (context.mounted) context.go('/plan');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exitToPlan();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.pauseTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.pauseMessage, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await notifier.resumeSession();
                    final request = ref.read(focusModeNotifierProvider).request;
                    if (context.mounted) {
                      context.go(request == null ? AppRoutes.focus : AppRoutes.focusFor(request));
                    }
                  },
                  child: Text(context.l10n.pauseResume),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: exitToPlan, child: Text(context.l10n.focusExit)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
