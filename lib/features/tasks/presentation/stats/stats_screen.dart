import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_range.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final dates = statsDateRange(range, clock.now());
    final stats = ref.watch(taskStatsProvider(dates));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/plan');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(taskStatsProvider(dates).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<StatsRange>(
              segments: const [
                ButtonSegment(value: StatsRange.day, label: Text('Day'), icon: Icon(Icons.today)),
                ButtonSegment(value: StatsRange.week, label: Text('Week'), icon: Icon(Icons.date_range)),
                ButtonSegment(value: StatsRange.month, label: Text('Month'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {range},
              onSelectionChanged: (selection) => ref.read(statsRangeProvider.notifier).select(selection.first),
            ),
            const SizedBox(height: 16),
            switch (stats) {
              AsyncData(:final value) => _StatsContent(stats: value),
              AsyncError() => const Center(child: Text('No stats available yet.')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Completion score', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${stats.completionScore.toStringAsFixed(1)}%', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('${stats.completedTasks}/${stats.totalTasks} tasks completed', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Let the outer ListView handle scrolling
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5, // Adjust this ratio to make the cards taller or shorter
          children: [
            _StatCard(title: 'Focus time', value: '${stats.totalFocusMinutes} min', icon: Icons.timer_outlined),
            _StatCard(title: 'Avg. task duration', value: '${stats.averageTaskDurationMinutes} min', icon: Icons.av_timer),
            _StatCard(title: 'Per day', value: '${stats.focusMinutesPerDay} min', icon: Icons.insights),
            _StatCard(title: 'Remaining', value: '${stats.totalTasks - stats.completedTasks} tasks', icon: Icons.pending_actions_outlined),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
