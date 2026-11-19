import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Lists the open [tasks] of the last days, all checked. Returns the ids of the tasks to move to today, or `null` when
/// the sheet is dismissed.
Future<List<int>?> showRolloverSheet(BuildContext context, {required List<TaskEntity> tasks, required DateTime today}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _RolloverSheet(tasks: tasks, today: today),
  );
}

class _RolloverSheet extends StatefulWidget {
  const _RolloverSheet({required this.tasks, required this.today});

  final List<TaskEntity> tasks;
  final DateTime today;

  @override
  State<_RolloverSheet> createState() => _RolloverSheetState();
}

class _RolloverSheetState extends State<_RolloverSheet> {
  late final Set<int> _selected = {for (final task in widget.tasks) task.id};

  void _toggle(int id, bool selected) => setState(() => selected ? _selected.add(id) : _selected.remove(id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Keep the original order (by day, then plan order) for the move.
    final selectedIds = [
      for (final task in widget.tasks)
        if (_selected.contains(task.id)) task.id,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.planRolloverTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.planRolloverMessage(widget.tasks.length), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final task in widget.tasks)
                    CheckboxListTile(
                      value: _selected.contains(task.id),
                      onChanged: (value) => _toggle(task.id, value ?? false),
                      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(relativeDayLabel(context, task.assignedDate, today: widget.today)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.planRolloverSettingsHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.planRolloverNotNow)),
                FilledButton(onPressed: selectedIds.isEmpty ? null : () => Navigator.of(context).pop(selectedIds), child: Text(l10n.planRolloverMove(selectedIds.length))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
