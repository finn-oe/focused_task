import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/settings/presentation/settings_state.dart';

/// Language options; `null` follows the system language.
enum _Language {
  system(null),
  english(Locale('en')),
  german(Locale('de'));

  const _Language(this.locale);

  final Locale? locale;

  static _Language of(Locale? locale) => values.firstWhere((language) => language.locale == locale, orElse: () => system);
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final lastCleanup = state.lastCleanup;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settingsAppearance, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.settingsThemeSystem), icon: const Icon(Icons.settings_suggest)),
              ButtonSegment(value: ThemeMode.light, label: Text(l10n.settingsThemeLight), icon: const Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.settingsThemeDark), icon: const Icon(Icons.dark_mode)),
            ],
            selected: {state.themeMode},
            onSelectionChanged: (selection) => notifier.setThemeMode(selection.first),
          ),
          const SizedBox(height: 16),
          Text(l10n.settingsLanguage, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<_Language>(
            segments: [
              ButtonSegment(value: _Language.system, label: Text(l10n.settingsLanguageSystem), icon: const Icon(Icons.translate)),
              ButtonSegment(value: _Language.english, label: Text(l10n.settingsLanguageEnglish)),
              ButtonSegment(value: _Language.german, label: Text(l10n.settingsLanguageGerman)),
            ],
            selected: {_Language.of(state.locale)},
            onSelectionChanged: (selection) => notifier.setLocale(selection.first.locale),
          ),
          const SizedBox(height: 24),
          Text(l10n.settingsDataRetention, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.settingsDataRetentionInfo, style: textTheme.bodyMedium),
          SwitchListTile(
            title: Text(l10n.settingsAutoCleanup),
            subtitle: Text(l10n.settingsAutoCleanupHint(state.retentionDays)),
            value: state.autoCleanupEnabled,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setAutoCleanupEnabled,
          ),
          Row(
            children: [
              Expanded(child: Text(l10n.settingsRetentionPeriod(state.retentionDays), style: textTheme.titleMedium)),
              IconButton(
                tooltip: l10n.settingsDecrease,
                onPressed: state.retentionDays <= 1 ? null : () => notifier.setRetentionDays(state.retentionDays - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(tooltip: l10n.settingsIncrease, onPressed: () => notifier.setRetentionDays(state.retentionDays + 1), icon: const Icon(Icons.add_circle_outline)),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsNothingToClean(state.retentionDays))));
                      return;
                    }
                    final confirmed = await _confirmCleanup(context, count: count, days: state.retentionDays);
                    if (!confirmed) return;
                    await notifier.cleanNow();
                    final result = ref.read(settingsNotifierProvider).lastCleanup;
                    if (context.mounted && result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanupMessage(l10n, result))));
                    }
                  },
            icon: state.isCleaning ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cleaning_services),
            label: Text(l10n.settingsCleanNow),
          ),
          if (lastCleanup != null) ...[const SizedBox(height: 12), Text(_cleanupMessage(l10n, lastCleanup), style: textTheme.bodyMedium)],
          const SizedBox(height: 24),
          Text(l10n.settingsFocusMode, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l10n.settingsKeepScreenAwake),
            subtitle: Text(l10n.settingsKeepScreenAwakeHint),
            value: state.enableWakelock,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setEnableWakelock,
          ),
          SwitchListTile(
            title: Text(l10n.settingsPauseOnBackground),
            subtitle: Text(l10n.settingsPauseOnBackgroundHint),
            value: state.pauseOnBackground,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setPauseOnBackground,
          ),
        ],
      ),
    );
  }
}

String _cleanupMessage(AppLocalizations l10n, CleanupResult result) {
  final deleted = result.deletedCount;
  return deleted == null ? l10n.settingsCleanupFailed : l10n.settingsCleanupDeleted(deleted);
}

Future<bool> _confirmCleanup(BuildContext context, {required int count, required int days}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingsCleanupConfirmTitle),
      content: Text(l10n.settingsCleanupConfirmMessage(count, days)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonDelete)),
      ],
    ),
  );
  return confirmed ?? false;
}
