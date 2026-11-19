import 'package:focused_task/features/categories/domain/task_category.dart';

abstract class ICategoryRepository {
  /// All categories, also archived ones, in their order.
  Stream<List<TaskCategory>> watchCategories();

  /// Adds a category after the existing ones and returns its id. Throws [DuplicateCategoryNameException] if the name
  /// is taken (ignoring case).
  Future<int> createCategory({required String name, required int colorIndex});

  /// Changes name, colour or archived state. Throws [DuplicateCategoryNameException] if the new name is taken.
  Future<void> updateCategory(TaskCategory category);

  Future<void> updateCategoryOrder({required int categoryId, required String sortOrder});

  /// Deletes the category. Its tasks stay and become uncategorised.
  Future<void> deleteCategory(int categoryId);

  /// Puts a task into [categoryId] (`null` = no category).
  Future<void> setTaskCategory({required int taskId, required int? categoryId});
}
