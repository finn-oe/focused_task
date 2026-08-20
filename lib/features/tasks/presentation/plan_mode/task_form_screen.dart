import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final TaskEntity? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  int? _targetDurationMinutes;

  bool get _isEditMode => widget.task != null;

  List<TaskTodoEntity> _todos = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _targetDurationMinutes = widget.task?.targetDurationMinutes;
    _todos = widget.task?.todos.toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showTodoDialog({int? editIndex}) async {
    final isEdit = editIndex != null;

    // Use our new custom dialog widget that safely manages its own controller
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => _TodoInputDialog(initialTitle: isEdit ? _todos[editIndex].title : null),
    );

    if (!mounted) return; // Always check mounted after an async gap

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      setState(() {
        if (isEdit) {
          _todos[editIndex] = _todos[editIndex].copyWith(title: newTitle.trim());
        } else {
          _todos.add(
            TaskTodoEntity(
              title: newTitle.trim(),
              isCompleted: false,
              sortOrder: '', // Will be assigned on save
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(planModeNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'Add Task'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Delete Task',
              onPressed: () async {
                await notifier.deleteTask(widget.task!.id);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              autofocus: !_isEditMode,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sub-tasks', style: theme.textTheme.titleMedium),
                IconButton(onPressed: () => _showTodoDialog(), icon: const Icon(Icons.add), tooltip: 'Add Sub-task'),
              ],
            ),
            const SizedBox(height: 8),

            // --- Sub-tasks List ---
            if (_todos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text('No sub-tasks added.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _todos.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final item = _todos.removeAt(oldIndex);
                    _todos.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final todo = _todos[index];
                  return ListTile(
                    key: ValueKey(todo.id ?? 'new_${todo.title}_$index'),
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: todo.isCompleted,
                      onChanged: (val) => setState(() => _todos[index] = todo.copyWith(isCompleted: val)),
                    ),
                    title: Text(todo.title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showTodoDialog(editIndex: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => setState(() => _todos.removeAt(index)),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(padding: EdgeInsets.only(right: 8.0, left: 8.0), child: Icon(Icons.drag_handle)),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: ListTile(
                title: const Text('Target Duration (Optional)'),
                subtitle: Text(_targetDurationMinutes == null ? 'No limit' : '${_targetDurationMinutes! ~/ 60}h ${_targetDurationMinutes! % 60}m'),
                trailing: const Icon(Icons.timer_outlined),
                onTap: () async {
                  final initialTime = TimeOfDay(hour: (_targetDurationMinutes ?? 0) ~/ 60, minute: (_targetDurationMinutes ?? 0) % 60);

                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
                  );

                  if (selectedTime != null) {
                    setState(() {
                      final totalMins = selectedTime.hour * 60 + selectedTime.minute;
                      _targetDurationMinutes = totalMins == 0 ? null : totalMins;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              final description = _descriptionController.text.trim();
              final parsedDesc = description.isEmpty ? null : description;

              if (title.isEmpty) return;

              final sortedTodos = _todos.asMap().entries.map((entry) {
                return entry.value.copyWith(sortOrder: entry.key.toString().padLeft(5, '0'));
              }).toList();

              if (_isEditMode) {
                await notifier.updateTask(id: widget.task!.id, title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes, todos: sortedTodos);
              } else {
                await notifier.addTask(title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes, todos: sortedTodos);
              }

              if (context.mounted) context.pop();
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text('Save Task')),
          ),
        ),
      ),
    );
  }
}

class _TodoInputDialog extends StatefulWidget {
  const _TodoInputDialog({this.initialTitle});

  final String? initialTitle;

  @override
  State<_TodoInputDialog> createState() => _TodoInputDialogState();
}

class _TodoInputDialogState extends State<_TodoInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    // The controller is safely disposed *after* the dialog fully unmounts
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTitle != null ? 'Edit sub-task' : 'Add sub-task'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
        onSubmitted: (val) => Navigator.of(context).pop(val),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}
