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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _targetDurationMinutes = widget.task?.targetDurationMinutes;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'Add Task'),
        // Optional: Move delete to an icon in the AppBar instead of the bottom
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
              maxLines: 4, // More space since it's a full screen!
              minLines: 2,
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

              if (_isEditMode) {
                await notifier.updateTask(id: widget.task!.id, title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes);
              } else {
                await notifier.addTask(title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes);
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
