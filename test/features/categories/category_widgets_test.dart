import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/category_picker.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

const _work = TaskCategory(id: 1, name: 'Work', colorIndex: 0, sortOrder: 'a0');
const _study = TaskCategory(id: 2, name: 'Study', colorIndex: 1, sortOrder: 'a1');

Future<GoRouter> _pumpApp(WidgetTester tester, FakeTaskRepository repository, {String initialLocation = AppRoutes.plan, Size size = const Size(1000, 800), PlanView? view}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(
          await fakePreferences({PlanModeNotifier.rolloverPromptedKey: DateTime.now().dateOnly.isoDate, PlanModeNotifier.viewKey: ?view?.name}),
        ),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
        focusGoalProvider.overrideWithValue(FocusGoal.off),
      ],
      child: localizedRouterApp(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.routeInformationProvider.value.uri.toString();

void main() {
  final today = DateTime.now().dateOnly;

  setUp(() {
    // wakelock_plus has no implementation in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  FakeTaskRepository repositoryWithCategories() {
    return FakeTaskRepository(
      categories: [_work, _study],
      tasks: [
        buildTask(id: 1, title: 'Report', assignedDate: today, sortOrder: 'a0', categoryId: 1),
        buildTask(id: 2, title: 'Exam prep', assignedDate: today, sortOrder: 'a1', categoryId: 2),
        buildTask(id: 3, title: 'Slides', assignedDate: today, sortOrder: 'a2', categoryId: 1),
        buildTask(id: 4, title: 'Groceries', assignedDate: today, sortOrder: 'a3'),
      ],
    );
  }

  testWidgets('without categories the list has no filter, no dots and no board toggle', (tester) async {
    await _pumpApp(
      tester,
      FakeTaskRepository(
        tasks: [buildTask(title: 'Report', assignedDate: today)],
      ),
      view: PlanView.board,
    );

    expect(find.text('Report'), findsOneWidget);
    expect(find.byKey(const Key('planCategoryFilter')), findsNothing);
    expect(find.byKey(const Key('planBoard')), findsNothing, reason: 'a stored board view falls back to the list');
    expect(find.byTooltip('Show as board'), findsNothing);
    expect(find.byKey(const ValueKey('taskCategoryDot-1')), findsNothing);
  });

  testWidgets('filter chips show one category; Focus on it queues only its tasks', (tester) async {
    final router = await _pumpApp(tester, repositoryWithCategories());

    expect(find.byKey(const ValueKey('taskCategoryDot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('taskCategoryDot-4')), findsNothing, reason: 'no dot without a category');
    expect(find.text('Focus on Work'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Slides'), findsOneWidget);
    expect(find.text('Exam prep'), findsNothing);
    expect(find.text('Groceries'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus on Work'));
    await tester.pumpAndSettle();

    expect(_location(router), '/focus?day=${today.isoDate}&category=1');
    expect(find.text('Focus: Work'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Slides'), findsOneWidget, reason: 'up next is from the same category');
    expect(find.text('Exam prep'), findsNothing);
  });

  testWidgets('the board groups the tasks by category; dragging a task changes its category', (tester) async {
    final repository = repositoryWithCategories();
    // Wide enough for all four columns side by side.
    await _pumpApp(tester, repository, size: const Size(1800, 800));

    await tester.tap(find.byTooltip('Show as board'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planBoard')), findsOneWidget);

    Finder inGroup(int? id, String title) => find.descendant(of: find.byKey(ValueKey('boardGroup-${id ?? 'none'}')), matching: find.text(title));
    expect(inGroup(1, 'Report'), findsOneWidget);
    expect(inGroup(1, 'Slides'), findsOneWidget);
    expect(inGroup(2, 'Exam prep'), findsOneWidget);
    expect(inGroup(null, 'Groceries'), findsOneWidget);
    expect(inGroup(null, 'No category'), findsOneWidget);

    final handle = find.descendant(
      of: find.ancestor(of: find.text('Groceries'), matching: find.byType(Card)),
      matching: find.byIcon(Icons.drag_indicator),
    );
    final start = tester.getCenter(handle);
    final target = tester.getCenter(find.byKey(const ValueKey('boardGroup-2')));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(start, target, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repository.task(4).categoryId, 2);
    expect(inGroup(2, 'Groceries'), findsOneWidget);
  });

  testWidgets('the board header starts focus on its category', (tester) async {
    final router = await _pumpApp(tester, repositoryWithCategories(), size: const Size(400, 800), view: PlanView.board);

    expect(find.byKey(const Key('planBoard')), findsOneWidget, reason: 'the stored view is used');
    await tester.tap(find.byTooltip('Focus on Study'));
    await tester.pumpAndSettle();

    expect(_location(router), '/focus?day=${today.isoDate}&category=2');
    expect(find.text('Exam prep'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
  });

  testWidgets('the task form picks a category and can create a new one', (tester) async {
    final repository = FakeTaskRepository(categories: [_work]);
    await _pumpApp(tester, repository, size: const Size(800, 1400));

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Report');
    Finder categoryChip(String label) => find.descendant(of: find.byType(CategoryPicker), matching: find.widgetWithText(ChoiceChip, label));
    expect(tester.widget<ChoiceChip>(categoryChip('None')).selected, isTrue);

    await tester.tap(find.widgetWithText(ActionChip, 'New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'work');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('A category with this name already exists.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Study');
    await tester.tap(find.byKey(const ValueKey('categoryColor-green')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(categoryChip('Study')).selected, isTrue);

    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();

    final study = repository.categories.firstWhere((category) => category.name == 'Study');
    expect(study.colorIndex, 3);
    expect(repository.tasks.single.categoryId, study.id);
  });

  testWidgets('Settings → Categories: add, archive and delete with confirmation', (tester) async {
    final repository = FakeTaskRepository(
      categories: [_work],
      tasks: [buildTask(id: 1, title: 'Report', assignedDate: today, categoryId: 1)],
    );
    await _pumpApp(tester, repository, initialLocation: AppRoutes.categories, size: const Size(400, 800));

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Study');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.categories.map((category) => category.name), ['Work', 'Study']);

    await tester.tap(find.byTooltip('Category actions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
    expect(repository.categories.last.archived, isTrue);

    await tester.tap(find.byTooltip('Category actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete category?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.categories, hasLength(2));

    await tester.tap(find.byTooltip('Category actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.categories.map((category) => category.name), ['Study']);
    expect(repository.task(1).categoryId, isNull, reason: 'the task stays, uncategorised');
  });

  testWidgets('statistics show the focus time per category', (tester) async {
    final repository = repositoryWithCategories();
    await repository.addManualTime(taskId: 1, day: today, duration: const Duration(minutes: 40));
    await repository.addManualTime(taskId: 4, day: today, duration: const Duration(minutes: 10));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(repository),
          inboxRepositoryProvider.overrideWithValue(repository),
          focusGoalProvider.overrideWithValue(FocusGoal.off),
        ],
        child: localizedApp(home: const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('statsByCategory'));
    expect(find.descendant(of: card, matching: find.text('Focus time per category')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Work')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('40 min')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('No category')), findsOneWidget);
  });
}
