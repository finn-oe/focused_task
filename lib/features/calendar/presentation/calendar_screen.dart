import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/features/calendar/presentation/calendar_notifier.dart';
import 'package:focused_task/features/calendar/presentation/calendar_period.dart';
import 'package:focused_task/features/tasks/domain/entities/day_summary.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Key of the column (week) or cell (month) of [day], e.g. for tests.
Key calendarDayKey(DateTime day) => ValueKey('calendar-day-${day.isoDate}');

/// Week and month views. The view and the shown day come from the URL (`/calendar?view=month&date=YYYY-MM-DD`;
/// missing = week view, today), so browser back/forward and deep links work. Tapping a day opens it in the plan.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, this.view, this.date});

  /// View from the route; `null` shows the week.
  final CalendarView? view;

  /// Day from the route; `null` shows today.
  final DateTime? date;

  /// Window width from which the week shows 7 columns instead of an agenda.
  static const wideWeekWidth = 900.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = clock.now().dateOnly;
    final period = CalendarPeriod(view: view ?? CalendarView.week, anchor: date ?? today, firstWeekday: firstDayOfWeek(context));

    void show(CalendarView view, DateTime anchor) => context.go(AppRoutes.calendarFor(view, anchor, today: today));
    void previous() => show(period.view, period.previous.start);
    void next() => show(period.view, period.next.start);
    void goToToday() => show(period.view, today);
    void switchView(CalendarView view) => show(view, period.contains(today) ? today : period.anchor);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): previous, const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): next},
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return Scaffold(
              appBar: AppBar(
                titleSpacing: 4,
                title: _PeriodNavigator(period: period, onPrevious: previous, onNext: next),
                actions: [
                  if (!period.contains(today))
                    compact
                        ? IconButton(tooltip: l10n.commonToday, onPressed: goToToday, icon: const Icon(Icons.today))
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(label: Text(l10n.commonToday), avatar: const Icon(Icons.today), onPressed: goToToday),
                          ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<CalendarView>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: CalendarView.week, label: Text(l10n.calendarViewWeek), icon: const Icon(Icons.view_week_outlined)),
                          ButtonSegment(value: CalendarView.month, label: Text(l10n.calendarViewMonth), icon: const Icon(Icons.calendar_month_outlined)),
                        ],
                        selected: {period.view},
                        onSelectionChanged: (selection) => switchView(selection.first),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CalendarBody(period: period, today: today),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// `‹` previous period · week or month label · `›` next period.
class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.period, required this.onPrevious, required this.onNext});

  final CalendarPeriod period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isWeek = period.view == CalendarView.week;
    final label = isWeek
        ? l10n.calendarWeekRange(DateFormat.MMMd(locale).format(period.start), DateFormat.yMMMd(locale).format(period.end))
        : DateFormat.yMMMM(locale).format(period.start);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: isWeek ? l10n.calendarPreviousWeek : l10n.calendarPreviousMonth, onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(tooltip: isWeek ? l10n.calendarNextWeek : l10n.calendarNextMonth, onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({required this.period, required this.today});

  final CalendarPeriod period;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider(period.visibleRange));
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.calendarLoadError(state.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    if (state.isLoading && state.tasksByDay.isEmpty) return const Center(child: CircularProgressIndicator());

    void openDay(DateTime day) => context.go(AppRoutes.planFor(day, today: today));
    Future<void> moveTask(TaskEntity task, DateTime day) => ref.read(calendarProvider(period.visibleRange).notifier).moveTask(task, day);

    if (period.view == CalendarView.month) {
      return _MonthGrid(period: period, today: today, state: state, onOpenDay: openDay);
    }
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= CalendarScreen.wideWeekWidth
          ? _WeekColumns(period: period, today: today, state: state, onOpenDay: openDay, onMoveTask: moveTask)
          : _WeekAgenda(period: period, today: today, state: state, onOpenDay: openDay, onMoveTask: moveTask),
    );
  }
}

// --- Week: columns (wide) ------------------------------------------------------------------------------------------

class _WeekColumns extends StatelessWidget {
  const _WeekColumns({required this.period, required this.today, required this.state, required this.onOpenDay, required this.onMoveTask});

  final CalendarPeriod period;
  final DateTime today;
  final CalendarState state;
  final ValueChanged<DateTime> onOpenDay;
  final Future<void> Function(TaskEntity task, DateTime day) onMoveTask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in period.visibleDays)
            Expanded(
              child: _DayColumn(
                key: calendarDayKey(day),
                day: day,
                isToday: day.isSameDate(today),
                tasks: state.tasksOn(day),
                summary: state.summaryOf(day),
                onOpen: () => onOpenDay(day),
                onDrop: (task) => onMoveTask(task, day),
              ),
            ),
        ],
      ),
    );
  }
}

/// One day of the wide week: header and the day's tasks. Tasks of other days can be dropped onto it.
class _DayColumn extends StatelessWidget {
  const _DayColumn({super.key, required this.day, required this.isToday, required this.tasks, required this.summary, required this.onOpen, required this.onDrop});

  final DateTime day;
  final bool isToday;
  final List<TaskEntity> tasks;
  final DaySummary summary;
  final VoidCallback onOpen;
  final ValueChanged<TaskEntity> onDrop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DragTarget<TaskEntity>(
      onWillAcceptWithDetails: (details) => !details.data.assignedDate.isSameDate(day),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: highlighted ? colors.primaryContainer : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: highlighted ? colors.primary : colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DayHeader(day: day, isToday: isToday, summary: summary, onOpen: onOpen),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(6),
                  children: [for (final task in tasks) _DraggableTask(key: ValueKey('calendar-task-${task.id}'), task: task, onOpen: onOpen)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Weekday, day number (today highlighted) and the day's summary; tapping opens the day in the plan.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isToday, required this.summary, required this.onOpen});

  final DateTime day;
  final bool isToday;
  final DaySummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Tooltip(
      message: context.l10n.calendarOpenDay,
      child: InkWell(
        onTap: onOpen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(DateFormat.E(locale).format(day), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              _DayNumber(day: day, isToday: isToday, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              _SummaryLine(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2/3 · 01:05" – done/total tasks and focus time; empty parts are left out.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (summary.total > 0) _TaskCount(summary: summary, style: style),
        if (summary.focusTime > Duration.zero)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 2),
              Text(
                summary.focusTime.toFormattedString(),
                style: style?.copyWith(color: theme.colorScheme.primary),
                semanticsLabel: context.l10n.calendarFocusTime(summary.focusTime.toFormattedString()),
              ),
            ],
          ),
      ],
    );
  }
}

class _TaskCount extends StatelessWidget {
  const _TaskCount({required this.summary, this.style});

  final DaySummary summary;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(l10n.calendarDoneOfTotal(summary.completed, summary.total), style: style, semanticsLabel: l10n.calendarTasksDone(summary.completed, summary.total));
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day, required this.isToday, this.style, this.dimmed = false});

  final DateTime day;
  final bool isToday;
  final TextStyle? style;

  /// Day outside the shown month.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isToday
        ? colors.onPrimary
        : dimmed
        ? colors.outline
        : colors.onSurface;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: isToday ? BoxDecoration(color: colors.primary, shape: BoxShape.circle) : null,
      child: Text(
        '${day.day}',
        style: (style ?? const TextStyle()).copyWith(color: color, fontWeight: isToday ? FontWeight.bold : null),
      ),
    );
  }
}

/// A task of the wide week; long-press and drag it onto another day to move it.
class _DraggableTask extends StatelessWidget {
  const _DraggableTask({super.key, required this.task, required this.onOpen});

  final TaskEntity task;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chip = _TaskChip(task: task, onTap: onOpen);
        return LongPressDraggable<TaskEntity>(
          data: task,
          feedback: SizedBox(
            width: constraints.maxWidth,
            child: Material(
              type: MaterialType.transparency,
              child: _TaskChip(task: task, elevation: 6),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: chip),
          child: chip,
        );
      },
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.task, this.onTap, this.elevation = 0});

  final TaskEntity task;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: _TaskTitle(task: task, maxLines: 3),
        ),
      ),
    );
  }
}

/// The task's title; completed tasks are struck through.
class _TaskTitle extends StatelessWidget {
  const _TaskTitle({required this.task, this.maxLines});

  final TaskEntity task;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          // Recurring tasks (#24) are marked like in the plan.
          if (task.isRecurring)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.repeat, size: 14, color: theme.colorScheme.onSurfaceVariant, semanticLabel: context.l10n.taskRecurringLabel),
              ),
            ),
          TextSpan(text: task.title),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: task.isCompleted
          ? theme.textTheme.bodyMedium?.copyWith(decoration: TextDecoration.lineThrough, color: theme.colorScheme.onSurfaceVariant)
          : theme.textTheme.bodyMedium,
    );
  }
}

// --- Week: agenda (narrow) -----------------------------------------------------------------------------------------

class _WeekAgenda extends StatelessWidget {
  const _WeekAgenda({required this.period, required this.today, required this.state, required this.onOpenDay, required this.onMoveTask});

  final CalendarPeriod period;
  final DateTime today;
  final CalendarState state;
  final ValueChanged<DateTime> onOpenDay;
  final Future<void> Function(TaskEntity task, DateTime day) onMoveTask;

  Future<void> _move(BuildContext context, TaskEntity task) async {
    final target = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MoveTaskDialog(task: task, days: period.visibleDays, today: today),
    );
    if (target != null) await onMoveTask(task, target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final day in period.visibleDays) ...[
          _AgendaDayHeader(key: calendarDayKey(day), day: day, today: today, summary: state.summaryOf(day), onOpen: () => onOpenDay(day)),
          if (state.tasksOn(day).isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Text(l10n.calendarNoTasks, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            )
          else
            for (final task in state.tasksOn(day))
              ListTile(
                key: ValueKey('calendar-task-${task.id}'),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 24, right: 4),
                leading: Icon(
                  task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: task.isCompleted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                title: _TaskTitle(task: task),
                onTap: () => onOpenDay(day),
                trailing: PopupMenuButton<void>(
                  itemBuilder: (_) => [PopupMenuItem(onTap: () => _move(context, task), child: Text(l10n.calendarMoveTo))],
                ),
              ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ],
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({super.key, required this.day, required this.today, required this.summary, required this.onOpen});

  final DateTime day;
  final DateTime today;
  final DaySummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = day.isSameDate(today);
    return ListTile(
      leading: _DayNumber(day: day, isToday: isToday, style: theme.textTheme.titleMedium),
      title: Text(
        relativeDayLabel(context, day, today: today),
        style: theme.textTheme.titleSmall?.copyWith(color: isToday ? theme.colorScheme.primary : null, fontWeight: FontWeight.w600),
      ),
      trailing: _SummaryLine(summary: summary),
      onTap: onOpen,
    );
  }
}

/// Asks for the day to move [task] to: another day of the shown week, or any date.
class _MoveTaskDialog extends StatelessWidget {
  const _MoveTaskDialog({required this.task, required this.days, required this.today});

  final TaskEntity task;
  final List<DateTime> days;
  final DateTime today;

  Future<void> _pickOtherDate(BuildContext context) async {
    final navigator = Navigator.of(context);
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: task.assignedDate.dateOnly);
    navigator.pop(picked?.dateOnly);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SimpleDialog(
      title: Text(l10n.calendarMoveTaskTitle(task.title)),
      children: [
        for (final day in days)
          if (!day.isSameDate(task.assignedDate))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(day),
              child: Text(relativeDayLabel(context, day, today: today)),
            ),
        SimpleDialogOption(onPressed: () => _pickOtherDate(context), child: Text(l10n.calendarOtherDate)),
      ],
    );
  }
}

// --- Month ---------------------------------------------------------------------------------------------------------

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.period, required this.today, required this.state, required this.onOpenDay});

  final CalendarPeriod period;
  final DateTime today;
  final CalendarState state;
  final ValueChanged<DateTime> onOpenDay;

  static const _minRowHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = period.visibleDays;
    final weeks = days.length ~/ DateTime.daysPerWeek;
    final maxFocus = state.maxFocusTime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in days.take(DateTime.daysPerWeek))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      DateFormat.E(locale).format(day),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowHeight = math.max(_minRowHeight, (constraints.maxHeight / weeks).floorToDouble());
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var week = 0; week < weeks; week++)
                        SizedBox(
                          height: rowHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final day in days.skip(week * DateTime.daysPerWeek).take(DateTime.daysPerWeek))
                                Expanded(
                                  child: _MonthCell(
                                    key: calendarDayKey(day),
                                    day: day,
                                    isToday: day.isSameDate(today),
                                    inMonth: period.contains(day),
                                    summary: state.summaryOf(day),
                                    maxFocus: maxFocus,
                                    onOpen: () => onOpenDay(day),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Day number, done/total badge and a bar for the focus time (relative to the busiest visible day).
class _MonthCell extends StatelessWidget {
  const _MonthCell({super.key, required this.day, required this.isToday, required this.inMonth, required this.summary, required this.maxFocus, required this.onOpen});

  final DateTime day;
  final bool isToday;
  final bool inMonth;
  final DaySummary summary;
  final Duration maxFocus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allDone = summary.total > 0 && summary.completed == summary.total;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isToday ? colors.primaryContainer.withValues(alpha: 0.4) : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isToday ? colors.primary : colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Semantics(
            label: DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(day),
            button: true,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DayNumber(day: day, isToday: isToday, dimmed: !inMonth, style: theme.textTheme.labelLarge),
                  const Spacer(),
                  if (summary.total > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: allDone ? colors.primary : colors.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                        child: _TaskCount(
                          summary: summary,
                          style: theme.textTheme.labelSmall?.copyWith(color: allDone ? colors.onPrimary : colors.onSecondaryContainer),
                        ),
                      ),
                    ),
                  if (summary.focusTime > Duration.zero) ...[
                    const SizedBox(height: 3),
                    _FocusBar(
                      fraction: maxFocus > Duration.zero ? summary.focusTime.inSeconds / maxFocus.inSeconds : 0,
                      label: context.l10n.calendarFocusTime(summary.focusTime.toFormattedString()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusBar extends StatelessWidget {
  const _FocusBar({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: Container(
        height: 4,
        decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.05, 1.0),
          child: Container(
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
    );
  }
}
