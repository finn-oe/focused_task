import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/inbox/domain/inbox_item.dart';

/// Lets the user turn each parked thought into a task (today / tomorrow) or dismiss it.
Future<void> showInboxReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => const _InboxReviewSheet());
}

/// "3 parked thoughts · Review", shown while thoughts wait for review; nothing otherwise.
class ParkedThoughtsBanner extends ConsumerWidget {
  const ParkedThoughtsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inboxNotifierProvider.select((inbox) => inbox.open.length));
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      key: const Key('parkedThoughtsBanner'),
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(Icons.lightbulb_outline, color: theme.colorScheme.onSecondaryContainer),
        title: Text(l10n.inboxCount(count), style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
        trailing: TextButton(onPressed: () => showInboxReviewSheet(context), child: Text(l10n.inboxReview)),
      ),
    );
  }
}

class _InboxReviewSheet extends ConsumerStatefulWidget {
  const _InboxReviewSheet();

  @override
  ConsumerState<_InboxReviewSheet> createState() => _InboxReviewSheetState();
}

class _InboxReviewSheetState extends ConsumerState<_InboxReviewSheet> {
  /// What happened to the last item, and how to undo it (only for dismissing). Shown in the sheet, because a
  /// SnackBar would be hidden behind it.
  String? _feedback;
  InboxItem? _dismissed;

  void _show(String? feedback, {InboxItem? dismissed}) {
    setState(() {
      _feedback = feedback;
      _dismissed = dismissed;
    });
  }

  Future<void> _convert(InboxItem item, {required bool tomorrow}) async {
    final today = clock.now().dateOnly;
    final l10n = context.l10n;
    await ref.read(inboxNotifierProvider.notifier).convertToTask(item, tomorrow ? today.nextDay : today);
    if (mounted) _show(tomorrow ? l10n.inboxAddedTomorrow : l10n.inboxAddedToday);
  }

  Future<void> _dismiss(InboxItem item) async {
    final l10n = context.l10n;
    await ref.read(inboxNotifierProvider.notifier).dismiss(item);
    if (mounted) _show(l10n.inboxDismissed, dismissed: item);
  }

  Future<void> _undo() async {
    final item = _dismissed;
    if (item == null) return;
    await ref.read(inboxNotifierProvider.notifier).reopen(item);
    if (mounted) _show(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final items = ref.watch(inboxNotifierProvider.select((inbox) => inbox.open));
    final today = clock.now().dateOnly;
    final time = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag());

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(l10n.inboxTitle, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.inboxHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.inboxAllReviewed, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in items)
                      _InboxItemTile(
                        key: ValueKey(item.id),
                        item: item,
                        subtitle: '${relativeDayLabel(context, item.createdAt, today: today)}, ${time.format(item.createdAt)}',
                        onToday: () => _convert(item, tomorrow: false),
                        onTomorrow: () => _convert(item, tomorrow: true),
                        onDismiss: () => _dismiss(item),
                      ),
                  ],
                ),
              ),
            if (_feedback case final feedback?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(feedback, style: theme.textTheme.bodyMedium)),
                    if (_dismissed != null) TextButton(onPressed: _undo, child: Text(l10n.commonUndo)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxItemTile extends StatelessWidget {
  const _InboxItemTile({super.key, required this.item, required this.subtitle, required this.onToday, required this.onTomorrow, required this.onDismiss});

  final InboxItem item;
  final String subtitle;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 8),
      title: Text(item.text),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: l10n.inboxToTodayTooltip, onPressed: onToday, icon: const Icon(Icons.today)),
          IconButton(tooltip: l10n.inboxToTomorrowTooltip, onPressed: onTomorrow, icon: const Icon(Icons.next_plan_outlined)),
          IconButton(tooltip: l10n.inboxDismiss, onPressed: onDismiss, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
