import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/categories/domain/i_category_repository.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';

class CategoriesState {
  const CategoriesState({required this.all, required this.isLoading});

  static const initial = CategoriesState(all: [], isLoading: true);

  /// Every category, also archived ones, in their order.
  final List<TaskCategory> all;
  final bool isLoading;

  /// Categories that can be picked, filtered by and shown as board groups.
  List<TaskCategory> get active => all.where((category) => !category.archived).toList(growable: false);

  List<TaskCategory> get archived => all.where((category) => category.archived).toList(growable: false);

  /// The category with [id] (also archived), or `null` (no category, or deleted).
  TaskCategory? byId(int? id) => id == null ? null : all.where((category) => category.id == id).firstOrNull;
}

/// The categories and the actions of the category management screen.
class CategoriesNotifier extends Notifier<CategoriesState> {
  late ICategoryRepository _repository;
  StreamSubscription<List<TaskCategory>>? _subscription;

  @override
  CategoriesState build() {
    _repository = ref.watch(categoryRepositoryProvider);
    _subscription = _repository.watchCategories().listen((categories) => state = CategoriesState(all: categories, isLoading: false));
    ref.onDispose(() => _subscription?.cancel());
    return CategoriesState.initial;
  }

  /// The first palette colour no category uses yet, so new categories look different from the existing ones.
  int get nextColorIndex {
    final used = {for (final category in state.all) category.colorIndex};
    for (var index = 0; index < categoryPaletteSize; index++) {
      if (!used.contains(index)) return index;
    }
    return state.all.length % categoryPaletteSize;
  }

  /// Adds a category and returns its id. Throws [DuplicateCategoryNameException] if the name is taken.
  Future<int> add({required String name, required int colorIndex}) => _repository.createCategory(name: name, colorIndex: colorIndex);

  /// Throws [DuplicateCategoryNameException] if the name is taken.
  Future<void> rename(TaskCategory category, String name) => _repository.updateCategory(category.copyWith(name: name));

  Future<void> setColor(TaskCategory category, int colorIndex) => _repository.updateCategory(category.copyWith(colorIndex: colorIndex));

  Future<void> setArchived(TaskCategory category, {required bool archived}) => _repository.updateCategory(category.copyWith(archived: archived));

  /// Deletes the category; its tasks stay without a category.
  Future<void> delete(TaskCategory category) => _repository.deleteCategory(category.id);

  /// Moves the active category at [oldIndex] to [newIndex] (indexes into [CategoriesState.active], after removal).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final active = [...state.active];
    if (oldIndex < 0 || oldIndex >= active.length) return;
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex.clamp(0, active.length), moved);
    final index = active.indexOf(moved);
    final before = index > 0 ? active[index - 1].sortOrder : null;
    final after = index < active.length - 1 ? active[index + 1].sortOrder : null;
    final sortOrder = FractionalIndexer.between(before, after);

    // Optimistic, so the list doesn't jump back until the database reports the change.
    state = CategoriesState(
      all: [
        ...active.map((category) => category == moved ? category.copyWith(sortOrder: sortOrder) : category),
        ...state.archived,
      ],
      isLoading: false,
    );
    await _repository.updateCategoryOrder(categoryId: moved.id, sortOrder: sortOrder);
  }
}
