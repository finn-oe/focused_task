import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
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
          Text(l10n.settingsPlanning, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l10n.settingsAskToMoveUnfinished),
            subtitle: Text(l10n.settingsAskToMoveUnfinishedHint),
            value: state.askToMoveUnfinished,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setAskToMoveUnfinished,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.label_outline),
            title: Text(l10n.settingsCategories),
            subtitle: Text(l10n.settingsCategoriesHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.categories),
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
          SwitchListTile(
            title: Text(l10n.settingsMinimalFocusLayout),
            subtitle: Text(l10n.settingsMinimalFocusLayoutHint),
            value: state.focusMinimalLayout,
            contentPadding: EdgeInsets.zero,
            onChanged: notifier.setFocusMinimalLayout,
          ),
          const _IntervalsSection(),
          const SizedBox(height: 24),
          const _GoalsSection(),
          const SizedBox(height: 24),
          const _NotificationsSection(),
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

/// Pomodoro-style work/break cycles: on/off, the lengths and auto-start.
class _IntervalsSection extends ConsumerWidget {
  const _IntervalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final intervals = ref.watch(settingsNotifierProvider.select((settings) => settings.intervals));
    final notifier = ref.read(settingsNotifierProvider.notifier);
    String minutes(int value) => l10n.durationLabel(Duration(minutes: value));

    return Column(
      children: [
        SwitchListTile(
          key: const Key('settingsIntervals'),
          title: Text(l10n.settingsIntervals),
          subtitle: Text(l10n.settingsIntervalsHint),
          value: intervals.isEnabled,
          contentPadding: EdgeInsets.zero,
          onChanged: (enabled) => notifier.setIntervals(intervals.copyWith(isEnabled: enabled)),
        ),
        if (intervals.isEnabled) ...[
          _IntervalOption(
            title: l10n.settingsIntervalWork,
            value: intervals.work.inMinutes,
            options: IntervalSettings.workOptions,
            label: minutes,
            onChanged: (value) => notifier.setIntervals(intervals.copyWith(work: Duration(minutes: value))),
          ),
          _IntervalOption(
            title: l10n.settingsIntervalShortBreak,
            value: intervals.shortBreak.inMinutes,
            options: IntervalSettings.shortBreakOptions,
            label: minutes,
            onChanged: (value) => notifier.setIntervals(intervals.copyWith(shortBreak: Duration(minutes: value))),
          ),
          _IntervalOption(
            title: l10n.settingsIntervalLongBreak,
            value: intervals.longBreak.inMinutes,
            options: IntervalSettings.longBreakOptions,
            label: minutes,
            onChanged: (value) => notifier.setIntervals(intervals.copyWith(longBreak: Duration(minutes: value))),
          ),
          _IntervalOption(
            title: l10n.settingsIntervalLongBreakEvery,
            value: intervals.longBreakEvery,
            options: IntervalSettings.longBreakEveryOptions,
            label: l10n.settingsIntervalCount,
            onChanged: (value) => notifier.setIntervals(intervals.copyWith(longBreakEvery: value)),
          ),
          SwitchListTile(
            title: Text(l10n.settingsIntervalAutoStart),
            subtitle: Text(l10n.settingsIntervalAutoStartHint),
            value: intervals.autoStart,
            contentPadding: EdgeInsets.zero,
            onChanged: (autoStart) => notifier.setIntervals(intervals.copyWith(autoStart: autoStart)),
          ),
        ],
      ],
    );
  }
}

/// One length of the work/break cycle, picked from [options].
class _IntervalOption extends StatelessWidget {
  const _IntervalOption({required this.title, required this.value, required this.options, required this.label, required this.onChanged});

  final String title;
  final int value;
  final List<int> options;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value,
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        items: [
          // A value stored by an older version that isn't an option any more stays selectable.
          for (final option in {...options, value}.toList()..sort()) DropdownMenuItem(value: option, child: Text(label(option))),
        ],
      ),
    );
  }
}

/// Daily focus goal (off / 30 min … 8 h) and the working days it applies to.
class _GoalsSection extends ConsumerWidget {
  const _GoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final goal = ref.watch(settingsNotifierProvider.select((settings) => settings.focusGoal));
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final firstWeekday = firstDayOfWeek(context);
    final weekdays = [for (var offset = 0; offset < DateTime.daysPerWeek; offset++) (firstWeekday - 1 + offset) % DateTime.daysPerWeek + 1];
    // 2024-01-01 was a Monday: any week gives the localized weekday names.
    String weekdayName(int weekday) => DateFormat.E(locale).format(DateTime(2024, 1, weekday));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsGoals, style: textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsDailyGoal),
          subtitle: Text(l10n.settingsDailyGoalHint),
          trailing: DropdownButton<int>(
            key: const Key('settingsDailyGoal'),
            value: goal.daily?.inMinutes ?? 0,
            onChanged: (minutes) => notifier.setDailyGoal(minutes == null || minutes == 0 ? null : Duration(minutes: minutes)),
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.settingsGoalOff)),
              // A goal stored by an older version that isn't an option any more stays selectable.
              for (final minutes in {...FocusGoal.options, ?goal.daily?.inMinutes}.toList()..sort())
                DropdownMenuItem(
                  value: minutes,
                  child: Text(l10n.durationLabel(Duration(minutes: minutes))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.settingsWorkingDays, style: textTheme.titleMedium),
        Text(l10n.settingsWorkingDaysHint, style: textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final weekday in weekdays)
              FilterChip(
                label: Text(weekdayName(weekday)),
                selected: goal.workingDays.contains(weekday),
                // The last working day can't be removed.
                onSelected: goal.workingDays.length == 1 && goal.workingDays.contains(weekday) ? null : (selected) => notifier.setWorkingDay(weekday, selected),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hint when notifications were refused, and a test notification to check they arrive.
class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final denied = ref.watch(settingsNotifierProvider.select((settings) => settings.notificationsDenied));
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsNotifications, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (denied)
          Card(
            elevation: 0,
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: theme.colorScheme.onErrorContainer),
              title: Text(l10n.settingsNotificationsDenied, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              trailing: TextButton(onPressed: notifier.requestNotificationPermission, child: Text(l10n.settingsNotificationsAskAgain)),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsNotificationsTest),
          subtitle: Text(l10n.settingsNotificationsTestHint),
          trailing: OutlinedButton(
            onPressed: () async {
              await notifier.sendTestNotification();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsNotificationsTestScheduled)));
            },
            child: Text(l10n.settingsNotificationsTestButton),
          ),
        ),
      ],
    );
  }
}
