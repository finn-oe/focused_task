import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/task_builders.dart';
import '../../../helpers/localized_app.dart';

void main() {
  testWidgets('shows the stats of the selected range and reloads when it changes', (tester) async {
    final today = DateTime.now().dateOnly;
    final repository = FakeTaskRepository(
      tasks: [
        buildTask(id: 1, assignedDate: today, isCompleted: true),
        // Two weeks ago: outside of "Day" and "Week", but possibly inside "Month".
        buildTask(id: 2, assignedDate: today.addDays(-14), sortOrder: 'a1'),
      ],
    );
    await repository.addManualTime(taskId: 1, day: today, duration: const Duration(minutes: 25));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository), focusSessionRepositoryProvider.overrideWithValue(repository)],
        child: localizedApp(home: const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/1 task completed'), findsOneWidget);
    expect(find.text('25 min'), findsWidgets);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    final sameMonth = today.addDays(-14).month == today.month;
    expect(find.text(sameMonth ? '1/2 tasks completed' : '1/1 task completed'), findsOneWidget);
  });

  test('taskStatsProvider caches per date range', () async {
    final repository = FakeTaskRepository();
    final container = ProviderContainer.test(overrides: [taskRepositoryProvider.overrideWithValue(repository), focusSessionRepositoryProvider.overrideWithValue(repository)]);
    final today = DateTime(2026, 11, 17);

    expect(taskStatsProvider(DateRange(today, today)), taskStatsProvider(DateRange(today.add(const Duration(hours: 5)), today)));
    final stats = await container.read(taskStatsProvider(DateRange(today, today)).future);
    expect(stats.totalTasks, 0);
  });
}
