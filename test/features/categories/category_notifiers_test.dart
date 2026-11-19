import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/goals/domain/focus_goal.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/task_builders.dart';

const _work = TaskCategory(id: 1, name: 'Work', colorIndex: 0, sortOrder: 'a0');
const _study = TaskCategory(id: 2, name: 'Study', colorIndex: 1, sortOrder: 'a1');

Future<ProviderContainer> _container(FakeTaskRepository repository, {Map<String, Object> preferences = const {}}) async {
  final container = ProviderContainer.test(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(await fakePreferences(preferences)),
      targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    ],
  );
  container.listen(categoriesNotifierProvider, (_, _) {});
  container.listen(planModeNotifierProvider, (_, _) {});
  await pumpEventQueue();
  return container;
}

void main() {
  final today = DateTime.now().dateOnly;

  group('CategoriesNotifier', () {
    test('lists categories; active and archived ones apart', () async {
      final repository = FakeTaskRepository(categories: [_work, _study.copyWith(archived: true)]);
      final container = await _container(repository);

      final state = container.read(categoriesNotifierProvider);
      expect(state.active.map((category) => category.name), ['Work']);
      expect(state.archived.map((category) => category.name), ['Study']);
      expect(state.byId(2)?.name, 'Study');
      expect(state.byId(null), isNull);
    });

    test('new categories get the first unused colour', () async {
      final repository = FakeTaskRepository(categories: [_work, _study]);
      final container = await _container(repository);

      expect(container.read(categoriesNotifierProvider.notifier).nextColorIndex, 2);
    });

    test('reorder moves a category and keeps the order', () async {
      final repository = FakeTaskRepository(
        categories: [
          _work,
          _study,
          const TaskCategory(id: 3, name: 'Home', colorIndex: 2, sortOrder: 'a2'),
        ],
      );
      final container = await _container(repository);

      await container.read(categoriesNotifierProvider.notifier).reorder(2, 0);
      await pumpEventQueue();

      expect(container.read(categoriesNotifierProvider).active.map((category) => category.name), ['Home', 'Work', 'Study']);
      expect(repository.categories.map((category) => category.name), ['Home', 'Work', 'Study']);
    });

    test('deleting a category leaves its tasks uncategorised', () async {
      final repository = FakeTaskRepository(
        categories: [_work],
        tasks: [buildTask(id: 1, assignedDate: today, categoryId: 1)],
      );
      final container = await _container(repository);

      await container.read(categoriesNotifierProvider.notifier).delete(_work);
      await pumpEventQueue();

      expect(repository.task(1).categoryId, isNull);
      expect(container.read(categoriesNotifierProvider).all, isEmpty);
    });
  });

  group('PlanModeNotifier with categories', () {
    List<String> titles(Iterable<TaskEntity> tasks) => [for (final task in tasks) task.title];

    test('the filter shows one category; archiving it shows all again', () async {
      final repository = FakeTaskRepository(
        categories: [_work, _study],
        tasks: [
          buildTask(id: 1, title: 'Report', assignedDate: today, sortOrder: 'a0', categoryId: 1),
          buildTask(id: 2, title: 'Exam', assignedDate: today, sortOrder: 'a1', categoryId: 2),
          buildTask(id: 3, title: 'Groceries', assignedDate: today, sortOrder: 'a2'),
        ],
      );
      final container = await _container(repository);
      final notifier = container.read(planModeNotifierProvider.notifier);

      expect(titles(container.read(planModeNotifierProvider).visibleTasks), ['Report', 'Exam', 'Groceries']);
      notifier.setCategoryFilter(2);
      expect(titles(container.read(planModeNotifierProvider).visibleTasks), ['Exam']);

      await container.read(categoriesNotifierProvider.notifier).setArchived(_study, archived: true);
      await pumpEventQueue();
      expect(container.read(planModeNotifierProvider).categoryFilter, isNull);
    });

    test('reordering with a filter moves the task between its visible neighbours', () async {
      final repository = FakeTaskRepository(
        categories: [_work],
        tasks: [
          buildTask(id: 1, title: 'A', assignedDate: today, sortOrder: 'a0', categoryId: 1),
          buildTask(id: 2, title: 'other', assignedDate: today, sortOrder: 'a1'),
          buildTask(id: 3, title: 'B', assignedDate: today, sortOrder: 'a2', categoryId: 1),
        ],
      );
      final container = await _container(repository);
      final notifier = container.read(planModeNotifierProvider.notifier);
      notifier.setCategoryFilter(1);

      await notifier.reorderTask(1, 0);
      await pumpEventQueue();

      expect(titles(container.read(planModeNotifierProvider).visibleTasks), ['B', 'A']);
      expect(titles(repository.tasks), ['B', 'A', 'other']);
    });

    test('board groups: active categories (also empty), archived ones with tasks, then no category', () async {
      final archived = const TaskCategory(id: 3, name: 'Old', colorIndex: 2, sortOrder: 'a2', archived: true);
      final unused = const TaskCategory(id: 4, name: 'Unused', colorIndex: 3, sortOrder: 'a3', archived: true);
      final repository = FakeTaskRepository(
        categories: [_work, _study, archived, unused],
        tasks: [
          buildTask(id: 1, title: 'Report', assignedDate: today, sortOrder: 'a0', categoryId: 1),
          buildTask(id: 2, title: 'Legacy', assignedDate: today, sortOrder: 'a1', categoryId: 3),
          buildTask(id: 3, title: 'Groceries', assignedDate: today, sortOrder: 'a2', isCompleted: true),
        ],
      );
      final container = await _container(repository);

      final groups = container.read(planModeNotifierProvider).boardGroups(container.read(categoriesNotifierProvider).all);

      expect(
        [for (final group in groups) (group.category?.name, titles(group.tasks).join(', '), group.openCount)],
        [('Work', 'Report', 1), ('Study', '', 0), ('Old', 'Legacy', 1), (null, 'Groceries', 0)],
      );
    });

    test('moving a task to another group changes its category', () async {
      final repository = FakeTaskRepository(
        categories: [_work],
        tasks: [buildTask(id: 1, assignedDate: today)],
      );
      final container = await _container(repository);
      final notifier = container.read(planModeNotifierProvider.notifier);

      await notifier.setTaskCategory(container.read(planModeNotifierProvider).tasks.single, 1);
      expect(repository.task(1).categoryId, 1);

      await notifier.setTaskCategory(container.read(planModeNotifierProvider).tasks.single, null);
      expect(repository.task(1).categoryId, isNull);
    });

    test('the view is remembered', () async {
      final repository = FakeTaskRepository();
      final container = await _container(repository);
      await container.read(planModeNotifierProvider.notifier).setView(PlanView.board);

      final restarted = await _container(repository, preferences: {PlanModeNotifier.viewKey: 'board'});
      expect(restarted.read(planModeNotifierProvider).view, PlanView.board);
      expect(container.read(sharedPreferencesProvider).getString(PlanModeNotifier.viewKey), 'board');
    });

    test('saving the form stores the category; copies keep it', () async {
      final repository = FakeTaskRepository(categories: [_work]);
      final container = await _container(repository);
      final notifier = container.read(planModeNotifierProvider.notifier);

      await notifier.saveDraft(TaskDraft.empty(today, categoryId: 1).copyWith(title: 'Report'));
      expect(repository.tasks.single.categoryId, 1);

      await notifier.duplicateTaskToDate(task: repository.tasks.single, date: today.addDays(1), keepTodoCompletion: false, subtractTimeSpent: false);
      expect(repository.tasks.map((task) => task.categoryId), [1, 1]);

      await notifier.saveDraft(TaskDraft.fromTask(repository.task(1)).copyWith(clearCategory: true), id: 1);
      expect(repository.task(1).categoryId, isNull);
    });
  });

  test('category focus queues only the open tasks of that category', () {
    fakeAsync((async) {
      final day = DateTime(2026, 11, 17);
      final repository = FakeTaskRepository(
        categories: [_work, _study],
        tasks: [
          buildTask(id: 1, title: 'Report', assignedDate: day, sortOrder: 'a0', categoryId: 1),
          buildTask(id: 2, title: 'Exam', assignedDate: day, sortOrder: 'a1', categoryId: 2),
          buildTask(id: 3, title: 'Slides', assignedDate: day, sortOrder: 'a2', categoryId: 1),
          buildTask(id: 4, title: 'Done', assignedDate: day, sortOrder: 'a3', categoryId: 1, isCompleted: true),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(repository),
          targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
          notificationServiceProvider.overrideWithValue(FakeNotificationService()),
          focusGoalProvider.overrideWithValue(FocusGoal.off),
          appLocalizationsProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
        ],
      );
      final notifier = container.read(focusModeNotifierProvider.notifier);

      notifier.start(FocusRequest(day, categoryId: 1, startTaskId: 3));
      async.flushMicrotasks();

      expect(notifier.state.queue.map((task) => task.title), ['Slides', 'Report']);
      expect(notifier.state.currentTask?.title, 'Slides');
      notifier.exitFocus();
      async.flushMicrotasks();
      container.dispose();
    }, initialTime: DateTime(2026, 11, 17, 9));
  });
}
