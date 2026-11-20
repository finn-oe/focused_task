import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/features/recurrence/domain/repeat_pattern.dart';
import 'package:focused_task/features/recurrence/presentation/repeat_labels.dart';

/// What the repeat sub-page edits.
class TaskRepeatRequest {
  const TaskRepeatRequest({required this.repeat, required this.day, this.isOccurrence = false});

  /// `null` = the task doesn't repeat.
  final RepeatPattern? repeat;

  /// The task's day in the form: weekly repeats on its weekday, monthly on its day of the month by default.
  final DateTime day;

  /// The task is already an occurrence of a recurring task, so a change applies from it on.
  final bool isOccurrence;
}

/// The edited repeat, returned when the sub-page closes.
class TaskRepeatResult {
  const TaskRepeatResult(this.repeat);

  final RepeatPattern? repeat;
}

/// Sub-page of the task form (#24): Never / Daily / Weekdays / Weekly on … / Every N days / Monthly on day N, with an
/// optional end date. Going back returns the edited repeat to the form, which saves it with the task.
class TaskRepeatScreen extends StatefulWidget {
  const TaskRepeatScreen({super.key, required this.request});

  final TaskRepeatRequest request;

  @override
  State<TaskRepeatScreen> createState() => _TaskRepeatScreenState();
}

class _TaskRepeatScreenState extends State<TaskRepeatScreen> {
  late RepeatPattern? _repeat = widget.request.repeat;

  void _update(RepeatPattern? repeat) => setState(() => _repeat = repeat);

  void _choose(RepeatFrequency? frequency) {
    final current = _repeat;
    if (frequency == null) return _update(null);
    if (current == null) return _update(RepeatPattern.startingOn(frequency, widget.request.day));
    final weekdays = current.weekdays.isEmpty ? {widget.request.day.weekday} : current.weekdays;
    _update(current.copyWith(frequency: frequency, weekdays: weekdays));
  }

  Future<void> _pickEndDate() async {
    final repeat = _repeat;
    if (repeat == null) return;
    final first = widget.request.day;
    final initial = repeat.endDate ?? DateTime(first.year, first.month + 1, first.day);
    final picked = await showDatePicker(context: context, firstDate: first, lastDate: DateTime(2100), initialDate: initial.isBefore(first) ? first : initial);
    if (picked != null) _update(repeat.copyWith(endDate: picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repeat = _repeat;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day = widget.request.day;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(TaskRepeatResult(_repeat));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.taskRepeatTitle)),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            RadioGroup<RepeatFrequency?>(
              groupValue: repeat?.frequency,
              onChanged: _choose,
              child: Column(
                children: [
                  _FrequencyTile(key: const Key('repeat-never'), value: null, title: l10n.taskRepeatNever),
                  _FrequencyTile(key: const Key('repeat-daily'), value: RepeatFrequency.daily, title: l10n.taskRepeatDaily),
                  _FrequencyTile(key: const Key('repeat-weekdays'), value: RepeatFrequency.weekdays, title: l10n.taskRepeatWeekdays),
                  _FrequencyTile(key: const Key('repeat-weekly'), value: RepeatFrequency.weekly, title: l10n.taskRepeatWeekly),
                  if (repeat?.frequency == RepeatFrequency.weekly) _WeekdayPicker(repeat: repeat!, onChanged: _update),
                  _FrequencyTile(key: const Key('repeat-interval'), value: RepeatFrequency.interval, title: l10n.taskRepeatIntervalOption),
                  if (repeat?.frequency == RepeatFrequency.interval) _IntervalStepper(repeat: repeat!, onChanged: _update),
                  _FrequencyTile(
                    key: const Key('repeat-monthly'),
                    value: RepeatFrequency.monthly,
                    title: l10n.taskRepeatMonthly(repeat?.frequency == RepeatFrequency.monthly ? repeat!.monthDay : day.day),
                    subtitle: day.day > 28 ? l10n.taskRepeatMonthlyHint : null,
                  ),
                ],
              ),
            ),
            if (repeat != null) ...[
              const Divider(height: 32),
              ListTile(
                key: const Key('repeatEnds'),
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(l10n.taskRepeatEnds),
                subtitle: Text(repeat.endDate == null ? l10n.taskRepeatEndsNever : DateFormat.yMMMEd(locale).format(repeat.endDate!)),
                onTap: _pickEndDate,
                trailing: repeat.endDate == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(tooltip: l10n.taskScheduleClear, icon: const Icon(Icons.close), onPressed: () => _update(repeat.copyWith(clearEndDate: true))),
              ),
            ],
            if (widget.request.isOccurrence)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.taskRepeatSeriesHint, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (repeat != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(repeatSummary(context, repeat), key: const Key('repeatSummary'), style: Theme.of(context).textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyTile extends StatelessWidget {
  const _FrequencyTile({super.key, required this.value, required this.title, this.subtitle});

  final RepeatFrequency? value;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return RadioListTile<RepeatFrequency?>(value: value, title: Text(title), subtitle: subtitle == null ? null : Text(subtitle));
  }
}

/// The days of the week of a weekly repeat, in the locale's order; at least one stays selected.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.repeat, required this.onChanged});

  final RepeatPattern repeat;
  final ValueChanged<RepeatPattern> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final first = firstDayOfWeek(context);
    final weekdays = [for (var offset = 0; offset < DateTime.daysPerWeek; offset++) (first - 1 + offset) % DateTime.daysPerWeek + 1];
    // 2024-01-01 is a Monday.
    String name(int weekday) => DateFormat.E(locale).format(DateTime(2024, 1, weekday));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final weekday in weekdays)
            FilterChip(
              key: Key('repeatWeekday-$weekday'),
              label: Text(name(weekday)),
              selected: repeat.weekdays.contains(weekday),
              onSelected: (selected) {
                final days = {...repeat.weekdays};
                selected ? days.add(weekday) : days.remove(weekday);
                if (days.isNotEmpty) onChanged(repeat.copyWith(weekdays: days));
              },
            ),
        ],
      ),
    );
  }
}

/// Days between occurrences of an "every N days" repeat.
class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({required this.repeat, required this.onChanged});

  final RepeatPattern repeat;
  final ValueChanged<RepeatPattern> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = repeat.intervalDays;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(l10n.taskRepeatIntervalLabel),
      subtitle: Text(l10n.taskRepeatEveryDays(days)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('repeatIntervalLess'),
            tooltip: l10n.taskRepeatFewerDays,
            icon: const Icon(Icons.remove),
            onPressed: days > RepeatPattern.minIntervalDays ? () => onChanged(repeat.copyWith(intervalDays: days - 1)) : null,
          ),
          Text('$days', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            key: const Key('repeatIntervalMore'),
            tooltip: l10n.taskRepeatMoreDays,
            icon: const Icon(Icons.add),
            onPressed: days < RepeatPattern.maxIntervalDays ? () => onChanged(repeat.copyWith(intervalDays: days + 1)) : null,
          ),
        ],
      ),
    );
  }
}
