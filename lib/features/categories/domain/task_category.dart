/// A category tasks can belong to (#2), e.g. "Work" or "Study".
class TaskCategory {
  const TaskCategory({required this.id, required this.name, required this.colorIndex, required this.sortOrder, this.icon, this.archived = false});

  final int id;
  final String name;

  /// Index into the fixed category palette (`categoryPaletteSize` colours).
  final int colorIndex;

  /// Reserved for an icon name; not used by the UI yet.
  final String? icon;
  final String sortOrder;

  /// Archived categories are hidden from pickers, filters and the board; their tasks keep them.
  final bool archived;

  TaskCategory copyWith({String? name, int? colorIndex, String? sortOrder, bool? archived}) {
    return TaskCategory(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      icon: icon,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskCategory &&
      other.id == id &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.icon == icon &&
      other.sortOrder == sortOrder &&
      other.archived == archived;

  @override
  int get hashCode => Object.hash(id, name, colorIndex, icon, sortOrder, archived);
}

/// Number of colours in the category palette; stored colour indexes are `0 … categoryPaletteSize - 1`.
const categoryPaletteSize = 10;

/// Thrown when a category name is already taken (names are unique, ignoring case).
class DuplicateCategoryNameException implements Exception {
  const DuplicateCategoryNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateCategoryNameException($name)';
}
