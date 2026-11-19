import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';

/// A small ring that fills with [progress] (0–1) and shows a check mark once [reached].
class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({super.key, required this.progress, required this.reached, this.size = 28});

  final double progress;
  final bool reached;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: reached ? 1 : progress.clamp(0, 1),
              strokeWidth: size / 8,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          if (reached) Icon(Icons.check, size: size * 0.55, color: colors.primary),
        ],
      ),
    );
  }
}

/// Today's focus time vs. the daily goal, for the plan header. Tap → statistics. Nothing without a goal.
class TodayGoalRing extends ConsumerWidget {
  const TodayGoalRing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(focusGoalProvider);
    if (!goal.isEnabled) return const SizedBox.shrink();
    final status = ref.watch(goalStatusProvider).value;
    if (status == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final focus = l10n.durationLabel(status.todayFocus);
    final target = l10n.durationLabel(goal.daily!);
    final label = status.reachedToday ? l10n.planGoalReached(focus, target) : l10n.planGoalProgress(focus, target);
    return IconButton(
      key: const Key('planGoalRing'),
      tooltip: label,
      onPressed: () => context.go(AppRoutes.stats),
      icon: GoalProgressRing(progress: status.progressToday, reached: status.reachedToday),
    );
  }
}
