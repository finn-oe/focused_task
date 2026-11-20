import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/ui/category_palette.dart';
import 'package:focused_task/core/ui/keyboard.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';

/// Creates a category, or edits [category] (name and colour). Returns the category's id, or `null` if cancelled.
Future<int?> showCategoryDialog(BuildContext context, {TaskCategory? category}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _CategoryDialog(category: category),
  );
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});

  final TaskCategory? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.category?.name ?? '');
  late int _colorIndex = widget.category?.colorIndex ?? ref.read(categoriesNotifierProvider.notifier).nextColorIndex;
  bool _nameTaken = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _nameTaken = false);
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(categoriesNotifierProvider.notifier);
    final existing = widget.category;
    setState(() => _saving = true);
    try {
      if (existing == null) {
        final id = await notifier.add(name: _name.text, colorIndex: _colorIndex);
        if (mounted) Navigator.of(context).pop(id);
      } else {
        await notifier.rename(existing.copyWith(colorIndex: _colorIndex), _name.text);
        if (mounted) Navigator.of(context).pop(existing.id);
      }
    } on DuplicateCategoryNameException {
      if (!mounted) return;
      setState(() {
        _nameTaken = true;
        _saving = false;
      });
      _formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.category == null ? l10n.categoriesNewTitle : l10n.categoriesEditTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              onTapOutside: unfocusOnTapOutside,
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.categoriesNameLabel, border: const OutlineInputBorder()),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_nameTaken) setState(() => _nameTaken = false);
              },
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return l10n.categoriesNameRequired;
                if (_nameTaken) return l10n.categoriesNameTaken;
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(l10n.categoriesColor, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CategoryColorPicker(selected: _colorIndex, onChanged: (index) => setState(() => _colorIndex = index)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

/// The ten palette colours as round swatches; the selected one has a check mark.
class CategoryColorPicker extends StatelessWidget {
  const CategoryColorPicker({super.key, required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in CategoryColor.values)
          Semantics(
            label: l10n.categoryColorName(color.name),
            selected: color.index == selected,
            button: true,
            child: InkResponse(
              key: ValueKey('categoryColor-${color.name}'),
              onTap: () => onChanged(color.index),
              radius: 22,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.color(context), shape: BoxShape.circle),
                child: color.index == selected ? Icon(Icons.check, size: 20, color: color.onColor(context)) : null,
              ),
            ),
          ),
      ],
    );
  }
}
