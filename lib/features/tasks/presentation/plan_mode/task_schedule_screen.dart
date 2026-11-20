import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/reminders/domain/reminder_scheduler.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/schedule_labels.dart';

/// What the schedule sub-page edits, with the parts of the task the reminder preview needs.
class TaskScheduleRequest {
  const TaskScheduleRequest({required this.schedule, required this.day, this.targetMinutes, this.timeSpent = Duration.zero});

  final TaskSchedule schedule;

  /// The task's day in the form (the start time is on it).
  final DateTime day;
  final int? targetMinutes;
  final Duration timeSpent;
}

/// Sub-page of the task form (#10): start time, deadline and reminder. Going back returns the edited schedule to the
/// form, which saves it with the task.
class TaskScheduleScreen extends ConsumerStatefulWidget {
  const TaskScheduleScreen({super.key, required this.request});

  final TaskScheduleRequest request;

  @override
  ConsumerState<TaskScheduleScreen> createState() => _TaskScheduleScreenState();
}

class _TaskScheduleScreenState extends ConsumerState<TaskScheduleScreen> {
  late TaskSchedule _schedule = widget.request.schedule;

  void _update(TaskSchedule schedule) => setState(() => _schedule = schedule);

  Future<int?> _pickTime(int initialMinute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialMinute ~/ 60, minute: initialMinute % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _pickStart() async {
    final minute = await _pickTime(_schedule.startMinute ?? 9 * 60);
    if (minute != null) _update(_schedule.copyWith(startMinute: minute));
  }

  Future<void> _pickDueDate() async {
    final today = clock.now();
    final initial = _schedule.dueDate ?? widget.request.day;
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: initial.isBefore(DateTime(2020)) ? today : initial);
    if (picked != null) _update(_schedule.copyWith(dueDate: picked));
  }

  Future<void> _pickDueTime(int defaultMinute) async {
    final minute = await _pickTime(_schedule.dueMinute ?? defaultMinute);
    if (minute != null) _update(_schedule.copyWith(dueMinute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(reminderSettingsProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = _schedule.startMinute;
    final dueDate = _schedule.dueDate;
    final dueMinute = _schedule.dueMinute;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_schedule);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.taskScheduleTitle)),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _ValueTile(
              key: const Key('scheduleStart'),
              icon: Icons.schedule,
              title: l10n.taskScheduleStartTime,
              subtitle: l10n.taskScheduleStartHint(DateFormat.MMMEd(locale).format(widget.request.day)),
              value: start == null ? l10n.taskScheduleNone : timeOfDayLabel(context, start),
              onTap: _pickStart,
              onClear: start == null ? null : () => _update(_schedule.copyWith(clearStart: true)),
            ),
            _ValueTile(
              key: const Key('scheduleDueDate'),
              icon: Icons.flag_outlined,
              title: l10n.taskScheduleDueDate,
              value: dueDate == null ? l10n.taskScheduleNone : DateFormat.yMMMEd(locale).format(dueDate),
              onTap: _pickDueDate,
              onClear: dueDate == null ? null : () => _update(_schedule.copyWith(clearDue: true)),
            ),
            if (dueDate != null)
              _ValueTile(
                key: const Key('scheduleDueTime'),
                icon: Icons.access_time,
                title: l10n.taskScheduleDueTime,
                value: dueMinute == null ? l10n.taskScheduleDueTimeDefault(timeOfDayLabel(context, settings.defaultDueMinute)) : timeOfDayLabel(context, dueMinute),
                onTap: () => _pickDueTime(settings.defaultDueMinute),
                onClear: dueMinute == null ? null : () => _update(_schedule.copyWith(clearDueMinute: true)),
              ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.taskScheduleReminder, style: textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReminderChoice(schedule: _schedule, settings: settings, onChanged: _update),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReminderPreview(request: widget.request, schedule: _schedule, settings: settings),
            ),
          ],
        ),
      ),
    );
  }
}

/// A value that opens a picker on tap, with a button to remove it.
class _ValueTile extends StatelessWidget {
  const _ValueTile({super.key, required this.icon, required this.title, this.subtitle, required this.value, required this.onTap, this.onClear});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle == null ? value : '$value\n$subtitle'),
      isThreeLine: subtitle != null,
      onTap: onTap,
      trailing: onClear == null ? const Icon(Icons.chevron_right) : IconButton(tooltip: context.l10n.taskScheduleClear, icon: const Icon(Icons.close), onPressed: onClear),
    );
  }
}

/// Default lead time, one of the presets, or off.
class _ReminderChoice extends StatelessWidget {
  const _ReminderChoice({required this.schedule, required this.settings, required this.onChanged});

  final TaskSchedule schedule;
  final ReminderSettings settings;
  final ValueChanged<TaskSchedule> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = schedule.reminderMinutes;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const Key('scheduleReminder-default'),
          label: Text(l10n.taskScheduleReminderDefault(l10n.durationLabel(settings.defaultLead))),
          selected: !schedule.reminderOff && custom == null,
          onSelected: (_) => onChanged(schedule.copyWith(clearReminderMinutes: true, reminderOff: false)),
        ),
        for (final minutes in {...ReminderSettings.leadOptions, ?custom}.toList()..sort())
          ChoiceChip(
            key: Key('scheduleReminder-$minutes'),
            label: Text(l10n.durationLabel(Duration(minutes: minutes))),
            selected: !schedule.reminderOff && custom == minutes,
            onSelected: (_) => onChanged(schedule.copyWith(reminderMinutes: minutes, reminderOff: false)),
          ),
        ChoiceChip(
          key: const Key('scheduleReminder-off'),
          label: Text(l10n.taskScheduleReminderOffOption),
          selected: schedule.reminderOff,
          onSelected: (_) => onChanged(schedule.copyWith(reminderOff: true)),
        ),
      ],
    );
  }
}

/// When the reminder will come, computed with the same rules as the real one.
class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({required this.request, required this.schedule, required this.settings});

  final TaskScheduleRequest request;
  final TaskSchedule schedule;
  final ReminderSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final now = clock.now();
    final task = TaskEntity(
      id: 0,
      title: '',
      description: null,
      assignedDate: request.day,
      sortOrder: '',
      isCompleted: false,
      priority: TaskPriority.low,
      timeSpent: request.timeSpent.inMilliseconds,
      latestStart: null,
      targetDurationMinutes: request.targetMinutes,
      todos: const [],
      schedule: schedule,
    );
    final time = const ReminderScheduler().reminderFor(task, settings);
    final lines = <String>[
      if (!settings.taskReminders)
        l10n.taskScheduleRemindersDisabled
      else if (schedule.reminderOff)
        l10n.taskScheduleReminderOff
      else if (time == null)
        l10n.taskScheduleReminderNeedsTime
      else ...[
        l10n.taskScheduleReminderAt(momentLabel(context, time.at, now: now)),
        if (!time.at.isAfter(now) && time.anchor.isAfter(now)) l10n.taskScheduleReminderNow,
        if (time.kind == TaskReminderKind.due) l10n.taskScheduleReminderDueHint,
      ],
    ];
    return Card(
      key: const Key('schedulePreview'),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(time == null || schedule.reminderOff || !settings.taskReminders ? Icons.notifications_off_outlined : Icons.notifications_outlined),
        title: Text(lines.first),
        subtitle: lines.length > 1 ? Text(lines.skip(1).join('\n')) : null,
      ),
    );
  }
}
