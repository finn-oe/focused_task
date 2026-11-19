import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_range.dart';
import 'package:focused_task/features/tasks/presentation/stats/widgets/stats_cards.dart';

/// Width from which the cards are laid out in two columns.
const _twoColumnWidth = 720.0;

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final firstWeekday = firstDayOfWeek(context);
    final period = ref.watch(statsPeriodProvider);
    final query = period.query(firstWeekday: firstWeekday);
    final report = ref.watch(statsReportProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(statsReportProvider(query).future),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RangeSelector(range: period.range),
                const SizedBox(height: 8),
                _PeriodNavigator(period: period, firstWeekday: firstWeekday),
                const SizedBox(height: 8),
                switch (report) {
                  AsyncValue(:final value?) => value.isEmpty ? const StatsEmptyState() : _StatsContent(report: value),
                  AsyncError() => Center(child: Text(l10n.statsUnavailable)),
                  _ => const Center(child: CircularProgressIndicator()),
                },
                const SizedBox(height: 12),
                _GoalSection(year: query.range.start.year),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streaks are about the whole history, so they show for every period; the goal days follow the period's year.
class _GoalSection extends ConsumerWidget {
  const _GoalSection({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(goalStatusProvider).value;
    return status == null ? const SizedBox.shrink() : StreakCards(status: status, year: year);
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector({required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedButton<StatsRange>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: StatsRange.day, label: Text(l10n.statsDay)),
        ButtonSegment(value: StatsRange.week, label: Text(l10n.statsWeek)),
        ButtonSegment(value: StatsRange.month, label: Text(l10n.statsMonth)),
        ButtonSegment(value: StatsRange.year, label: Text(l10n.statsYear)),
      ],
      selected: {range},
      onSelectionChanged: (selection) => ref.read(statsPeriodProvider.notifier).select(selection.first),
    );
  }
}

/// ‹ period label › plus a button back to the current period.
class _PeriodNavigator extends ConsumerWidget {
  const _PeriodNavigator({required this.period, required this.firstWeekday});

  final StatsPeriod period;
  final int firstWeekday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(statsPeriodProvider.notifier);
    final isCurrent = period.contains(clock.now(), firstWeekday: firstWeekday);

    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), tooltip: l10n.statsPreviousPeriod, onPressed: notifier.previous),
        Expanded(
          child: Text(
            statsPeriodLabel(context, period, firstWeekday: firstWeekday),
            key: const Key('statsPeriodLabel'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // Same width either way, so the label stays centred.
        if (isCurrent)
          const SizedBox(width: kMinInteractiveDimension)
        else
          IconButton(icon: const Icon(Icons.today), tooltip: l10n.statsCurrentPeriod, onPressed: notifier.goToCurrent),
        IconButton(icon: const Icon(Icons.chevron_right), tooltip: l10n.statsNextPeriod, onPressed: notifier.next),
      ],
    );
  }
}

/// "Tue, Nov 17, 2026", "Nov 16 – Nov 22, 2026", "November 2026" or "2026".
String statsPeriodLabel(BuildContext context, StatsPeriod period, {required int firstWeekday}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dates = period.dates(firstWeekday: firstWeekday);
  return switch (period.range) {
    StatsRange.day => DateFormat.yMMMEd(locale).format(dates.start),
    StatsRange.week => context.l10n.statsWeekLabel(
      dates.start.year == dates.end.year ? DateFormat.MMMd(locale).format(dates.start) : DateFormat.yMMMd(locale).format(dates.start),
      DateFormat.yMMMd(locale).format(dates.end),
    ),
    StatsRange.month => DateFormat.yMMMM(locale).format(dates.start),
    StatsRange.year => DateFormat.y(locale).format(dates.start),
  };
}

class _StatsContent extends ConsumerWidget {
  const _StatsContent({required this.report});

  final StatsReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(focusGoalProvider);
    final categories = ref.watch(categoriesNotifierProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          PlannedVsActualCard(report: report),
          BestHoursCard(report: report),
          TopTasksCard(report: report),
          if (report.hasCategorizedFocus) CategoryFocusCard(report: report, categoryOf: categories.byId),
        ];
        final twoColumns = constraints.maxWidth >= _twoColumnWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            StatsSummaryTiles(report: report, width: constraints.maxWidth),
            FocusChartCard(report: report, dailyGoal: goal.isEnabled ? goal.daily : null),
            if (twoColumns) ...[
              for (var index = 0; index < cards.length; index += 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(child: cards[index]),
                    Expanded(child: index + 1 < cards.length ? cards[index + 1] : const SizedBox.shrink()),
                  ],
                ),
            ] else
              ...cards,
          ],
        );
      },
    );
  }
}
