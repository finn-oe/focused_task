import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.settings_suggest),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (selection) async {
                    final selectedMode = selection.first;
                    await notifier.setThemeMode(selectedMode);
                  },
                ),
                const SizedBox(height: 24),
                Text('Data Retention', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Automatically delete completed tasks older than the selected number of days.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Retention period: ${state.retentionDays} days',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Decrease',
                      onPressed: state.retentionDays <= 1
                          ? null
                          : () => notifier.setRetentionDays(state.retentionDays - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Increase',
                      onPressed: () => notifier.setRetentionDays(state.retentionDays + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isCleaning
                      ? null
                      : () async {
                          await notifier.cleanNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref
                                          .read(settingsNotifierProvider)
                                          .lastCleanupMessage ??
                                      'Cleanup complete.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: state.isCleaning
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services),
                  label: const Text('Clean now'),
                ),
                if (state.lastCleanupMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.lastCleanupMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
    );
  }
}
