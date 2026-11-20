import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/schedule_labels.dart';

/// Settings sub-page "Reminders & dates" (#10): task reminders, daily planning, inactivity and the notification checks.
class RemindersSettingsScreen extends ConsumerWidget {
  const RemindersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final reminders = ref.watch(reminderSettingsProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    void update(ReminderSettings value) => notifier.setReminders(value);
    String minutes(int value) => l10n.durationLabel(Duration(minutes: value));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReminders)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: const Key('settingsTaskReminders'),
            title: Text(l10n.settingsTaskReminders, style: textTheme.titleMedium),
            subtitle: Text(l10n.settingsTaskRemindersHint),
            value: reminders.taskReminders,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => update(reminders.copyWith(taskReminders: value)),
          ),
          if (reminders.taskReminders)
            _MinutesOption(
              key: const Key('settingsDefaultLead'),
              title: l10n.settingsDefaultLead,
              value: reminders.defaultLead.inMinutes,
              options: ReminderSettings.leadOptions,
              label: (value) => l10n.taskScheduleReminderBefore(minutes(value)),
              onChanged: (value) => update(reminders.copyWith(defaultLead: Duration(minutes: value))),
            ),
          _TimeOption(
            key: const Key('settingsDefaultDueTime'),
            title: l10n.settingsDefaultDueTime,
            subtitle: l10n.settingsDefaultDueTimeHint,
            minute: reminders.defaultDueMinute,
            onChanged: (value) => update(reminders.copyWith(defaultDueMinute: value)),
          ),
          const Divider(height: 32),
          SwitchListTile(
            key: const Key('settingsDailyPlanning'),
            title: Text(l10n.settingsDailyPlanning, style: textTheme.titleMedium),
            subtitle: Text(l10n.settingsDailyPlanningHint),
            value: reminders.dailyPlanning,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => update(reminders.copyWith(dailyPlanning: value)),
          ),
          if (reminders.dailyPlanning)
            _TimeOption(
              key: const Key('settingsDailyPlanningTime'),
              title: l10n.settingsReminderTime,
              minute: reminders.dailyPlanningMinute,
              onChanged: (value) => update(reminders.copyWith(dailyPlanningMinute: value)),
            ),
          const Divider(height: 32),
          SwitchListTile(
            key: const Key('settingsInactivity'),
            title: Text(l10n.settingsInactivity, style: textTheme.titleMedium),
            subtitle: Text(l10n.settingsInactivityHint),
            value: reminders.inactivity,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => update(reminders.copyWith(inactivity: value)),
          ),
          if (reminders.inactivity) ...[
            _TimeOption(
              key: const Key('settingsWorkStart'),
              title: l10n.settingsWorkStart,
              minute: reminders.workStartMinute,
              onChanged: (value) => update(reminders.copyWith(workStartMinute: value)),
            ),
            _TimeOption(
              key: const Key('settingsWorkEnd'),
              title: l10n.settingsWorkEnd,
              minute: reminders.workEndMinute,
              onChanged: (value) => update(reminders.copyWith(workEndMinute: value)),
            ),
            _MinutesOption(
              key: const Key('settingsIdleTime'),
              title: l10n.settingsIdleTime,
              value: reminders.idle.inMinutes,
              options: ReminderSettings.idleOptions,
              label: minutes,
              onChanged: (value) => update(reminders.copyWith(idle: Duration(minutes: value))),
            ),
          ],
          if (reminders.dailyPlanning || reminders.inactivity) Text(l10n.settingsWorkingDaysFromGoals, style: textTheme.bodySmall),
          const Divider(height: 32),
          const _NotificationsSection(),
        ],
      ),
    );
  }
}

/// A time of day; tap to change it.
class _TimeOption extends StatelessWidget {
  const _TimeOption({super.key, required this.title, this.subtitle, required this.minute, required this.onChanged});

  final String title;
  final String? subtitle;
  final int minute;
  final ValueChanged<int> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: TextButton(onPressed: () => _pick(context), child: Text(timeOfDayLabel(context, minute))),
      onTap: () => _pick(context),
    );
  }
}

/// A number of minutes picked from [options].
class _MinutesOption extends StatelessWidget {
  const _MinutesOption({super.key, required this.title, required this.value, required this.options, required this.label, required this.onChanged});

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
          for (final option in {...options, value}.toList()..sort()) DropdownMenuItem(value: option, child: Text(label(option))),
        ],
      ),
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
