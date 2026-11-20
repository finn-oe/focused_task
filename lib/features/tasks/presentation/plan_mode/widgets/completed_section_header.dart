import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';

/// "Completed (3)" with a chevron: shows or hides the completed tasks below it (#58). Used by the plan list and by
/// every board group.
class CompletedSectionHeader extends StatelessWidget {
  const CompletedSectionHeader({super.key, required this.count, required this.expanded, required this.onToggle, this.dense = false});

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  /// Smaller, for a board group.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Semantics(
      expanded: expanded,
      child: Tooltip(
        message: expanded ? l10n.planHideCompleted : l10n.planShowCompleted,
        // Its own Material: on the board the group's coloured box would hide the ink.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: dense,
            minTileHeight: kMinInteractiveDimension,
            contentPadding: EdgeInsets.symmetric(horizontal: dense ? 16 : 24),
            title: Text(
              l10n.planCompletedSection(count),
              style: (dense ? theme.textTheme.labelLarge : theme.textTheme.titleSmall)?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
            onTap: onToggle,
          ),
        ),
      ),
    );
  }
}
