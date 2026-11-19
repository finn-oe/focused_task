import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

/// Confirms a move with a snack bar that can undo it.
///
/// Create it from the context *before* moving: the moved task's tile is gone afterwards.
class TaskMoveFeedback {
  TaskMoveFeedback.of(BuildContext context, this._notifier)
    : _messenger = ScaffoldMessenger.of(context),
      _l10n = context.l10n,
      _locale = Localizations.localeOf(context).toLanguageTag();

  final PlanModeNotifier _notifier;
  final ScaffoldMessengerState _messenger;
  final AppLocalizations _l10n;
  final String _locale;

  void show(TaskMove move) {
    if (move.isEmpty) return;
    final message = move.to.isSameDate(clock.now()) ? _l10n.taskMovedToToday(move.count) : _l10n.taskMovedToDate(move.count, DateFormat.yMMMEd(_locale).format(move.to));
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: _l10n.commonUndo, onPressed: () => _notifier.undoMove(move)),
        ),
      );
  }
}
