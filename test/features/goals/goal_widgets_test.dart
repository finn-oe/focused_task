import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/ui/charts/bar_chart.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/goals/presentation/goal_progress_ring.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/finished_for_today_screen.dart';
import 'package:focused_task/features/tasks/presentation/stats/widgets/stats_cards.dart';

import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

// Wednesday, 18 Nov 2026, 15:00.
final _now = DateTime(2026, 11, 18, 15);
final _today = DateTime(2026, 11, 18);
const _goal = FocusGoal(daily: Duration(hours: 1));

Future<void> _pump(WidgetTester tester, Widget child, {FocusGoal goal = _goal, FakeTaskRepository? repository, double width = 800}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeTaskRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        focusSessionRepositoryProvider.overrideWithValue(repo),
        categoryRepositoryProvider.overrideWithValue(repo),
        inboxRepositoryProvider.overrideWithValue(repo),
        focusGoalProvider.overrideWithValue(goal),
      ],
      child: localizedApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

GoalStatus _status(Map<DateTime, Duration> focus, {FocusGoal goal = _goal}) => GoalStatus.from(focus, goal, _now);

void main() {
  group('GoalProgressRing', () {
    testWidgets('fills with the progress and shows a check mark once reached', (tester) async {
      await _pump(tester, const GoalProgressRing(progress: 0.25, reached: false));
      expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 0.25);
      expect(find.byIcon(Icons.check), findsNothing);

      await _pump(tester, const GoalProgressRing(progress: 1, reached: true));
      expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 1);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('TodayGoalRing shows today\'s focus vs. the goal, and nothing without a goal', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        final repository = FakeTaskRepository(tasks: [buildTask(id: 1, assignedDate: _today)]);
        await repository.addManualTime(taskId: 1, day: _today, duration: const Duration(minutes: 15));

        await _pump(tester, const TodayGoalRing(), repository: repository);
        expect(find.byTooltip('Today’s focus: 15 min of 1 h'), findsOneWidget);
        expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 0.25);

        await repository.addManualTime(taskId: 1, day: _today, duration: const Duration(minutes: 45));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Daily goal reached: 1 h of 1 h'), findsOneWidget, reason: 'updates while focus time is added');
        expect(find.byIcon(Icons.check), findsOneWidget);

        await _pump(tester, const TodayGoalRing(), repository: repository, goal: FocusGoal.off);
        expect(find.byKey(const Key('planGoalRing')), findsNothing);
      });
    });
  });

  group('TodaySummaryCard', () {
    testWidgets('shows focus time, tasks done, goal reached and the streak', (tester) async {
      // Monday and Tuesday reached, Wednesday (today) too.
      final status = _status({_today.addDays(-2): const Duration(hours: 1), _today.addDays(-1): const Duration(hours: 1), _today: const Duration(minutes: 70)});
      await _pump(tester, TodaySummaryCard(focus: const Duration(minutes: 70), tasksDone: 3, goal: status), width: 360);

      expect(find.text('1 h 10 min'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byKey(const Key('finishedGoalReached')), findsOneWidget);
      expect(find.text('Reached (1 h)'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
    });

    testWidgets('a missed goal shows how far it got; without a goal there is no goal row', (tester) async {
      await _pump(tester, TodaySummaryCard(focus: const Duration(minutes: 25), tasksDone: 1, goal: _status({_today: const Duration(minutes: 25)})), width: 360);
      expect(find.text('Not reached (25 min of 1 h)'), findsOneWidget);
      expect(find.text('0 days'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'fits 360 px');

      await _pump(tester, const TodaySummaryCard(focus: Duration(minutes: 25), tasksDone: 1));
      expect(find.text('Daily goal'), findsNothing);
      expect(find.text('Streak'), findsNothing);
    });

    testWidgets('the finished-for-today screen shows the summary of today', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        final repository = FakeTaskRepository(
          tasks: [
            buildTask(id: 1, assignedDate: _today, isCompleted: true),
            buildTask(id: 2, assignedDate: _today, isCompleted: true, sortOrder: 'a1'),
          ],
        );
        await repository.addManualTime(taskId: 1, day: _today, duration: const Duration(minutes: 30));
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(repository),
              focusSessionRepositoryProvider.overrideWithValue(repository),
              categoryRepositoryProvider.overrideWithValue(repository),
              inboxRepositoryProvider.overrideWithValue(repository),
              focusGoalProvider.overrideWithValue(_goal),
            ],
            child: localizedApp(home: const FinishedForTodayScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('30 min'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Not reached (30 min of 1 h)'), findsOneWidget);
      });
    });
  });

  group('StreakCards', () {
    testWidgets('current and longest streak, and goal days per month', (tester) async {
      final focus = {
        DateTime(2026, 11, 9): const Duration(hours: 1), // Mon
        DateTime(2026, 11, 10): const Duration(hours: 1),
        DateTime(2026, 11, 11): const Duration(hours: 1),
        // Thu 12 missed.
        DateTime(2026, 11, 16): const Duration(hours: 1),
        DateTime(2026, 11, 17): const Duration(hours: 1),
      };
      await _pump(tester, StreakCards(status: _status(focus), year: 2026));

      expect(find.descendant(of: find.byKey(const Key('statsCurrentStreak')), matching: find.text('2 days')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('statsLongestStreak')), matching: find.text('3 days')), findsOneWidget);
      expect(find.text('Working days with 1 h of focus'), findsNWidgets(2));
      expect(find.text('Goal days in 2026'), findsOneWidget);
      final bars = tester.widget<BarChart>(find.byKey(const Key('statsGoalDaysChart'))).bars;
      expect(bars.map((bar) => bar.value), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0]);
      expect(bars[10].highlighted, isTrue);
      expect(bars[10].tooltip, 'November 2026: 5 goal days');
    });

    testWidgets('without a goal: a hint to set one', (tester) async {
      await _pump(tester, StreakCards(status: _status(const {}, goal: FocusGoal.off), year: 2026));
      expect(find.text('Set a daily focus goal in the settings to see your streaks.'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });
  });

  testWidgets('settings: choose a daily goal and the working days', (tester) async {
    final repository = FakeTaskRepository();
    final container = ProviderContainer.test(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
      ],
    );
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(focusGoalProvider), FocusGoal.off);
    await tester.tap(find.byKey(const Key('settingsDailyGoal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 h').last);
    await tester.pumpAndSettle();
    expect(container.read(focusGoalProvider).daily, const Duration(hours: 2));

    // Mon–Fri by default; add Saturday.
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Sat')).selected, isFalse);
    await tester.tap(find.widgetWithText(FilterChip, 'Sat'));
    await tester.pumpAndSettle();
    expect(container.read(focusGoalProvider).workingDays, {...FocusGoal.defaultWorkingDays, DateTime.saturday});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('settings.daily_goal_minutes'), 120);
    expect(prefs.getStringList('settings.working_days'), ['1', '2', '3', '4', '5', '6']);
    expect(tester.takeException(), isNull, reason: 'fits 360 px');
  });

  test('settings: the goal survives a restart, and the last working day stays', () async {
    final repository = FakeTaskRepository();
    final container = ProviderContainer.test(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(
          await fakePreferences({
            'settings.daily_goal_minutes': 90,
            'settings.working_days': ['3'],
          }),
        ),
      ],
    );
    expect(container.read(focusGoalProvider), const FocusGoal(daily: Duration(minutes: 90), workingDays: {DateTime.wednesday}));

    await container.read(settingsNotifierProvider.notifier).setWorkingDay(DateTime.wednesday, false);
    expect(container.read(focusGoalProvider).workingDays, {DateTime.wednesday});

    await container.read(settingsNotifierProvider.notifier).setDailyGoal(null);
    expect(container.read(focusGoalProvider).isEnabled, isFalse);
    expect((await SharedPreferences.getInstance()).containsKey('settings.daily_goal_minutes'), isFalse);
  });
}
