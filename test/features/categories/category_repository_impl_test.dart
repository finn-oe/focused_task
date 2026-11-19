import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/categories/data/category_repository_impl.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';

void main() {
  late AppDatabase database;
  late CategoryRepositoryImpl categories;
  late TaskRepositoryImpl tasks;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepositoryImpl(database);
    tasks = TaskRepositoryImpl(database);
  });
  tearDown(() => database.close());

  test('new categories go after the existing ones', () async {
    await categories.createCategory(name: 'Work', colorIndex: 0);
    await categories.createCategory(name: ' Study ', colorIndex: 4);

    final all = await categories.watchCategories().first;
    expect(all.map((category) => (category.name, category.colorIndex, category.archived)), [('Work', 0, false), ('Study', 4, false)]);
  });

  test('names are unique, ignoring case', () async {
    final work = await categories.createCategory(name: 'Work', colorIndex: 0);
    final study = await categories.createCategory(name: 'Study', colorIndex: 1);

    expect(() => categories.createCategory(name: 'work', colorIndex: 2), throwsA(isA<DuplicateCategoryNameException>()));
    final all = await categories.watchCategories().first;
    final studyCategory = all.firstWhere((category) => category.id == study);
    expect(() => categories.updateCategory(studyCategory.copyWith(name: 'WORK')), throwsA(isA<DuplicateCategoryNameException>()));

    // Renaming to the own name with another case is fine.
    await categories.updateCategory(all.firstWhere((category) => category.id == work).copyWith(name: 'WORK'));
    expect((await categories.watchCategories().first).first.name, 'WORK');
  });

  test('rename, colour, archive and reorder', () async {
    final work = await categories.createCategory(name: 'Work', colorIndex: 0);
    final study = await categories.createCategory(name: 'Study', colorIndex: 1);
    var all = await categories.watchCategories().first;

    await categories.updateCategory(all.first.copyWith(name: 'Job', colorIndex: 7, archived: true));
    await categories.updateCategoryOrder(categoryId: work, sortOrder: 'b0');

    all = await categories.watchCategories().first;
    expect(all.map((category) => (category.id, category.name, category.colorIndex, category.archived)), [(study, 'Study', 1, false), (work, 'Job', 7, true)]);
  });

  test('a task keeps its category through create, update and the stats; deleting the category uncategorises it', () async {
    final day = DateTime(2026, 11, 17);
    final work = await categories.createCategory(name: 'Work', colorIndex: 0);
    final id = await tasks.createTask(title: 'Report', assignedDate: day, sortOrder: 'a0', categoryId: work);
    final other = await tasks.createTask(title: 'Groceries', assignedDate: day, sortOrder: 'a1');
    expect((await tasks.getTaskById(id))!.categoryId, work);

    await FocusSessionRepositoryImpl(database).addManualTime(taskId: id, day: day, duration: const Duration(minutes: 40));
    await FocusSessionRepositoryImpl(database).addManualTime(taskId: other, day: day, duration: const Duration(minutes: 10));
    final stats = await tasks.getStatsReport(StatsQuery(range: DateRange(day, day), granularity: StatsGranularity.day));
    expect(stats.focusByCategory.map((entry) => (entry.categoryId, entry.focus)), [(work, const Duration(minutes: 40)), (null, const Duration(minutes: 10))]);

    await tasks.updateTaskDetails(taskId: id, title: 'Report', categoryId: null);
    expect((await tasks.getTaskById(id))!.categoryId, isNull);
    await categories.setTaskCategory(taskId: id, categoryId: work);
    expect((await tasks.getTaskById(id))!.categoryId, work);

    await categories.deleteCategory(work);

    final task = (await tasks.getTaskById(id))!;
    expect((task.title, task.categoryId, task.timeSpent), ('Report', null, const Duration(minutes: 40).inMilliseconds));
    expect(await categories.watchCategories().first, isEmpty);
  });
}
