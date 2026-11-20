import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/keyboard.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/task_schedule_screen.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/category_picker.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/duration_picker.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/sub_task_editor.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/schedule_labels.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_form/task_form_fields.dart';

/// Adds a task, or edits [task] (also past ones).
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final TaskEntity? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TaskDraft _initial;
  late TaskDraft _draft;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  /// Set once the form saved or the user confirmed discarding, so leaving doesn't ask again.
  bool _leaving = false;

  bool get _isEditMode => widget.task != null;

  bool get _hasChanges => _draft != _initial;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _initial = TaskDraft.fromTask(task);
    } else {
      // New tasks go to the day shown in the plan, but never into the past, and into the category the list is
      // filtered by.
      final today = clock.now().dateOnly;
      final plan = ref.read(planModeNotifierProvider);
      final planDay = plan.selectedDay;
      _initial = TaskDraft.empty(planDay.isBefore(today) ? today : planDay, categoryId: plan.view == PlanView.list ? plan.categoryFilter : null);
    }
    _draft = _initial;
    _titleController = TextEditingController(text: _initial.title);
    _descriptionController = TextEditingController(text: _initial.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _update(TaskDraft draft) => setState(() => _draft = draft);

  void _leave() {
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  Future<void> _editSchedule() async {
    final task = widget.task;
    final request = TaskScheduleRequest(
      schedule: _draft.schedule,
      day: _draft.date,
      targetMinutes: _draft.targetMinutes,
      timeSpent: task == null ? Duration.zero : Duration(milliseconds: task.timeSpent),
    );
    final schedule = await context.push<TaskSchedule>(AppRoutes.taskSchedule, extra: request);
    if (schedule != null && mounted) _update(_draft.copyWith(schedule: schedule));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(planModeNotifierProvider.notifier).saveDraft(_draft, id: widget.task?.id);
    if (mounted) _leave();
  }

  Future<void> _duplicate() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(planModeNotifierProvider.notifier).duplicateDraft(_draft);
    if (mounted) _leave();
  }

  Future<void> _delete() async {
    final task = widget.task!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteTaskDialog(task: task),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(planModeNotifierProvider.notifier).deleteTask(task.id);
    if (mounted) _leave();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(context: context, builder: (context) => const _DiscardChangesDialog());
    if (discard == true && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final task = widget.task;

    return PopScope(
      canPop: _leaving || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? l10n.taskFormEditTitle : l10n.taskFormAddTitle),
          actions: [
            if (_isEditMode) ...[
              IconButton(tooltip: l10n.taskFormDuplicateTooltip, icon: const Icon(Icons.copy_outlined), onPressed: _duplicate),
              IconButton(
                tooltip: l10n.taskFormDeleteTooltip,
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: _delete,
              ),
            ],
            // Reachable while the keyboard covers the bottom button (#56).
            IconButton(key: const Key('taskFormSaveAction'), tooltip: l10n.taskFormSave, icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              TaskTitleField(
                controller: _titleController,
                autofocus: !_isEditMode,
                onChanged: (value) => _update(_draft.copyWith(title: value)),
              ),
              const SizedBox(height: 16),
              TaskDateField(
                date: _draft.date,
                onChanged: (date) => _update(_draft.copyWith(date: date)),
              ),
              _Section(title: l10n.taskFormDurationLabel),
              DurationPicker(
                minutes: _draft.targetMinutes,
                onChanged: (minutes) => _update(minutes == null ? _draft.copyWith(clearTarget: true) : _draft.copyWith(targetMinutes: minutes)),
              ),
              _Section(title: l10n.taskFormCategory),
              CategoryPicker(
                categoryId: _draft.categoryId,
                onChanged: (id) => _update(id == null ? _draft.copyWith(clearCategory: true) : _draft.copyWith(categoryId: id)),
              ),
              _Section(title: l10n.taskFormPriority),
              PrioritySelector(
                priority: _draft.priority,
                onChanged: (priority) => _update(_draft.copyWith(priority: priority)),
              ),
              _Section(title: l10n.taskFormSubTasks),
              SubTaskEditor(
                initialTodos: _initial.todos,
                onChanged: (todos) => _update(_draft.copyWith(todos: todos)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                onTapOutside: unfocusOnTapOutside,
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.taskFormDescriptionLabel, border: const OutlineInputBorder()),
                maxLines: 4,
                minLines: 2,
                onChanged: (value) => _update(_draft.copyWith(description: value)),
              ),
              const SizedBox(height: 16),
              // Optional extras behind one tap, so the basics above stay quick to reach (#10).
              _ScheduleTile(schedule: _draft.schedule, onTap: _editSchedule),
              if (task != null) ...[const SizedBox(height: 16), _TrackedTimeTile(task: task)],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _save,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l10n.taskFormSave)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Schedule & reminder" with a one-line summary; opens the sub-page.
class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({required this.schedule, required this.onTap});

  final TaskSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        key: const Key('taskFormSchedule'),
        leading: const Icon(Icons.event_note_outlined),
        title: Text(context.l10n.taskFormSchedule),
        subtitle: Text(scheduleSummary(context, schedule, settings, now: clock.now())),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Asks before deleting; names the tracked time, which stays in the statistics.
class _DeleteTaskDialog extends StatelessWidget {
  const _DeleteTaskDialog({required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tracked = task.elapsedAt(clock.now());
    return AlertDialog(
      title: Text(l10n.taskFormDeleteTitle),
      content: Text(tracked > Duration.zero ? l10n.taskFormDeleteMessageTracked(task.title, tracked.toFormattedString()) : l10n.taskFormDeleteMessage(task.title)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}

class _DiscardChangesDialog extends StatelessWidget {
  const _DiscardChangesDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.taskFormDiscardTitle),
      content: Text(l10n.taskFormDiscardMessage),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.taskFormKeepEditing)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.taskFormDiscard)),
      ],
    );
  }
}

/// Tracked time of [task] with a button to add time manually (e.g. work done without the app).
class _TrackedTimeTile extends ConsumerStatefulWidget {
  const _TrackedTimeTile({required this.task});

  final TaskEntity task;

  @override
  ConsumerState<_TrackedTimeTile> createState() => _TrackedTimeTileState();
}

class _TrackedTimeTileState extends ConsumerState<_TrackedTimeTile> {
  late Duration _tracked = widget.task.elapsedAt(clock.now());

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 0, minute: 30),
      helpText: context.l10n.taskFormAddTimeTitle,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final duration = Duration(hours: picked.hour, minutes: picked.minute);
    if (duration == Duration.zero) return;

    await ref.read(planModeNotifierProvider.notifier).addManualTime(task: widget.task, duration: duration);
    if (mounted) setState(() => _tracked += duration);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        title: Text(l10n.taskFormTrackedTime),
        subtitle: Text(_tracked.toFormattedString()),
        trailing: TextButton.icon(onPressed: _addTime, icon: const Icon(Icons.more_time), label: Text(l10n.taskFormAddTime)),
      ),
    );
  }
}
