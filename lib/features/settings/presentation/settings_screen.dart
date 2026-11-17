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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
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
          Text('Deleted tasks are removed from your statistics as well. Tasks with an unfinished session are never deleted.', style: Theme.of(context).textTheme.bodyMedium),
          SwitchListTile(
            title: const Text('Delete old completed tasks automatically'),
            subtitle: Text('On every app start, completed tasks older than ${state.retentionDays} days are deleted.'),
            value: state.autoCleanupEnabled,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setAutoCleanupEnabled,
          ),
          Row(
            children: [
              Expanded(child: Text('Retention period: ${state.retentionDays} days', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                tooltip: 'Decrease',
                onPressed: state.retentionDays <= 1 ? null : () => notifier.setRetentionDays(state.retentionDays - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(tooltip: 'Increase', onPressed: () => notifier.setRetentionDays(state.retentionDays + 1), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.isCleaning
                ? null
                : () async {
                    final count = await notifier.countCleanupCandidates();
                    if (!context.mounted) return;
                    if (count == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No completed tasks older than ${state.retentionDays} days.')));
                      return;
                    }
                    final confirmed = await _confirmCleanup(context, count: count, days: state.retentionDays);
                    if (!confirmed) return;
                    await notifier.cleanNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(settingsNotifierProvider).lastCleanupMessage ?? 'Cleanup complete.')));
                    }
                  },
            icon: state.isCleaning ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cleaning_services),
            label: const Text('Clean now'),
          ),
          if (state.lastCleanupMessage != null) ...[const SizedBox(height: 12), Text(state.lastCleanupMessage!, style: Theme.of(context).textTheme.bodyMedium)],
          const SizedBox(height: 24),
          Text('Focus Mode', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text('Keep screen awake'),
            subtitle: const Text('Prevents the screen from turning off during an active focus session.'),
            value: state.enableWakelock,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setEnableWakelock,
          ),
          SwitchListTile(
            title: const Text('Pause when minimized or locked'),
            subtitle: const Text('Pauses the session if the app is sent to the background or the screen turns off.'),
            value: state.pauseOnBackground,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setPauseOnBackground,
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmCleanup(BuildContext context, {required int count, required int days}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete old tasks?'),
      content: Text('$count completed task(s) older than $days days will be deleted permanently, including their tracked time in the statistics.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  return confirmed ?? false;
}
