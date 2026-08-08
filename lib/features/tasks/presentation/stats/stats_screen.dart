import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task_stats.dart';

enum StatsRange { day, week, month }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsRange _range = StatsRange.day;
  TaskStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    final repository = ref.read(taskRepositoryProvider);
    final now = DateTime.now();
    final range = _range;
    final start = _startOfRange(now, range);
    final end = _endOfRange(now, range);
    final stats = await repository.getTaskStats(start: start, end: end);

    if (!mounted) {
      return;
    }

    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<StatsRange>(
              segments: const [
                ButtonSegment(value: StatsRange.day, label: Text('Day'), icon: Icon(Icons.today)),
                ButtonSegment(value: StatsRange.week, label: Text('Week'), icon: Icon(Icons.date_range)),
                ButtonSegment(value: StatsRange.month, label: Text('Month'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {_range},
              onSelectionChanged: (selection) async {
                setState(() => _range = selection.first);
                await _loadStats();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_stats == null)
              const Center(child: Text('No stats available yet.'))
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Completion score', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${_stats!.completionScore.toStringAsFixed(1)}%', style: theme.textTheme.displaySmall),
                      const SizedBox(height: 8),
                      Text('${_stats!.completedTasks}/${_stats!.totalTasks} tasks completed', style: theme.textTheme.bodyMedium),
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
                  _buildStatCard('Focus time', '${_stats!.totalFocusMinutes} min', Icons.timer_outlined),
                  _buildStatCard('Avg. task duration', '${_stats!.averageTaskDurationMinutes} min', Icons.av_timer),
                  _buildStatCard('Per day', '${_stats!.focusMinutesPerDay} min', Icons.insights),
                  _buildStatCard('Remaining', '${_stats!.totalTasks - _stats!.completedTasks} tasks', Icons.pending_actions_outlined),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
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

  DateTime _startOfRange(DateTime now, StatsRange range) {
    switch (range) {
      case StatsRange.day:
        return DateTime(now.year, now.month, now.day);
      case StatsRange.week:
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day);
      case StatsRange.month:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime _endOfRange(DateTime now, StatsRange range) {
    switch (range) {
      case StatsRange.day:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case StatsRange.week:
        final lastDayOfWeek = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
        return DateTime(lastDayOfWeek.year, lastDayOfWeek.month, lastDayOfWeek.day, 23, 59, 59);
      case StatsRange.month:
        final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);
        return DateTime(firstDayOfNextMonth.year, firstDayOfNextMonth.month, firstDayOfNextMonth.day - 1, 23, 59, 59);
    }
  }
}
