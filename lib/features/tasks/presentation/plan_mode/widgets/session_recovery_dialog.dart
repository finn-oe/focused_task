import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

/// Asks how to close focus sessions that were left open, e.g. because the app was killed.
///
/// Returns `null` if dismissed; the sessions then stay open and the question is asked again next time.
Future<SessionRecovery?> showSessionRecoveryDialog(BuildContext context, {required List<TaskEntity> sessions, required DateTime now}) {
  return showDialog<SessionRecovery>(
    context: context,
    builder: (context) => _SessionRecoveryDialog(sessions: sessions, now: now),
  );
}

class _SessionRecoveryDialog extends StatelessWidget {
  const _SessionRecoveryDialog({required this.sessions, required this.now});

  final List<TaskEntity> sessions;
  final DateTime now;

  Duration _sum(DateTime Function(TaskEntity session) endOf) {
    return sessions.fold(Duration.zero, (sum, session) {
      final elapsed = endOf(session).difference(session.latestStart!);
      return elapsed.isNegative ? sum : sum + elapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final untilLastActivity = _sum((session) => session.lastActivityAt!);
    final untilNow = _sum((_) => now);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Recover unfinished session?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The app was closed while you were focusing on:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final session in sessions) Text('• ${session.title}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text('How much of that time do you want to keep?', style: theme.textTheme.bodyMedium),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(SessionRecovery.discard), child: const Text('Discard')),
        if (untilNow - untilLastActivity >= const Duration(minutes: 1))
          TextButton(onPressed: () => Navigator.of(context).pop(SessionRecovery.untilNow), child: Text('Until now (${untilNow.toFormattedString()})')),
        FilledButton(onPressed: () => Navigator.of(context).pop(SessionRecovery.untilLastActivity), child: Text('Until last activity (${untilLastActivity.toFormattedString()})')),
      ],
    );
  }
}
