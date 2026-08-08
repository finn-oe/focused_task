import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

class TaskFormModal extends ConsumerStatefulWidget {
  const TaskFormModal({super.key, this.task});

  final TaskEntity? task; // If null, it's Add Mode. If provided, it's Edit Mode.

  static Future<void> show(BuildContext context, {TaskEntity? task}) {
    return showDialog<void>(
      context: context,
      builder: (context) => TaskFormModal(task: task),
    );
  }

  @override
  ConsumerState<TaskFormModal> createState() => _TaskFormModalState();
}

class _TaskFormModalState extends ConsumerState<TaskFormModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  bool get _isEditMode => widget.task != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(planModeNotifierProvider.notifier);

    return AlertDialog(
      title: Text(_isEditMode ? 'Edit task' : 'Add task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            autofocus: !_isEditMode, // Only autofocus on new tasks
          ),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
      actions: [
        if (_isEditMode)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: () async {
              await notifier.deleteTask(widget.task!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          )
        else
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final title = _titleController.text.trim();
            final description = _descriptionController.text.trim();
            final parsedDesc = description.isEmpty ? null : description;

            if (title.isEmpty) return;

            if (_isEditMode) {
              await notifier.updateTask(id: widget.task!.id, title: title, description: parsedDesc);
            } else {
              await notifier.addTask(title: title, description: parsedDesc);
            }

            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
