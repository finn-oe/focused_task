import 'package:drift/drift.dart';

/// Task categories (#2). [color] is an index into the fixed category palette (`lib/core/ui/category_palette.dart`),
/// never a raw colour, so categories look right in light and dark mode.
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  IntColumn get color => integer()();

  /// Reserved for an icon name; not used by the UI yet.
  TextColumn get icon => text().nullable()();

  TextColumn get sortOrder => text().named('sort_order')();

  /// Archived categories are hidden from pickers, filters and the board, but tasks keep them.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}
