import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/duration_extensions.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/rollover_sheet.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/session_recovery_dialog.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_list_item.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_move_feedback.dart';

/// Tasks of one day. The day comes from the URL (`/plan?date=YYYY-MM-DD`, missing = today) and the plan notifier
/// follows it, so browser back/forward and deep links work.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, this.day});

  /// Day from the route; `null` shows today.
  final DateTime? day;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _recoveryHandled = false;

  DateTime get _today => clock.now().dateOnly;

  DateTime get _shownDay => widget.day ?? _today;

  @override
  void initState() {
    super.initState();
    _followRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupPrompts());
  }

  @override
  void didUpdateWidget(PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _followRoute();
  }

  /// Providers must not change while widgets build, so the notifier follows the route right after.
  void _followRoute() {
    final day = _shownDay;
    Future.microtask(() {
      if (mounted) ref.read(planModeNotifierProvider.notifier).setSelectedDay(day);
    });
  }

  void _goToDay(DateTime day) => context.go(AppRoutes.planFor(day.dateOnly, today: _today));

  void _previousDay() => _goToDay(_shownDay.addDays(-1));

  void _nextDay() => _goToDay(_shownDay.addDays(1));

  void _addTask() => context.push(AppRoutes.taskForm);

  /// Starts focus on the shown day; asks first when working ahead or when open tasks would move to today.
  Future<void> _startFocus() async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final today = _today;
    String date(DateTime day) => DateFormat.yMMMEd(locale).format(day);
    Future<bool> confirm(String title, String message, String action) async {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmDialog(title: title, message: message, action: action),
      );
      return result ?? false;
    }

    final decision = await notifier.focusStartFor(_shownDay);
    if (!mounted) return;
    switch (decision) {
      case FocusStartNow(:final day):
        context.go(AppRoutes.focusFor(FocusRequest(day)));
      case FocusStartAhead(:final day):
        final message = day.isSameDate(today.addDays(1)) ? l10n.planFocusAheadTomorrow : l10n.planFocusAheadDate(date(day));
        if (await confirm(l10n.planFocusAheadTitle, message, l10n.planFocusStart) && mounted) {
          context.go(AppRoutes.focusFor(FocusRequest(day)));
        }
      case FocusStartMoveToToday(:final day, :final openTasks, :final fromYesterday):
        final ok = fromYesterday
            ? await confirm(l10n.planFocusYesterdayTitle, l10n.planFocusYesterdayMessage(openTasks), l10n.planFocusMoveAndStart)
            : await confirm(l10n.planFocusMoveTitle, l10n.planFocusMoveMessage(openTasks, date(day)), l10n.planFocusMoveAndStart);
        if (!ok || !mounted) return;
        await notifier.moveOpenTasks(from: day, to: today);
        if (mounted) context.go(AppRoutes.focusFor(FocusRequest(today)));
    }
  }

  Future<void> _pickDay() async {
    final selected = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _shownDay);
    if (selected != null && mounted) _goToDay(selected);
  }

  /// One prompt after the other: first unfinished focus sessions, then the daily rollover of open tasks.
  Future<void> _runStartupPrompts() async {
    await _handleRecoverableSessions();
    if (mounted) await _offerRollover();
  }

  /// On the first start of a day, offers to move the open tasks of the last days to today.
  Future<void> _offerRollover() async {
    final notifier = ref.read(planModeNotifierProvider.notifier);
    final tasks = await notifier.takeRolloverCandidates();
    if (!mounted || tasks.isEmpty) return;

    final today = _today;
    final ids = await showRolloverSheet(context, tasks: tasks, today: today);
    if (ids == null || ids.isEmpty || !mounted) return;

    final feedback = TaskMoveFeedback.of(context, notifier);
    feedback.show(await notifier.moveTasks(ids, today));
  }

  Future<void> _handleRecoverableSessions() async {
    if (_recoveryHandled) {
      return;
    }

    _recoveryHandled = true;
    final focus = ref.read(focusModeNotifierProvider.notifier);
    final sessions = await focus.loadRecoverableSessions();
    if (!mounted || sessions.isEmpty) {
      return;
    }

    final recovery = await showSessionRecoveryDialog(context, sessions: sessions, now: clock.now());
    if (recovery == null) {
      return;
    }

    await focus.recoverSessions(recovery: recovery, sessions: sessions);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = _today;
    final shownDay = _shownDay;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _previousDay,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _nextDay,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _addTask,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _addTask,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            return Scaffold(
              appBar: AppBar(
                titleSpacing: 4,
                title: _DayNavigator(
                  label: relativeDayLabel(context, shownDay, today: today),
                  onPrevious: _previousDay,
                  onNext: _nextDay,
                  onPick: _pickDay,
                ),
                actions: [
                  if (!shownDay.isSameDate(today))
                    compact
                        ? IconButton(tooltip: l10n.commonToday, onPressed: () => _goToDay(today), icon: const Icon(Icons.today))
                        : Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(label: Text(l10n.commonToday), avatar: const Icon(Icons.today), onPressed: () => _goToDay(today)),
                          ),
                  if (compact)
                    IconButton.filled(
                      tooltip: l10n.planStartFocus,
                      onPressed: _startFocus,
                      // The app bar's action icon colour would override the filled button's foreground.
                      icon: Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  else
                    FilledButton.icon(onPressed: _startFocus, icon: const Icon(Icons.play_arrow), label: Text(l10n.planStartFocus)),
                  const SizedBox(width: 8),
                ],
              ),
              body: _DayTasks(onSwipeToPrevious: _previousDay, onSwipeToNext: _nextDay),
              floatingActionButton: FloatingActionButton.extended(onPressed: _addTask, icon: const Icon(Icons.add), label: Text(l10n.planAddTask)),
            );
          },
        ),
      ),
    );
  }
}

/// `‹` previous day · date (tap → date picker) · `›` next day.
class _DayNavigator extends StatelessWidget {
  const _DayNavigator({required this.label, required this.onPrevious, required this.onNext, required this.onPick});

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: l10n.planPreviousDay, onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Flexible(
          child: Tooltip(
            message: l10n.planPickDayTooltip,
            child: TextButton(
              onPressed: onPick,
              child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        ),
        IconButton(tooltip: l10n.planNextDay, onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

/// Task list of the selected day with the day's tracked total. Swiping horizontally changes the day.
class _DayTasks extends ConsumerWidget {
  const _DayTasks({required this.onSwipeToPrevious, required this.onSwipeToNext});

  final VoidCallback onSwipeToPrevious;
  final VoidCallback onSwipeToNext;

  static const _swipeVelocity = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(planModeNotifierProvider);
    final notifier = ref.read(planModeNotifierProvider.notifier);

    final now = clock.now();
    final total = state.tasks.fold(Duration.zero, (sum, task) => sum + task.elapsedAt(now));

    return Column(
      children: [
        if (total > Duration.zero)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  total.toFormattedString(),
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > _swipeVelocity) onSwipeToPrevious();
              if (velocity < -_swipeVelocity) onSwipeToNext();
            },
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                ? Center(child: Text(l10n.planNoTasks))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 88), // keep the last task clear of the add button
                    itemCount: state.tasks.length,
                    onReorderItem: notifier.reorderTask,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
                      return TaskListItem(key: ValueKey(task.id), task: task, index: index);
                    },
                  ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.planLoadError(state.error!), style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title, required this.message, required this.action});

  final String title;
  final String message;
  final String action;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    );
  }
}
