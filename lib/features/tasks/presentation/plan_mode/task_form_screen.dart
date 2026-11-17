import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/core/utils/date_utils.dart';

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

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _targetDurationMinutes = widget.task?.targetDurationMinutes;
    _todos = widget.task?.todos.toList() ?? [];

    if (widget.task != null) {
      _selectedDate = widget.task!.assignedDate;
    } else {
      final planSelectedDay = ref.read(planModeNotifierProvider).selectedDay;
      final today = DateTime.now().dateOnly;

      if (planSelectedDay.isBefore(today)) {
        _selectedDate = today;
      } else {
        _selectedDate = planSelectedDay;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showTodoDialog({int? editIndex}) async {
    final isEdit = editIndex != null;
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => _TodoInputDialog(initialTitle: isEdit ? _todos[editIndex].title : null),
    );

    if (!mounted) return;

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      setState(() {
        if (isEdit) {
          _todos[editIndex] = _todos[editIndex].copyWith(title: newTitle.trim());
        } else {
          _todos.add(TaskTodoEntity(title: newTitle.trim(), isCompleted: false, sortOrder: ''));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final targetMinutes = _targetDurationMinutes;

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.taskFormEditTitle : l10n.taskFormAddTitle),
        actions: [
          if (_isEditMode)
            IconButton(
              tooltip: l10n.taskFormDuplicateTooltip,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                final title = _titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.taskFormDuplicateWithoutTitle)));
                  return;
                }

                final description = _descriptionController.text.trim();
                final parsedDesc = description.isEmpty ? null : description;

                final resetSortedTodos = _todos.asMap().entries.map((entry) {
                  return entry.value.copyWith(isCompleted: false, sortOrder: entry.key.toString().padLeft(5, '0'));
                }).toList();

                await notifier.addTask(title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes, assignedDate: _selectedDate, todos: resetSortedTodos);

                if (context.mounted) context.pop();
              },
            ),
          IconButton(
            tooltip: l10n.taskFormChangeDateTooltip,
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _selectedDate);
              if (selected != null && mounted) {
                setState(() => _selectedDate = selected);
              }
            },
          ),
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: l10n.taskFormDeleteTooltip,
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
              decoration: InputDecoration(labelText: l10n.taskFormTitleLabel, border: const OutlineInputBorder()),
              autofocus: !_isEditMode,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.taskFormDescriptionLabel, border: const OutlineInputBorder()),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.taskFormSubTasks, style: theme.textTheme.titleMedium),
                IconButton(onPressed: _showTodoDialog, icon: const Icon(Icons.add), tooltip: l10n.taskFormAddSubTaskTooltip),
              ],
            ),
            const SizedBox(height: 8),

            if (_todos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(l10n.taskFormNoSubTasks, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.4),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _todos.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _todos.removeAt(oldIndex);
                      _todos.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final todo = _todos[index];
                    return ListTile(
                      key: ObjectKey(todo),
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
                            tooltip: l10n.taskFormEditSubTaskTooltip,
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showTodoDialog(editIndex: index),
                          ),
                          IconButton(
                            tooltip: l10n.taskFormDeleteSubTaskTooltip,
                            icon: Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
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
              ),

            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: ListTile(
                title: Text(l10n.taskFormTargetDuration),
                subtitle: Text(targetMinutes == null ? l10n.taskFormNoLimit : l10n.taskFormTargetDurationValue(targetMinutes ~/ 60, targetMinutes % 60)),
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
                await notifier.updateTask(
                  id: widget.task!.id,
                  title: title,
                  description: parsedDesc,
                  targetDurationMinutes: _targetDurationMinutes,
                  assignedDate: _selectedDate,
                  todos: sortedTodos,
                );
              } else {
                await notifier.addTask(title: title, description: parsedDesc, targetDurationMinutes: _targetDurationMinutes, assignedDate: _selectedDate, todos: sortedTodos);
              }

              if (context.mounted) context.pop();
            },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text(l10n.taskFormSave)),
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.initialTitle != null ? l10n.taskFormEditSubTaskTitle : l10n.taskFormAddSubTaskTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.taskFormTitleLabel, border: const OutlineInputBorder()),
        onSubmitted: (val) => Navigator.of(context).pop(val),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(l10n.commonSave)),
      ],
    );
  }
}
