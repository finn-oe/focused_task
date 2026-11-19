import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/features/categories/presentation/widgets/category_dialog.dart';

/// "None", one chip per active category (plus the task's own category if it is archived) and "+ New".
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({super.key, required this.categoryId, required this.onChanged});

  /// `null` = no category.
  final int? categoryId;
  final ValueChanged<int?> onChanged;

  Future<void> _createCategory(BuildContext context) async {
    final id = await showCategoryDialog(context);
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesNotifierProvider);
    final current = categories.byId(categoryId);
    final shown = [...categories.active, if (current != null && current.archived) current];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(label: Text(l10n.taskFormCategoryNone), selected: current == null, onSelected: (_) => onChanged(null)),
        for (final category in shown)
          ChoiceChip(
            avatar: CategoryDot(colorIndex: category.colorIndex),
            label: Text(category.name),
            selected: category.id == current?.id,
            onSelected: (_) => onChanged(category.id),
          ),
        ActionChip(avatar: const Icon(Icons.add), label: Text(l10n.taskFormCategoryNew), onPressed: () => _createCategory(context)),
      ],
    );
  }
}
