import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/categories/domain/i_category_repository.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';

class CategoryRepositoryImpl implements ICategoryRepository {
  CategoryRepositoryImpl(this._database);

  final AppDatabase _database;

  static TaskCategory toEntity(CategoryRow row) {
    return TaskCategory(id: row.id, name: row.name, colorIndex: row.color, icon: row.icon, sortOrder: row.sortOrder, archived: row.archived);
  }

  @override
  Stream<List<TaskCategory>> watchCategories() => _database.watchCategories().map((rows) => rows.map(toEntity).toList(growable: false));

  Future<void> _ensureUniqueName(String name, {int? exceptId}) async {
    final taken = (await _database.getCategories()).any((row) => row.id != exceptId && row.name.toLowerCase() == name.toLowerCase());
    if (taken) throw DuplicateCategoryNameException(name);
  }

  @override
  Future<int> createCategory({required String name, required int colorIndex}) async {
    final trimmed = name.trim();
    await _ensureUniqueName(trimmed);
    final existing = await _database.getCategories();
    final sortOrder = FractionalIndexer.between(existing.isEmpty ? null : existing.last.sortOrder, null);
    return _database.createCategory(CategoriesCompanion.insert(name: trimmed, color: colorIndex, sortOrder: sortOrder));
  }

  @override
  Future<void> updateCategory(TaskCategory category) async {
    final name = category.name.trim();
    await _ensureUniqueName(name, exceptId: category.id);
    await _database.updateCategory(category.id, CategoriesCompanion(name: Value(name), color: Value(category.colorIndex), archived: Value(category.archived)));
  }

  @override
  Future<void> updateCategoryOrder({required int categoryId, required String sortOrder}) {
    return _database.updateCategory(categoryId, CategoriesCompanion(sortOrder: Value(sortOrder)));
  }

  @override
  Future<void> deleteCategory(int categoryId) => _database.deleteCategory(categoryId);

  @override
  Future<void> setTaskCategory({required int taskId, required int? categoryId}) => _database.setTaskCategory(taskId: taskId, categoryId: categoryId);
}
