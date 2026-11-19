import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/core/ui/charts/bar_chart.dart';
import 'package:focused_task/core/ui/charts/heatmap_chart.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

/// Shown instead of the cards when a period has neither focus time nor planned tasks.
class StatsEmptyState extends StatelessWidget {
  const StatsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        spacing: 12,
        children: [
          Icon(Icons.insights_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
          Text(l10n.statsEmptyTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          Text(
            l10n.statsEmptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The key numbers as small tiles: 2 per row on phones, up to 5 on wide screens.
class StatsSummaryTiles extends StatelessWidget {
  const StatsSummaryTiles({super.key, required this.report, required this.width});

  final StatsReport report;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rate = report.completionRate;
    final interruptions = report.interruptionsPerFocusHour;
    final tiles = [
      _StatTile(
        icon: Icons.timer_outlined,
        title: l10n.statsFocusTime,
        value: l10n.durationLabel(report.focusTotal),
        detail: report.breakTotal < const Duration(minutes: 1) ? null : l10n.statsBreakTime(l10n.durationLabel(report.breakTotal)),
      ),
      _StatTile(icon: Icons.insights, title: l10n.statsAveragePerDay, value: l10n.durationLabel(report.averagePerElapsedDay), detail: l10n.statsElapsedDays(report.elapsedDays)),
      _StatTile(
        icon: Icons.av_timer,
        title: l10n.statsSessions,
        value: '${report.sessionCount}',
        detail: report.sessionCount == 0 ? null : l10n.statsAverageSession(l10n.durationLabel(report.averageSessionLength)),
      ),
      _StatTile(
        icon: Icons.task_alt,
        title: l10n.statsCompletion,
        value: rate == null ? l10n.statsNoValue : l10n.commonPercent((rate * 100).round()),
        detail: report.tasksPlanned == 0 ? l10n.statsNoTasks : l10n.statsTasksCompleted(report.tasksCompleted, report.tasksPlanned),
      ),
      _StatTile(
        icon: Icons.notifications_paused_outlined,
        title: l10n.statsInterruptions,
        value: interruptions == null ? l10n.statsNoValue : l10n.statsInterruptionsValue(interruptions),
        detail: interruptions == null ? l10n.statsNotTrackedYet : null,
      ),
    ];

    const spacing = 12.0;
    final perRow = width >= 1000 ? 5 : (width >= 600 ? 3 : 2);
    final tileWidth = (width - spacing * (perRow - 1)) / perRow;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [for (final tile in tiles) SizedBox(width: tileWidth, child: tile)],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.icon, required this.title, required this.value, this.detail});

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge),
            // Same height with and without detail, so tiles in a row line up.
            Text(
              detail ?? '',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card around one statistic.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bar chart of the focus time per hour (day), per day (week, month) or per month (year). Per day, a dashed line
/// marks the [dailyGoal].
class FocusChartCard extends StatelessWidget {
  const FocusChartCard({super.key, required this.report, this.dailyGoal});

  final StatsReport report;
  final Duration? dailyGoal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    final granularity = report.query.granularity;

    final title = switch (granularity) {
      StatsGranularity.hour => l10n.statsFocusPerHour,
      StatsGranularity.day => l10n.statsFocusPerDay,
      StatsGranularity.month => l10n.statsFocusPerMonth,
    };
    final isWeek = granularity == StatsGranularity.day && report.buckets.length <= DateTime.daysPerWeek;

    ChartBar bar(StatsBucket bucket) {
      final start = bucket.start;
      final (label, name, current) = switch (granularity) {
        StatsGranularity.hour => ('${start.hour}', l10n.statsHourRange(_twoDigits(start.hour), _twoDigits(start.hour + 1)), !now.isBefore(start) && now.isBefore(bucket.end)),
        StatsGranularity.day => (isWeek ? DateFormat.E(locale).format(start) : '${start.day}', DateFormat.MMMEd(locale).format(start), start.isSameDate(now)),
        StatsGranularity.month => (DateFormat.MMM(locale).format(start), DateFormat.yMMMM(locale).format(start), start.year == now.year && start.month == now.month),
      };
      return ChartBar(
        value: bucket.focus.inSeconds / Duration.secondsPerMinute,
        label: label,
        tooltip: l10n.statsChartTooltip(name, l10n.durationLabel(bucket.focus)),
        highlighted: current,
      );
    }

    return StatsCard(
      title: title,
      child: BarChart(
        key: const Key('statsFocusChart'),
        bars: [for (final bucket in report.buckets) bar(bucket)],
        referenceValue: granularity == StatsGranularity.day && dailyGoal != null ? dailyGoal!.inSeconds / Duration.secondsPerMinute : null,
        semanticsLabel: title,
      ),
    );
  }
}

/// Heatmap of the focus time by weekday × hour of day.
class BestHoursCard extends StatelessWidget {
  const BestHoursCard({super.key, required this.report});

  final StatsReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final firstWeekday = firstDayOfWeek(context);
    final weekdays = [for (var offset = 0; offset < DateTime.daysPerWeek; offset++) (firstWeekday - 1 + offset) % DateTime.daysPerWeek + 1];
    // 2024-01-01 was a Monday: any week gives the localized weekday names.
    String weekdayName(int weekday) => DateFormat.E(locale).format(DateTime(2024, 1, weekday));

    return StatsCard(
      title: l10n.statsBestHours,
      child: HeatmapChart(
        key: const Key('statsHeatmap'),
        semanticsLabel: l10n.statsBestHours,
        rowLabels: [for (final weekday in weekdays) weekdayName(weekday)],
        columnLabels: [for (var hour = 0; hour < hoursPerDay; hour++) hour % 6 == 0 ? '$hour' : null],
        values: [
          for (final weekday in weekdays) [for (var hour = 0; hour < hoursPerDay; hour++) report.focusAt(weekday, hour).inSeconds.toDouble()],
        ],
        tooltip: (row, hour) {
          final weekday = weekdays[row];
          final label = l10n.statsHeatmapLabel(weekdayName(weekday), l10n.statsHourRange(_twoDigits(hour), _twoDigits(hour + 1)));
          return l10n.statsChartTooltip(label, l10n.durationLabel(report.focusAt(weekday, hour)));
        },
      ),
    );
  }
}

/// Sum of target durations vs. tracked time, and the median estimation accuracy.
class PlannedVsActualCard extends StatelessWidget {
  const PlannedVsActualCard({super.key, required this.report});

  final StatsReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final comparison = report.plannedVsActual;
    final accuracy = comparison.estimationAccuracy;

    if (comparison.taskCount == 0) {
      return StatsCard(
        title: l10n.statsPlannedVsActual,
        child: Text(l10n.statsNoTargets, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    final scale = comparison.planned > comparison.actual ? comparison.planned : comparison.actual;
    double share(Duration value) => scale == Duration.zero ? 0 : value.inSeconds / scale.inSeconds;

    return StatsCard(
      title: l10n.statsPlannedVsActual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(l10n.statsTargetTasks(comparison.taskCount), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          _ComparisonBar(label: l10n.statsPlanned, value: l10n.durationLabel(comparison.planned), share: share(comparison.planned), color: theme.colorScheme.outline),
          _ComparisonBar(label: l10n.statsTracked, value: l10n.durationLabel(comparison.actual), share: share(comparison.actual), color: theme.colorScheme.primary),
          if (accuracy != null) Text(l10n.statsEstimationAccuracy((accuracy * 100).round()), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({required this.label, required this.value, required this.share, required this.color});

  final String label;
  final String value;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(value, style: theme.textTheme.titleSmall),
          ],
        ),
        LinearProgressIndicator(value: share.clamp(0, 1), color: color, backgroundColor: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }
}

/// Up to five tasks with the most focus time in the period.
class TopTasksCard extends StatelessWidget {
  const TopTasksCard({super.key, required this.report});

  final StatsReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final top = report.topTasks;
    if (top.isEmpty) return const SizedBox.shrink();
    final most = top.first.focus;

    return StatsCard(
      title: l10n.statsTopTasks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          for (final task in top)
            _ComparisonBar(
              label: task.title ?? l10n.statsDeletedTask,
              value: l10n.durationLabel(task.focus),
              share: most == Duration.zero ? 0 : task.focus.inSeconds / most.inSeconds,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

/// Focus time per category, most first, as bars in the category colours.
class CategoryFocusCard extends StatelessWidget {
  const CategoryFocusCard({super.key, required this.report, required this.categoryOf});

  final StatsReport report;

  /// The category with an id, `null` if it doesn't exist (any more).
  final TaskCategory? Function(int? id) categoryOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entries = report.focusByCategory;
    if (!report.hasCategorizedFocus) return const SizedBox.shrink();
    final most = entries.first.focus;

    return StatsCard(
      key: const Key('statsByCategory'),
      title: l10n.statsByCategory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          for (final entry in entries)
            _ComparisonBar(
              label: categoryOf(entry.categoryId)?.name ?? l10n.statsNoCategory,
              value: l10n.durationLabel(entry.focus),
              share: most == Duration.zero ? 0 : entry.focus.inSeconds / most.inSeconds,
              color: switch (categoryOf(entry.categoryId)) {
                final category? => CategoryColor.of(category.colorIndex).color(context),
                null => theme.colorScheme.outline,
              },
            ),
        ],
      ),
    );
  }
}

/// Current and longest streak, and the goal days per month of [year]; a hint while no goal is set.
class StreakCards extends StatelessWidget {
  const StreakCards({super.key, required this.status, required this.year});

  final GoalStatus status;
  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final goal = status.goal;
    if (!goal.isEnabled) {
      return StatsCard(
        title: l10n.settingsDailyGoal,
        child: Text(l10n.statsGoalOff, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    final hint = l10n.statsStreakHint(l10n.durationLabel(goal.daily!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: _StatTile(
                key: const Key('statsCurrentStreak'),
                icon: Icons.event_available,
                title: l10n.statsCurrentStreak,
                value: l10n.statsStreakDays(status.streak.current),
                detail: hint,
              ),
            ),
            Expanded(
              child: _StatTile(
                key: const Key('statsLongestStreak'),
                icon: Icons.history,
                title: l10n.statsLongestStreak,
                value: l10n.statsStreakDays(status.streak.longest),
                detail: hint,
              ),
            ),
          ],
        ),
        GoalDaysCard(status: status, year: year),
      ],
    );
  }
}

/// Bar chart of the days per month of [year] on which the goal was reached.
class GoalDaysCard extends StatelessWidget {
  const GoalDaysCard({super.key, required this.status, required this.year});

  final GoalStatus status;
  final int year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = l10n.statsGoalDays(DateFormat.y(locale).format(DateTime(year)));
    final perMonth = status.goalDaysPerMonth(year);
    final today = status.today;

    return StatsCard(
      title: title,
      child: BarChart(
        key: const Key('statsGoalDaysChart'),
        semanticsLabel: title,
        bars: [
          for (var month = 1; month <= DateTime.monthsPerYear; month++)
            ChartBar(
              value: perMonth[month - 1].toDouble(),
              label: DateFormat.MMM(locale).format(DateTime(year, month)),
              tooltip: l10n.statsGoalDaysTooltip(DateFormat.yMMMM(locale).format(DateTime(year, month)), perMonth[month - 1]),
              highlighted: today.year == year && today.month == month,
            ),
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
