import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';

/// Recurring tasks in the form, on the plan and in the plan notifier (#24).
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

RecurrenceRule _daily(DateTime start, {String title = 'Stretch'}) => RecurrenceRule(
  title: title,
  pattern: const RepeatPattern(frequency: RepeatFrequency.daily),
  startDate: start,
);

void main() {
  final today = DateTime.now().dateOnly;

  Future<GoRouter> pumpApp(WidgetTester tester, FakeTaskRepository repository, {Size size = const Size(500, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createAppRouter();
    addTearDown(router.dispose);
    final preferences = await fakePreferences({PlanModeNotifier.rolloverPromptedKey: today.isoDate});
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository, preferences),
        child: localizedRouterApp(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openForm(WidgetTester tester, GoRouter router, [TaskEntity? task]) async {
    // ignore: unawaited_futures, the form stays open for the test
    router.push(AppRoutes.taskForm, extra: task);
    await tester.pumpAndSettle();
  }

  Future<void> openRepeat(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byKey(const Key('taskFormRepeat')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('taskFormRepeat')));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  group('plan', () {
    testWidgets('shows the occurrences of the shown day with the recurring icon', (tester) async {
      final repository = FakeTaskRepository();
      await repository.createRule(_daily(today.addDays(-3)));
      await pumpApp(tester, repository);

      expect(find.text('Stretch'), findsOneWidget);
      final task = repository.tasks.single;
      expect((task.occurrenceDate, task.isRecurring), (today, true));
      expect(find.byKey(ValueKey('taskRecurring-${task.id}')), findsOneWidget);
      expect(find.byTooltip('Repeats'), findsOneWidget);
    });
  });

  group('task form', () {
    testWidgets('a new task repeats on weekdays: the summary follows and the task starts the series', (tester) async {
      final repository = FakeTaskRepository();
      final router = await pumpApp(tester, repository, size: const Size(360, 800));
      await openForm(tester, router);
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Standup');

      await openRepeat(tester);
      expect(find.text('Repeat'), findsWidgets);
      await tester.tap(find.byKey(const Key('repeat-weekdays')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('repeatEnds')), findsOneWidget, reason: 'an end date can be set once it repeats');
      await back(tester);

      expect(find.text('Every weekday (Mon–Fri)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('taskFormSaveAction')));
      await tester.pumpAndSettle();

      final rule = repository.rules.values.single;
      expect((rule.title, rule.pattern.frequency, rule.startDate), ('Standup', RepeatFrequency.weekdays, today));
      final first = repository.tasks.firstWhere((task) => task.assignedDate == today);
      expect((first.title, first.recurrenceId, first.occurrenceDate), ('Standup', rule.id, today));
      expect(repository.tasks.where((task) => task.assignedDate == today), hasLength(1), reason: 'the saved task is the first occurrence');
    });

    testWidgets('weekly picks days of the week; every N days has a stepper', (tester) async {
      final router = await pumpApp(tester, FakeTaskRepository(), size: const Size(360, 800));
      await openForm(tester, router);
      await openRepeat(tester);

      await tester.tap(find.byKey(const Key('repeat-weekly')));
      await tester.pumpAndSettle();
      final other = today.weekday == DateTime.monday ? DateTime.tuesday : DateTime.monday;
      await tester.tap(find.byKey(Key('repeatWeekday-$other')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('repeatSummary')), findsOneWidget);
      // The task's own weekday can't be removed when it is the last one.
      await tester.tap(find.byKey(Key('repeatWeekday-$other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('repeatWeekday-${today.weekday}')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(find.byKey(Key('repeatWeekday-${today.weekday}'))).selected, isTrue);

      await tester.tap(find.byKey(const Key('repeat-interval')));
      await tester.pumpAndSettle();
      expect(find.text('Every 2 days'), findsWidgets);
      await tester.tap(find.byKey(const Key('repeatIntervalMore')));
      await tester.pumpAndSettle();
      expect(find.text('Every 3 days'), findsWidgets);
      await back(tester);
      expect(find.text('Every 3 days'), findsOneWidget, reason: 'the form shows the summary');
    });

    testWidgets('editing an occurrence asks: only this keeps the series, this and future replaces it', (tester) async {
      final repository = FakeTaskRepository();
      final ruleId = await repository.createRule(_daily(today));
      await repository.ensureOccurrences(DateRange(today, today.addDays(2)));
      final router = await pumpApp(tester, repository);

      Future<void> rename(String title, Key choice) async {
        final task = repository.tasks.firstWhere((task) => task.assignedDate == today);
        await openForm(tester, router, task);
        await tester.enterText(find.widgetWithText(TextFormField, 'Title'), title);
        await tester.scrollUntilVisible(find.byKey(const Key('taskFormRepeat')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Every day'), findsOneWidget, reason: 'the form loads the repeat of the occurrence');
        await tester.tap(find.byKey(const Key('taskFormSaveAction')));
        await tester.pumpAndSettle();
        expect(find.text('Change recurring task'), findsOneWidget);
        await tester.tap(find.byKey(choice));
        await tester.pumpAndSettle();
      }

      await rename('Stretch more', const Key('repeatScopeOnlyThis'));
      expect(repository.rules.keys, [ruleId]);
      expect(repository.tasks.where((task) => task.title == 'Stretch more'), hasLength(1));

      await rename('Yoga', const Key('repeatScopeFuture'));
      final next = repository.rules.values.firstWhere((rule) => rule.id != ruleId);
      expect((next.title, next.startDate), ('Yoga', today));
      expect(repository.rules.containsKey(ruleId), isFalse, reason: 'the old rule started today, so it is gone');
      await repository.ensureOccurrences(DateRange(today, today.addDays(2)));
      expect(repository.tasks.where((task) => task.assignedDate == today.addDays(2)).single.title, 'Yoga');
    });

    testWidgets('deleting an occurrence: only this leaves the others, this and future ends the series', (tester) async {
      final repository = FakeTaskRepository();
      final ruleId = await repository.createRule(_daily(today.addDays(-2)));
      await repository.ensureOccurrences(DateRange(today, today.addDays(2)));
      final router = await pumpApp(tester, repository);

      Future<void> delete(DateTime day, Key choice) async {
        await openForm(tester, router, repository.tasks.firstWhere((task) => task.assignedDate == day));
        await tester.tap(find.byTooltip('Delete Task'));
        await tester.pumpAndSettle();
        expect(find.text('Delete recurring task'), findsOneWidget);
        await tester.tap(find.byKey(choice));
        await tester.pumpAndSettle();
      }

      await delete(today, const Key('repeatDeleteOnlyThis'));
      expect(repository.exceptions, {(ruleId, today)});
      await repository.ensureOccurrences(DateRange(today, today));
      expect(repository.tasks.where((task) => task.assignedDate == today), isEmpty, reason: 'deleted occurrences stay deleted');

      await delete(today.addDays(1), const Key('repeatDeleteFuture'));
      expect(repository.tasks, isEmpty);
      expect(repository.rules[ruleId]!.pattern.endDate, today);
    });
  });

  group('plan notifier', () {
    late FakeTaskRepository repository;
    late ProviderContainer container;

    setUp(() async {
      repository = FakeTaskRepository();
      container = ProviderContainer.test(overrides: _overrides(repository, await fakePreferences()));
    });

    PlanModeNotifier notifier() => container.read(planModeNotifierProvider.notifier);

    test('a one-off task that gets a repeat starts the series on its day', () async {
      await notifier().saveDraft(TaskDraft.empty(today).copyWith(title: 'Read'));
      final task = repository.tasks.single;
      const weekly = RepeatPattern(frequency: RepeatFrequency.weekly, weekdays: {DateTime.saturday});
      await notifier().saveDraft(TaskDraft.fromTask(task).copyWith(repeat: weekly), id: task.id);

      final rule = repository.rules.values.single;
      expect((rule.startDate, rule.pattern), (today, weekly));
      expect((repository.task(task.id).recurrenceId, repository.task(task.id).occurrenceDate), (rule.id, today));
      expect(await notifier().repeatOf(repository.task(task.id)), weekly);
    });

    test('a changed repeat applies to this and the following occurrences without asking', () async {
      final ruleId = await repository.createRule(_daily(today.addDays(-1)));
      await repository.ensureOccurrences(DateRange(today, today.addDays(3)));
      final task = repository.tasks.firstWhere((task) => task.assignedDate == today.addDays(1));
      const every3 = RepeatPattern(frequency: RepeatFrequency.interval, intervalDays: 3);

      await notifier().saveDraft(TaskDraft.fromTask(task).copyWith(repeat: every3), id: task.id);
      expect(repository.rules[ruleId]!.pattern.endDate, today);
      final next = repository.rules.values.firstWhere((rule) => rule.id != ruleId);
      expect((next.startDate, next.pattern), (today.addDays(1), every3));
      expect(repository.task(task.id).recurrenceId, next.id);
    });

    test('"Never" on an occurrence ends the series there and keeps the task as a one-off', () async {
      final ruleId = await repository.createRule(_daily(today.addDays(-1)));
      await repository.ensureOccurrences(DateRange(today, today.addDays(3)));
      final task = repository.tasks.firstWhere((task) => task.assignedDate == today);

      await notifier().saveDraft(TaskDraft.fromTask(task), id: task.id, scope: RepeatScope.thisAndFuture);
      expect(repository.rules[ruleId]!.pattern.endDate, today.addDays(-1));
      expect(repository.task(task.id).isRecurring, isFalse);
      expect(repository.tasks, hasLength(1), reason: 'the untouched later occurrences are removed');
    });

    test('duplicating a recurring task makes a one-off copy', () async {
      await notifier().duplicateDraft(
        TaskDraft.empty(today).copyWith(
          title: 'Copy',
          repeat: const RepeatPattern(frequency: RepeatFrequency.daily),
        ),
      );
      expect(repository.rules, isEmpty);
      expect(repository.tasks.single.isRecurring, isFalse);
    });

    test('showing a day creates its occurrences', () async {
      await repository.createRule(_daily(today));
      container.read(planModeNotifierProvider);
      await notifier().setSelectedDay(today.addDays(5));
      await Future<void>.delayed(Duration.zero);
      expect(repository.ensuredRanges, containsAll([DateRange(today, today), DateRange(today.addDays(5), today.addDays(5))]));
      expect(repository.tasks.map((task) => task.assignedDate), containsAll([today, today.addDays(5)]));
    });
  });
}
