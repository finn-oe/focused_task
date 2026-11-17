import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Inline sub-task list: type and press Enter to add (focus stays), edit in place, swipe or tap the bin to delete,
/// drag to reorder. Reports every change through [onChanged].
class SubTaskEditor extends StatefulWidget {
  const SubTaskEditor({super.key, required this.initialTodos, required this.onChanged});

  final List<TaskTodoEntity> initialTodos;
  final ValueChanged<List<TaskTodoEntity>> onChanged;

  @override
  State<SubTaskEditor> createState() => _SubTaskEditorState();
}

class _Row {
  _Row(this.todo);

  final Key key = UniqueKey();
  TaskTodoEntity todo;
}

class _SubTaskEditorState extends State<SubTaskEditor> {
  late final List<_Row> _rows = [for (final todo in widget.initialTodos) _Row(todo)];
  final _newController = TextEditingController();
  final _newFocus = FocusNode();

  @override
  void dispose() {
    _newController.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged([for (final row in _rows) row.todo]);
  }

  void _add() {
    final title = _newController.text.trim();
    if (title.isNotEmpty) {
      _rows.add(_Row(TaskTodoEntity(title: title, isCompleted: false, sortOrder: '')));
      _newController.clear();
      _changed();
    }
    // Keep typing the next one.
    _newFocus.requestFocus();
  }

  void _remove(_Row row) {
    _rows.remove(row);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            _rows.insert(newIndex, _rows.removeAt(oldIndex));
            _changed();
          },
          children: [
            for (final (index, row) in _rows.indexed)
              Dismissible(
                key: row.key,
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  color: colorScheme.errorContainer,
                  child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => _remove(row),
                child: Row(
                  children: [
                    Checkbox(
                      value: row.todo.isCompleted,
                      onChanged: (value) {
                        row.todo = row.todo.copyWith(isCompleted: value ?? false);
                        _changed();
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: row.todo.title,
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        onChanged: (value) {
                          row.todo = row.todo.copyWith(title: value);
                          _changed();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.taskFormDeleteSubTaskTooltip,
                      icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                      onPressed: () => _remove(row),
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.drag_handle)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        TextField(
          controller: _newController,
          focusNode: _newFocus,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: l10n.taskFormNewSubTask,
            prefixIcon: const Icon(Icons.add),
            suffixIcon: IconButton(tooltip: l10n.taskFormAddSubTaskTooltip, icon: const Icon(Icons.keyboard_return), onPressed: _add),
          ),
          // Replaces the default "submit and unfocus", so the keyboard stays open for the next sub-task.
          onEditingComplete: _add,
        ),
      ],
    );
  }
}
