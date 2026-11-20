import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../../../helpers/fake_notification_service.dart';
import '../../../../helpers/fake_preferences.dart';
import '../../../../helpers/fake_target_alarm.dart';
import '../../../../helpers/fake_task_repository.dart';
import '../../../../helpers/localized_app.dart';
import '../../../../helpers/task_builders.dart';

/// "Collapse completed tasks" (#58).
const _collapseKey = 'settings.collapse_completed';
const _work = TaskCategory(id: 1, name: 'Work', colorIndex: 0, sortOrder: 'a0');

List<String> _titles(List<TaskEntity> tasks) => [for (final task in tasks) task.title];

List<Override> _overrides(FakeTaskRepository repository, SharedPreferences preferences) => [
  taskRepositoryProvider.overrideWithValue(repository),
  focusSessionRepositoryProvider.overrideWithValue(repository),
  categoryRepositoryProvider.overrideWithValue(repository),
  recurrenceRepositoryProvider.overrideWithValue(repository),
  inboxRepositoryProvider.overrideWithValue(repository),
  sharedPreferencesProvider.overrideWithValue(preferences),
  targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
  notificationServiceProvider.overrideWithValue(FakeNotificationService()),
  focusGoalProvider.overrideWithValue(FocusGoal.off),
];

void main() {
  final today = DateTime.now().dateOnly;

  /// A, B, C open, X and Y done – interleaved in plan order.
  FakeTaskRepository mixedDay() => FakeTaskRepository(
    categories: [_work],
    tasks: [
      buildTask(id: 1, title: 'A', assignedDate: today, sortOrder: 'a0', categoryId: 1),
      buildTask(id: 2, title: 'X', assignedDate: today, sortOrder: 'a1', isCompleted: true, categoryId: 1),
      buildTask(id: 3, title: 'B', assignedDate: today, sortOrder: 'a2'),
      buildTask(id: 4, title: 'Y', assignedDate: today, sortOrder: 'a3', isCompleted: true),
      buildTask(id: 5, title: 'C', assignedDate: today, sortOrder: 'a4', categoryId: 1),
    ],
  );

  Future<ProviderContainer> container(FakeTaskRepository repository, {bool collapse = true}) async {
    final container = ProviderContainer.test(overrides: _overrides(repository, await fakePreferences({_collapseKey: collapse})));
    container.listen(planModeNotifierProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  group('PlanModeNotifier', () {
    test('with the setting off the list is unchanged', () async {
      final plan = await container(mixedDay(), collapse: false);

      final state = plan.read(planModeNotifierProvider);
      expect(_titles(state.listTasks(collapse: false)), ['A', 'X', 'B', 'Y', 'C']);
      expect(state.listCompletedTasks(collapse: false), isEmpty);
    });

    test('with the setting on, open and completed tasks are split and keep their order', () async {
      final plan = await container(mixedDay());

      final state = plan.read(planModeNotifierProvider);
      expect(_titles(state.listTasks(collapse: true)), ['A', 'B', 'C']);
      expect(_titles(state.listCompletedTasks(collapse: true)), ['X', 'Y']);
      expect(state.listCompletedExpanded, isFalse, reason: 'collapsed by default');
    });

    test('the split follows the category filter', () async {
      final plan = await container(mixedDay());
      plan.read(planModeNotifierProvider.notifier).setCategoryFilter(1);

      final state = plan.read(planModeNotifierProvider);
      expect(_titles(state.listTasks(collapse: true)), ['A', 'C']);
      expect(_titles(state.listCompletedTasks(collapse: true)), ['X']);
    });

    test('toggling the sections; the state survives a day change', () async {
      final plan = await container(mixedDay());
      final notifier = plan.read(planModeNotifierProvider.notifier);

      notifier.toggleListCompleted();
      notifier.toggleBoardGroupCompleted(null);
      notifier.toggleBoardGroupCompleted(1);
      notifier.toggleBoardGroupCompleted(1);
      await notifier.setSelectedDay(today.addDays(1));

      final state = plan.read(planModeNotifierProvider);
      expect(state.listCompletedExpanded, isTrue);
      expect(state.expandedBoardGroups, {null});
    });

    test('switching the setting keeps the shown day (the plan is not rebuilt)', () async {
      final plan = await container(mixedDay(), collapse: false);
      final tomorrow = today.addDays(1);
      await plan.read(planModeNotifierProvider.notifier).setSelectedDay(tomorrow);

      await plan.read(settingsNotifierProvider.notifier).setCollapseCompleted(true);

      final state = plan.read(planModeNotifierProvider);
      expect(plan.read(collapseCompletedProvider), isTrue);
      expect(state.selectedDay, tomorrow);
    });

    test('reordering moves an open task between its open neighbours; completed tasks keep their place', () async {
      final repository = mixedDay();
      final plan = await container(repository);

      // C to the top of the open tasks.
      await plan.read(planModeNotifierProvider.notifier).reorderTask(2, 0);
      await pumpEventQueue();

      expect(_titles(plan.read(planModeNotifierProvider).listTasks(collapse: true)), ['C', 'A', 'B']);
      expect(_titles(repository.tasks.where((task) => !task.isCompleted).toList()), ['C', 'A', 'B'], reason: 'the stored order');
      expect(_titles(plan.read(planModeNotifierProvider).listCompletedTasks(collapse: true)), ['X', 'Y']);
    });
  });

  group('Plan screen', () {
    Future<void> pumpPlan(
      WidgetTester tester,
      FakeTaskRepository repository, {
      PlanView view = PlanView.list,
      Size size = const Size(500, 900),
      bool collapse = true,
      String initialLocation = AppRoutes.plan,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createAppRouter(initialLocation: initialLocation);
      addTearDown(router.dispose);
      final preferences = await fakePreferences({_collapseKey: collapse, PlanModeNotifier.rolloverPromptedKey: today.isoDate, PlanModeNotifier.viewKey: view.name});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(repository, preferences),
          child: localizedRouterApp(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the list hides completed tasks in a section that can be opened', (tester) async {
      await pumpPlan(tester, mixedDay());

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Completed (2)'), findsOneWidget);
      expect(find.text('X'), findsNothing);
      expect(find.byTooltip('Show completed tasks'), findsOneWidget);

      await tester.tap(find.text('Completed (2)'));
      await tester.pumpAndSettle();

      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.byTooltip('Hide completed tasks'), findsOneWidget);
      final completedSection = find.byKey(const Key('planCompletedSection'));
      expect(
        find.descendant(of: completedSection, matching: find.byIcon(Icons.drag_handle)),
        findsNothing,
        reason: 'completed tasks are not reorderable',
      );
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3), reason: 'the open tasks keep their handles');
    });

    testWidgets('completing a task moves it into the section; un-completing moves it back', (tester) async {
      final repository = mixedDay();
      await pumpPlan(tester, repository);
      // The round completion toggle at the start of the task's row.
      Finder toggleOf(String title, IconData icon) => find.descendant(of: find.widgetWithText(ListTile, title), matching: find.byIcon(icon));

      await tester.tap(toggleOf('B', Icons.circle_outlined));
      await tester.pumpAndSettle();

      expect(repository.task(3).isCompleted, isTrue);
      expect(find.text('Completed (3)'), findsOneWidget);
      expect(find.text('B'), findsNothing, reason: 'the section is collapsed');

      await tester.tap(find.text('Completed (3)'));
      await tester.pumpAndSettle();
      await tester.tap(toggleOf('B', Icons.check));
      await tester.pumpAndSettle();

      expect(repository.task(3).isCompleted, isFalse);
      expect(find.text('Completed (2)'), findsOneWidget);
      final completedSection = find.byKey(const Key('planCompletedSection'));
      expect(
        find.descendant(of: completedSection, matching: find.text('B')),
        findsNothing,
        reason: 'back with the open tasks',
      );
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('switching the setting in the settings and going back to the plan applies it (regression)', (tester) async {
      // The plan once copied the setting into its state from a listener, which modified a provider during a build.
      await pumpPlan(tester, mixedDay(), collapse: false);
      expect(find.text('X'), findsOneWidget);

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse completed tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Completed (2)'), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets('the board shows a completed section per group', (tester) async {
      await pumpPlan(tester, mixedDay(), view: PlanView.board, size: const Size(400, 900));

      final work = find.byKey(const ValueKey('boardGroup-1'));
      expect(find.descendant(of: work, matching: find.text('A')), findsOneWidget);
      expect(find.descendant(of: work, matching: find.text('X')), findsNothing);
      expect(find.byKey(const ValueKey('boardCompleted-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('boardCompleted-none')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const ValueKey('boardCompleted-1')), matching: find.text('Completed (1)')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: work, matching: find.text('X')), findsOneWidget);
      expect(find.text('Y'), findsNothing, reason: 'the other group stays collapsed');
    });
  });
}
