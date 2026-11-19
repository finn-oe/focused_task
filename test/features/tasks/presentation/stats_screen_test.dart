import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/ui/charts/bar_chart.dart';
import 'package:focused_task/core/ui/charts/heatmap_chart.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/task_builders.dart';
import '../../../helpers/localized_app.dart';

// Wednesday, 18 Nov 2026, 15:00.
final _now = DateTime(2026, 11, 18, 15);

Future<FakeTaskRepository> _pump(WidgetTester tester, {Size size = const Size(800, 1600), FocusGoal goal = FocusGoal.off}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = FakeTaskRepository(
    tasks: [
      buildTask(id: 1, title: 'Deep work', assignedDate: _now, isCompleted: true, targetDurationMinutes: 30),
      // Two weeks earlier: outside of "Day" and "Week", inside "Month".
      buildTask(id: 2, title: 'Old task', assignedDate: _now.addDays(-14), sortOrder: 'a1'),
    ],
  );
  await repository.addManualTime(taskId: 1, day: _now, duration: const Duration(minutes: 25));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        focusGoalProvider.overrideWithValue(goal),
      ],
      child: localizedApp(home: const StatsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

String _periodLabel(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('statsPeriodLabel'))).data!;

void main() {
  testWidgets('shows the numbers, chart, heatmap and top tasks of the day', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester);

      expect(_periodLabel(tester), 'Wed, Nov 18, 2026');
      expect(find.text('1/1 task completed'), findsOneWidget);
      expect(find.text('25 min'), findsWidgets);
      expect(find.text('Focus time per hour'), findsOneWidget);
      expect(tester.widget<BarChart>(find.byType(BarChart)).bars, hasLength(24));
      expect(find.byType(HeatmapChart), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget, reason: 'top tasks');
      expect(find.text('Completed tasks took 83% of their target (median).'), findsOneWidget);
      expect(find.text('Not tracked yet'), findsOneWidget, reason: 'interruptions come with #28');
    });
  });

  testWidgets('period navigation changes the range label and the data', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      // en_US weeks start on Sunday.
      expect(_periodLabel(tester), 'Nov 15 – Nov 21, 2026');
      expect(tester.widget<BarChart>(find.byType(BarChart)).bars.map((bar) => bar.label), ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
      expect(find.byTooltip('Go to current period'), findsNothing);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), 'Nov 8 – Nov 14, 2026');
      expect(find.text('No data for this period'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), 'Nov 1 – Nov 7, 2026');
      expect(find.text('0/1 task completed'), findsOneWidget, reason: 'the old task is planned in that week');

      await tester.tap(find.byTooltip('Go to current period'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), 'Nov 15 – Nov 21, 2026');

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), 'November 2026');
      expect(find.text('1/2 tasks completed'), findsOneWidget);
      expect(tester.widget<BarChart>(find.byType(BarChart)).bars, hasLength(30));

      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), '2026');
      expect(find.text('Focus time per month'), findsOneWidget);

      await tester.tap(find.byTooltip('Next period'));
      await tester.pumpAndSettle();
      expect(_periodLabel(tester), '2027');
      expect(find.text('No data for this period'), findsOneWidget);
    });
  });

  testWidgets('shows the empty state without data', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Next period'));
      await tester.pumpAndSettle();

      expect(_periodLabel(tester), 'Thu, Nov 19, 2026');
      expect(find.text('No data for this period'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });
  });

  testWidgets('tapping a bar shows its value', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      // Wednesday is the 4th of 7 bars.
      final chart = tester.getRect(find.byKey(const Key('statsFocusChart')));
      await tester.tapAt(Offset(chart.left + chart.width * 3.5 / 7, chart.bottom - 30));
      await tester.pumpAndSettle();

      expect(find.text('Wed, Nov 18: 25 min'), findsOneWidget);
    });
  });

  testWidgets('fits a 360 px phone and updates when focus time is added', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      final repository = await _pump(tester, size: const Size(360, 740));
      expect(tester.takeException(), isNull);

      await repository.addManualTime(taskId: 1, day: _now, duration: const Duration(minutes: 40));
      await tester.pumpAndSettle();

      expect(find.text('1 h 5 min'), findsWidgets);
    });
  });

  test('statsReportProvider caches per query', () async {
    final repository = FakeTaskRepository();
    final container = ProviderContainer.test(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final today = DateTime(2026, 11, 17);
    StatsQuery query(DateTime end) => StatsQuery(range: DateRange(today, end), granularity: StatsGranularity.hour);

    expect(statsReportProvider(query(today)), statsReportProvider(query(today.add(const Duration(hours: 5)))));
    container.listen(statsReportProvider(query(today)), (_, _) {});
    final report = await container.read(statsReportProvider(query(today)).future);
    expect(report.isEmpty, isTrue);
  });

  testWidgets('with a daily goal: a goal line per day and the streak cards', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester, goal: const FocusGoal(daily: Duration(minutes: 20)));

      expect(find.byKey(const Key('statsCurrentStreak')), findsOneWidget);
      expect(find.text('Goal days in 2026'), findsOneWidget);
      expect(tester.widget<BarChart>(find.byKey(const Key('statsFocusChart'))).referenceValue, isNull, reason: 'no goal line per hour');

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(tester.widget<BarChart>(find.byKey(const Key('statsFocusChart'))).referenceValue, 20);
    });
  });
}
