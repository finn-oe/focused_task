import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

class FinishedForTodayScreen extends ConsumerWidget {
  const FinishedForTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final today = clock.now().dateOnly;
    final report = ref.watch(statsReportProvider(StatsQuery(range: DateRange(today, today), granularity: StatsGranularity.day))).value;
    final goal = ref.watch(focusGoalProvider);
    final status = goal.isEnabled ? ref.watch(goalStatusProvider).value : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.finishedTitle),
        leading: IconButton(onPressed: () => context.go(AppRoutes.plan), icon: const Icon(Icons.close)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 24),
                Text(l10n.finishedHeadline, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(l10n.finishedMessage, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                if (report != null) ...[const SizedBox(height: 24), TodaySummaryCard(focus: report.focusTotal, tasksDone: report.tasksCompleted, goal: status)],
                const SizedBox(height: 32),
                FilledButton.icon(onPressed: () => context.go(AppRoutes.stats), icon: const Icon(Icons.insights_outlined), label: Text(l10n.finishedViewStatistics)),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => context.go(AppRoutes.plan), icon: const Icon(Icons.assignment_outlined), label: Text(l10n.finishedBackToPlan)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today in numbers: focus time, tasks done and – with a daily goal – whether it was reached and the streak.
class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.focus, required this.tasksDone, this.goal});

  final Duration focus;
  final int tasksDone;

  /// `null` without a daily goal.
  final GoalStatus? goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final goal = this.goal;
    final daily = goal?.goal.daily;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l10n.finishedSummary, style: theme.textTheme.titleMedium),
            ),
            _SummaryRow(icon: Icons.timer_outlined, label: l10n.finishedFocusTime, value: l10n.durationLabel(focus)),
            _SummaryRow(icon: Icons.task_alt, label: l10n.finishedTasksDone, value: '$tasksDone'),
            if (goal != null && daily != null) ...[
              goal.reachedToday
                  ? _SummaryRow(
                      key: const Key('finishedGoalReached'),
                      icon: Icons.check_circle_outline,
                      iconColor: theme.colorScheme.primary,
                      label: l10n.finishedGoal,
                      value: l10n.finishedGoalReached(l10n.durationLabel(daily)),
                    )
                  : _SummaryRow(
                      key: const Key('finishedGoalNotReached'),
                      icon: Icons.highlight_off,
                      label: l10n.finishedGoal,
                      value: l10n.finishedGoalNotReached(l10n.durationLabel(focus), l10n.durationLabel(daily)),
                    ),
              _SummaryRow(icon: Icons.event_available, label: l10n.finishedStreak, value: l10n.statsStreakDays(goal.streak.current)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({super.key, required this.icon, required this.label, required this.value, this.iconColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A row instead of a ListTile: long values ("Not reached (25 min of 2 h)") wrap instead of overflowing at 360 px.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 16,
        children: [
          Icon(icon, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Flexible(
            child: Text(value, style: theme.textTheme.titleSmall, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
