import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/categories/presentation/widgets/category_dialog.dart';

/// Settings → Categories: add, edit (name, colour), reorder, archive, restore and delete categories.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(categoriesNotifierProvider);
    final notifier = ref.read(categoriesNotifierProvider.notifier);
    final active = state.active;
    final archived = state.archived;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        // The plan's add button lives in another branch of the same shell; two default hero tags would clash.
        heroTag: null,
        onPressed: () => showCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.categoriesAdd),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 88), // keep the last row clear of the add button
                  buildDefaultDragHandles: false,
                  itemCount: active.length,
                  onReorderItem: notifier.reorder,
                  header: state.all.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.categoriesEmpty, textAlign: TextAlign.center),
                        )
                      : null,
                  itemBuilder: (context, index) => _CategoryTile(key: ValueKey(active[index].id), category: active[index], index: index),
                  footer: archived.isEmpty ? null : _ArchivedSection(categories: archived),
                ),
              ),
            ),
    );
  }
}

enum _CategoryAction { edit, archive, restore, delete }

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({super.key, required this.category, this.index});

  final TaskCategory category;

  /// Position in the reorderable list; `null` for archived categories (not reorderable).
  final int? index;

  Future<void> _onAction(BuildContext context, WidgetRef ref, _CategoryAction action) async {
    final notifier = ref.read(categoriesNotifierProvider.notifier);
    switch (action) {
      case _CategoryAction.edit:
        await showCategoryDialog(context, category: category);
      case _CategoryAction.archive:
        await notifier.setArchived(category, archived: true);
      case _CategoryAction.restore:
        await notifier.setArchived(category, archived: false);
      case _CategoryAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _DeleteCategoryDialog(category: category),
        );
        if (confirmed == true) await notifier.delete(category);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = this.index;
    return ListTile(
      leading: CategoryDot(colorIndex: category.colorIndex, size: 16),
      title: Text(category.name),
      onTap: () => showCategoryDialog(context, category: category),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<_CategoryAction>(
            tooltip: l10n.categoriesActions,
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              _menuItem(_CategoryAction.edit, Icons.edit_outlined, l10n.categoriesEdit),
              if (category.archived)
                _menuItem(_CategoryAction.restore, Icons.unarchive_outlined, l10n.categoriesRestore)
              else
                _menuItem(_CategoryAction.archive, Icons.archive_outlined, l10n.categoriesArchive),
              _menuItem(_CategoryAction.delete, Icons.delete_outline, l10n.commonDelete),
            ],
          ),
          if (index != null)
            Tooltip(
              message: l10n.categoriesReorderTooltip,
              child: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
            ),
        ],
      ),
    );
  }
}

PopupMenuItem<_CategoryAction> _menuItem(_CategoryAction action, IconData icon, String label) {
  return PopupMenuItem(
    value: action,
    child: ListTile(leading: Icon(icon), title: Text(label), contentPadding: EdgeInsets.zero),
  );
}

class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({required this.categories});

  final List<TaskCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Text(l10n.categoriesArchived, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(l10n.categoriesArchivedHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        for (final category in categories) _CategoryTile(key: ValueKey(category.id), category: category),
      ],
    );
  }
}

class _DeleteCategoryDialog extends StatelessWidget {
  const _DeleteCategoryDialog({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.categoriesDeleteTitle),
      content: Text(l10n.categoriesDeleteMessage(category.name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
