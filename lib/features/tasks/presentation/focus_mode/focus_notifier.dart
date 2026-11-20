import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/core/services/target_alarm.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/breaks/domain/interval_planner.dart';
import 'package:focused_task/features/inbox/domain/i_inbox_repository.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';

export 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';

/// How to close sessions that were left open (e.g. the app was killed while focusing).
enum SessionRecovery {
  /// Count the time up to the last heartbeat – the safe default.
  untilLastActivity,

  /// Count the time up to now, e.g. when the user kept working while the app was closed.
  untilNow,

  /// Drop the time of the unfinished session.
  discard,
}

class FocusModeState {
  const FocusModeState({
    required this.selectedDay,
    required this.now,
    required this.sessionBaseMs,
    required this.isLoading,
    required this.isPaused,
    this.sessionStartedAt,
    this.currentTask,
    this.request,
    this.queue = const [],
    this.error,
    this.shouldShowFinishedForToday = false,
    this.shouldShowAlarm = false,
    this.hasAlarmPlayedForCurrentTask = false,
    this.intervals,
    this.isBreakOver = false,
    this.awayFor,
  });

  factory FocusModeState.initial() {
    final now = clock.now();
    return FocusModeState(selectedDay: now.dateOnly, now: now, sessionBaseMs: 0, isLoading: false, isPaused: true);
  }

  final DateTime selectedDay;
  final DateTime now;
  final int sessionBaseMs;
  final DateTime? sessionStartedAt;
  final bool isLoading;
  final bool isPaused;
  final TaskEntity? currentTask;

  /// What the session works on (day and first task).
  final FocusRequest? request;

  /// Open tasks still to do in this session; the current task first. Only for this session, the plan is unchanged.
  final List<TaskEntity> queue;

  /// The task after the current one, if any.
  TaskEntity? get upNext => queue.length > 1 ? queue[1] : null;
  final String? error;
  final bool shouldShowFinishedForToday;
  final bool shouldShowAlarm;

  /// Whether the target alarm already rang (or the target was already exceeded) for [currentTask].
  final bool hasAlarmPlayedForCurrentTask;

  /// The work/break cycle (#27), or `null` if intervals are off.
  final IntervalPlanner? intervals;

  /// A break is running; focus time doesn't count meanwhile.
  bool get isOnBreak => intervals?.phase.isBreak ?? false;

  /// The break is over and the next work interval waits for the user.
  final bool isBreakOver;

  /// How long the user was away from a running focus session; set once on return for the "welcome back" message.
  final Duration? awayFor;

  Duration get totalSessionDuration {
    final runningMs = isPaused || sessionStartedAt == null ? 0 : now.difference(sessionStartedAt!).inMilliseconds;
    return Duration(milliseconds: sessionBaseMs + runningMs);
  }

  Duration get currentTaskDuration {
    if (currentTask == null) {
      return Duration.zero;
    }

    return currentTask!.elapsedAt(now);
  }

  FocusModeState copyWith({
    DateTime? selectedDay,
    DateTime? now,
    int? sessionBaseMs,
    DateTime? sessionStartedAt,
    bool? isLoading,
    bool? isPaused,
    TaskEntity? currentTask,
    FocusRequest? request,
    List<TaskEntity>? queue,
    String? error,
    bool? shouldShowFinishedForToday,
    bool? shouldShowAlarm,
    bool? hasAlarmPlayedForCurrentTask,
    IntervalPlanner? intervals,
    bool? isBreakOver,
    Duration? awayFor,
    bool clearAwayFor = false,
    bool clearIntervals = false,
    bool clearCurrentTask = false,
    bool clearSessionStartedAt = false,
    bool clearError = false,
  }) {
    return FocusModeState(
      selectedDay: selectedDay ?? this.selectedDay,
      now: now ?? this.now,
      sessionBaseMs: sessionBaseMs ?? this.sessionBaseMs,
      sessionStartedAt: clearSessionStartedAt ? null : sessionStartedAt ?? this.sessionStartedAt,
      isLoading: isLoading ?? this.isLoading,
      isPaused: isPaused ?? this.isPaused,
      currentTask: clearCurrentTask ? null : currentTask ?? this.currentTask,
      request: request ?? this.request,
      queue: queue ?? this.queue,
      error: clearError ? null : error ?? this.error,
      shouldShowFinishedForToday: shouldShowFinishedForToday ?? this.shouldShowFinishedForToday,
      shouldShowAlarm: shouldShowAlarm ?? this.shouldShowAlarm,
      hasAlarmPlayedForCurrentTask: hasAlarmPlayedForCurrentTask ?? this.hasAlarmPlayedForCurrentTask,
      intervals: clearIntervals ? null : intervals ?? this.intervals,
      isBreakOver: isBreakOver ?? this.isBreakOver,
      awayFor: clearAwayFor ? null : awayFor ?? this.awayFor,
    );
  }
}

class FocusModeNotifier extends Notifier<FocusModeState> {
  late ITaskRepository _repository;
  late IFocusSessionRepository _sessions;
  late TargetAlarm _alarm;
  late NotificationService _notifications;
  late IInboxRepository _inbox;
  Timer? _ticker;

  /// When the app lost the user's attention, and the focus session that was running then (#28).
  DateTime? _awaySince;
  int? _awaySessionId;

  /// The open focus session of [FocusModeState.currentTask], or `null` while paused.
  int? _sessionId;

  /// The open break session, or `null` if no break runs.
  int? _breakSessionId;
  DateTime? _lastHeartbeat;

  /// Set while an interval end is handled, so the ticker doesn't handle it twice.
  bool _isAdvancingIntervals = false;

  /// How often a running session records that it is still alive.
  static const heartbeatInterval = Duration(seconds: 30);

  /// A target alarm due this close to the end of a work interval waits until after the break, so the two never ring
  /// at the same moment (the interval has priority).
  static const alarmGap = Duration(minutes: 1);

  /// Leaving the app for at least this long during focus counts as an interruption; shorter switches (a flickering
  /// window focus, a glance at a notification) don't.
  static const interruptionThreshold = Duration(seconds: 2);

  /// Coming back after at least this long shows "You were away …".
  static const welcomeBackThreshold = Duration(minutes: 1);

  @override
  FocusModeState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _sessions = ref.watch(focusSessionRepositoryProvider);
    _alarm = ref.watch(targetAlarmProvider);
    _notifications = ref.watch(notificationServiceProvider);
    _inbox = ref.watch(inboxRepositoryProvider);
    ref.onDispose(_stopTicker);
    return FocusModeState.initial();
  }

  /// Focus on the open tasks of today.
  Future<void> initializeForDay(DateTime day) => start(FocusRequest(day));

  /// Starts (or continues) focus for [request]: the open tasks of its day (only those of its category, if it has one)
  /// in plan order, rotated so the requested task comes first. Re-entering with the same request (e.g. after a pause)
  /// keeps the current queue.
  Future<void> start(FocusRequest request) async {
    if (state.request == request && state.currentTask != null) {
      return;
    }
    state = state.copyWith(request: request, selectedDay: request.day, isLoading: true, clearError: true);

    final category = request.categoryId;
    final open = (await _repository.getTasksForDay(request.day)).where((task) => !task.isCompleted && (category == null || task.categoryId == category)).toList();
    final startIndex = open.indexWhere((task) => task.id == request.startTaskId);
    final queue = startIndex <= 0 ? open : [...open.sublist(startIndex), ...open.sublist(0, startIndex)];
    // A new focus run starts a new work/break cycle; settings changed meanwhile apply from here on.
    final intervals = ref.read(intervalSettingsProvider);
    state = state.copyWith(
      queue: queue,
      intervals: intervals.isEnabled ? IntervalPlanner(settings: intervals) : null,
      clearIntervals: !intervals.isEnabled,
      isBreakOver: false,
    );

    await _loadCurrentTask();
  }

  /// Puts the current task at the end of the queue. Its tracked time stays; the session ends as "skipped".
  Future<void> skipCurrentTask() async {
    final task = state.currentTask;
    if (task == null) return;

    await _cancelReminders();
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId != null) {
      await _sessions.end(sessionId, clock.now(), EndReason.skipped);
    }
    final skipped = await _repository.getTaskById(task.id) ?? task;
    state = state.copyWith(queue: [...state.queue.skip(1), skipped]);

    await _loadCurrentTask();
  }

  /// Adds a sub-task to the current task.
  Future<void> addSubTask(String title) async {
    final task = state.currentTask;
    final trimmed = title.trim();
    if (task == null || trimmed.isEmpty) return;

    final todos = [...task.todos, TaskTodoEntity(title: trimmed, isCompleted: false, sortOrder: task.todos.length.toString().padLeft(5, '0'))];
    await _repository.replaceTaskTodos(task.id, todos);
    final updated = await _repository.getTaskById(task.id);
    if (updated != null) state = state.copyWith(currentTask: updated);
  }

  /// Time left until [task] reaches its target, or `null` if it has no target.
  static Duration? _remainingUntilTarget(TaskEntity task, DateTime now) {
    final target = task.targetDurationMinutes;
    if (target == null) {
      return null;
    }
    return Duration(minutes: target) - task.elapsedAt(now);
  }

  /// Schedules the OS/background alarm for the running [task] if it hasn't rung yet. A target that was reached while
  /// the alarm was deferred (see [alarmGap]) rings right away; a target at or near the end of the running work
  /// interval is left to the next work interval.
  Future<void> _scheduleTargetAlarm(TaskEntity task, DateTime now) async {
    final remaining = _remainingUntilTarget(task, now);
    if (remaining == null || state.hasAlarmPlayedForCurrentTask) {
      return;
    }
    final at = remaining.isNegative ? now : now.add(remaining);
    final intervalEnd = state.intervals?.phase == IntervalPhase.work ? state.intervals?.endsAt : null;
    if (intervalEnd != null && !at.isBefore(intervalEnd.subtract(alarmGap))) {
      return;
    }
    // Read at schedule time (not watched): switching the language must not reset a running session.
    final l10n = ref.read(appLocalizationsProvider);
    final notification = AlarmNotification(title: l10n.focusTimeIsUp, body: l10n.focusAlarmNotificationBody(task.title), stopButton: l10n.focusAlarmStopButton);
    await _alarm.schedule(notification: notification, at: at);
  }

  /// Whether the target alarm waits because the work interval is about to end (see [alarmGap]).
  bool _isTargetAlarmDeferred(DateTime now) {
    final intervals = state.intervals;
    return intervals != null && intervals.phase == IntervalPhase.work && intervals.isRunning && intervals.remaining(now) <= alarmGap;
  }

  /// Schedules the "time for a break" notification for the end of the running work interval, so it also arrives while
  /// the app is in the background.
  Future<void> _scheduleBreakNotification() async {
    final intervals = state.intervals;
    final at = intervals?.endsAt;
    if (intervals == null || intervals.phase != IntervalPhase.work || at == null) return;
    final breakLength = intervals.nextPhase == IntervalPhase.longBreak ? intervals.settings.longBreak : intervals.settings.shortBreak;
    final l10n = ref.read(appLocalizationsProvider);
    final notification = AppNotification(
      id: NotificationIds.breakStarts,
      channel: NotificationChannel.breaks,
      title: l10n.notificationBreakTitle,
      body: l10n.notificationBreakBody(l10n.durationLabel(breakLength)),
    );
    await _notifications.schedule(notification, at);
  }

  /// Schedules the "break is over" notification for the end of the running break.
  Future<void> _scheduleBreakOverNotification() async {
    final at = state.intervals?.endsAt;
    final task = state.currentTask;
    if (!state.isOnBreak || at == null || task == null) return;
    final l10n = ref.read(appLocalizationsProvider);
    final notification = AppNotification(
      id: NotificationIds.breakOver,
      channel: NotificationChannel.breaks,
      title: l10n.notificationBreakOverTitle,
      body: l10n.notificationBreakOverBody(task.title),
    );
    await _notifications.schedule(notification, at);
  }

  Future<void> _loadCurrentTask() async {
    final task = state.queue.firstOrNull;
    if (task == null) {
      _stopTicker();
      state = state.copyWith(
        isLoading: false,
        isPaused: true,
        clearCurrentTask: true,
        clearSessionStartedAt: true,
        sessionBaseMs: 0,
        shouldShowFinishedForToday: true,
        shouldShowAlarm: false,
        hasAlarmPlayedForCurrentTask: false,
        clearIntervals: true,
        isBreakOver: false,
      );
      await _notifications.cancel(NotificationIds.breakStarts);
      return;
    }

    // Continue the task's open session (e.g. after a crash without recovery), otherwise start a new one.
    final open = await _sessions.openSession();
    _sessionId = open != null && open.taskId == task.id ? open.id : (await _sessions.start(taskId: task.id, at: clock.now())).id;
    final current = (await _repository.getTaskById(task.id)) ?? task;
    state = state.copyWith(queue: [current, ...state.queue.skip(1)]);

    final now = clock.now();
    final remaining = _remainingUntilTarget(current, now);
    _startTicker();
    state = state.copyWith(
      currentTask: current,
      isPaused: false,
      sessionStartedAt: state.sessionStartedAt ?? now,
      now: now,
      isLoading: false,
      clearError: true,
      shouldShowFinishedForToday: false,
      // A task that is already over its target must not ring again every time focus is (re)entered.
      hasAlarmPlayedForCurrentTask: remaining != null && remaining <= Duration.zero,
      // The work interval runs across tasks: it starts with the first task and goes on when the task changes.
      intervals: state.intervals?.start(now),
    );

    await _scheduleTargetAlarm(current, now);
    await _scheduleBreakNotification();
    await _scheduleGoalNotification(now);
  }

  /// Pauses the running session; [reason] is recorded in the session log.
  Future<void> pauseSession({EndReason reason = EndReason.paused}) async {
    final task = state.currentTask;
    if (task == null || state.isPaused) {
      return;
    }

    await _cancelReminders();

    final now = clock.now();
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId != null) {
      await _sessions.end(sessionId, now, reason);
    }

    final updatedTask = await _repository.getTaskById(task.id);
    final runningMs = state.sessionStartedAt == null ? 0 : now.difference(state.sessionStartedAt!).inMilliseconds;

    _stopTicker();
    state = state.copyWith(
      currentTask: updatedTask,
      sessionBaseMs: state.sessionBaseMs + runningMs,
      isPaused: true,
      clearSessionStartedAt: true,
      now: now,
      shouldShowFinishedForToday: false,
      // The work interval stops with the session and continues with the time that was left.
      intervals: state.intervals?.pause(now),
    );
  }

  /// Continues a paused session. Does nothing during a break: the break screen goes on with [skipBreak] or
  /// [continueAfterBreak].
  Future<void> resumeSession() async {
    if (state.currentTask == null || !state.isPaused || state.isOnBreak || state.isBreakOver) {
      return;
    }
    await _startWork(clock.now());
  }

  /// Starts a focus session for the current task at [at] (also the next work interval after a break).
  Future<void> _startWork(DateTime at) async {
    final task = state.currentTask;
    if (task == null) return;

    _sessionId = (await _sessions.start(taskId: task.id, at: at)).id;
    final updatedTask = await _repository.getTaskById(task.id);

    _startTicker();
    final now = clock.now();
    state = state.copyWith(
      currentTask: updatedTask,
      isPaused: false,
      sessionStartedAt: at,
      now: now,
      shouldShowFinishedForToday: false,
      intervals: state.intervals?.start(at),
      isBreakOver: false,
    );

    if (updatedTask != null) {
      await _scheduleTargetAlarm(updatedTask, now);
    }
    await _scheduleBreakNotification();
    await _scheduleGoalNotification(now);
  }

  /// Handles every phase of the work/break cycle that is over at [now], in order: after the app was suspended for a
  /// while, a work interval and the following break may both be over.
  Future<void> _advanceIntervals(DateTime now) async {
    if (_isAdvancingIntervals) return;
    _isAdvancingIntervals = true;
    try {
      while (true) {
        final intervals = state.intervals;
        final end = intervals?.endsAt;
        if (intervals == null || end == null || !intervals.isDue(now)) break;
        if (intervals.phase == IntervalPhase.work) {
          await _endWorkInterval(end);
        } else {
          await _endBreak(end);
        }
      }
    } finally {
      _isAdvancingIntervals = false;
    }
  }

  /// The work interval is over at [at]: the focus session ends there and the break starts.
  Future<void> _endWorkInterval(DateTime at) async {
    // The break notification is due right now and must still arrive while the app is in the background.
    await _cancelReminders(keepBreakNotification: true);
    final task = state.currentTask;
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId != null) {
      await _sessions.end(sessionId, at, EndReason.interval);
    }
    final updatedTask = task == null ? null : await _repository.getTaskById(task.id);
    final startedAt = state.sessionStartedAt;
    final runningMs = startedAt == null ? 0 : at.difference(startedAt).inMilliseconds;
    _breakSessionId = (await _sessions.start(kind: SessionKind.breakTime, at: at)).id;

    state = state.copyWith(
      currentTask: updatedTask,
      sessionBaseMs: state.sessionBaseMs + (runningMs < 0 ? 0 : runningMs),
      isPaused: true,
      clearSessionStartedAt: true,
      now: clock.now(),
      intervals: state.intervals?.next(at),
      isBreakOver: false,
    );
    await _scheduleBreakOverNotification();
  }

  /// The break is over at [at]: with auto-start the next work interval starts there, otherwise it waits for the user.
  Future<void> _endBreak(DateTime at) async {
    await _closeBreakSession(at, EndReason.interval);
    final intervals = state.intervals!;
    final autoStart = intervals.settings.autoStart;
    state = state.copyWith(intervals: intervals.next(at, start: false), isBreakOver: !autoStart, now: clock.now());
    if (autoStart) await _startWork(at);
  }

  Future<void> _closeBreakSession(DateTime at, EndReason reason) async {
    final breakId = _breakSessionId;
    _breakSessionId = null;
    if (breakId != null) await _sessions.end(breakId, at, reason);
  }

  /// Ends the running break now and starts the next work interval.
  Future<void> skipBreak() async {
    final intervals = state.intervals;
    if (intervals == null || !state.isOnBreak) return;
    final now = clock.now();
    await _notifications.cancel(NotificationIds.breakOver);
    await _closeBreakSession(now, EndReason.skipped);
    state = state.copyWith(intervals: intervals.skip(now));
    await _startWork(now);
  }

  /// Starts the next work interval after a break that is over ([FocusModeState.isBreakOver]).
  Future<void> continueAfterBreak() async {
    if (!state.isBreakOver) return;
    await _startWork(clock.now());
  }

  /// Cancels the target alarm, the goal and the break notification; they are scheduled again when focus continues.
  Future<void> _cancelReminders({bool keepBreakNotification = false}) async {
    await _alarm.cancel();
    await _notifications.cancel(NotificationIds.goalReached);
    if (!keepBreakNotification) await _notifications.cancel(NotificationIds.breakStarts);
  }

  /// Schedules the "goal reached" notification for the moment today's focus time reaches the daily goal, if focus
  /// continues until then. Nothing is scheduled once the goal is reached, so it comes at most once a day; also not on
  /// days off, and not if the goal would only be reached tomorrow.
  Future<void> _scheduleGoalNotification(DateTime now) async {
    final goal = ref.read(focusGoalProvider);
    final today = now.dateOnly;
    final daily = goal.daily;
    if (!goal.isEnabled || daily == null || !goal.isWorkingDay(today)) return;

    final focusToday = (await _sessions.focusTimeByDay(DateRange(today, today)))[today] ?? Duration.zero;
    final remaining = daily - focusToday;
    final at = now.add(remaining);
    if (remaining <= Duration.zero || !at.isBefore(today.nextDay)) return;

    final l10n = ref.read(appLocalizationsProvider);
    final notification = AppNotification(
      id: NotificationIds.goalReached,
      channel: NotificationChannel.reminders,
      title: l10n.notificationGoalReachedTitle,
      body: l10n.notificationGoalReachedBody(l10n.durationLabel(daily)),
    );
    await _notifications.schedule(notification, at);
  }

  Future<void> completeCurrentTask() async {
    final task = state.currentTask;
    if (task == null) {
      return;
    }

    await _cancelReminders();
    _sessionId = null;
    await _repository.completeTask(taskId: task.id, completedAt: clock.now());
    state = state.copyWith(queue: state.queue.skip(1).toList());

    await _loadCurrentTask();
  }

  /// The app lost the user's attention (window unfocused, app switched, screen locked). Only the first of several
  /// lifecycle events of one switch counts.
  void appLeft() {
    if (_awaySince != null) return;
    _awaySince = clock.now();
    _awaySessionId = state.isPaused ? null : _sessionId;
  }

  /// The user is back. Being away from a running focus session for [interruptionThreshold] or longer counts one
  /// interruption on that session (also if it was paused meanwhile because the app went to the background); after
  /// [welcomeBackThreshold], [FocusModeState.awayFor] says how long. Leaving during a break is not a distraction.
  Future<void> appReturned() async {
    final since = _awaySince;
    final sessionId = _awaySessionId;
    _awaySince = null;
    _awaySessionId = null;
    if (since == null || sessionId == null) return;
    final away = clock.now().difference(since);
    if (away < interruptionThreshold) return;
    await _sessions.addInterruption(sessionId);
    if (away >= welcomeBackThreshold) state = state.copyWith(awayFor: away);
  }

  /// The "welcome back" message was shown.
  void clearAwayFor() => state = state.copyWith(clearAwayFor: true);

  /// "I got distracted": counts one interruption on the running focus session.
  Future<void> recordDistraction() async {
    final sessionId = _sessionId;
    if (sessionId == null || state.isPaused) return;
    await _sessions.addInterruption(sessionId);
  }

  /// Parks a thought in the distraction inbox without leaving focus; it is reviewed after the session.
  Future<void> parkThought(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _inbox.addInboxItem(text: trimmed, at: clock.now(), sessionId: state.isPaused ? null : _sessionId);
  }

  Future<void> exitFocus() async {
    _awaySince = null;
    _awaySessionId = null;
    await pauseSession(reason: EndReason.exited);
    await _closeBreakSession(clock.now(), EndReason.exited);
    await _cancelReminders();
    await _notifications.cancel(NotificationIds.breakOver);
    _stopTicker();
    state = state.copyWith(
      clearIntervals: true,
      isBreakOver: false,
      clearCurrentTask: true,
      queue: const [],
      isPaused: true,
      clearSessionStartedAt: true,
      sessionBaseMs: 0,
      now: clock.now(),
      shouldShowFinishedForToday: false,
    );
  }

  /// Focus sessions that were left running, e.g. because the app was killed while focusing. Breaks left open hold no
  /// focus time, so they are closed at their last activity right away instead of asking.
  Future<List<FocusSession>> loadRecoverableSessions() async {
    final recoverable = <FocusSession>[];
    for (final session in await _sessions.unfinishedSessions()) {
      // Sessions this notifier is running are not left over.
      if (session.id == _sessionId || session.id == _breakSessionId) continue;
      if (session.kind == SessionKind.breakTime) {
        await _sessions.end(session.id, session.lastActivityAt, EndReason.recovered);
      } else {
        recoverable.add(session);
      }
    }
    return recoverable;
  }

  Future<void> recoverSessions({required SessionRecovery recovery, required List<FocusSession> sessions}) async {
    final now = clock.now();
    for (final session in sessions) {
      switch (recovery) {
        case SessionRecovery.untilLastActivity:
          await _sessions.end(session.id, session.lastActivityAt, EndReason.recovered);
        case SessionRecovery.untilNow:
          await _sessions.end(session.id, now, EndReason.recovered);
        case SessionRecovery.discard:
          await _sessions.end(session.id, now, EndReason.discarded);
      }
    }
  }

  Future<void> toggleTodoCompletion(int todoId) async {
    final task = state.currentTask;
    if (task == null) return;

    final todo = task.todos.where((todo) => todo.id == todoId).firstOrNull;
    if (todo == null) return;

    final isCompleted = !todo.isCompleted;
    state = state.copyWith(
      currentTask: task.copyWith(todos: [for (final candidate in task.todos) candidate.id == todoId ? candidate.copyWith(isCompleted: isCompleted) : candidate]),
    );

    await _repository.setTodoCompletion(todoId: todoId, isCompleted: isCompleted);
  }

  Future<void> dismissAlarm() async {
    await _alarm.cancel();
    state = state.copyWith(shouldShowAlarm: false);
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = clock.now();
    if (state.intervals?.isDue(now) ?? false) {
      // The interval end has priority over the target alarm at the same moment.
      unawaited(_advanceIntervals(now));
      return;
    }

    final task = state.currentTask;
    final remaining = task == null || state.isPaused ? null : _remainingUntilTarget(task, now);
    final reachedTarget = remaining != null && remaining <= Duration.zero && !state.hasAlarmPlayedForCurrentTask && !_isTargetAlarmDeferred(now);

    final runningId = state.isPaused ? _breakSessionId : _sessionId;
    if (runningId != null && (_lastHeartbeat == null || now.difference(_lastHeartbeat!) >= heartbeatInterval)) {
      _lastHeartbeat = now;
      unawaited(_sessions.heartbeat(runningId, now));
    }

    // The alarm itself is rung by [TargetAlarm]; here we only show the in-app dialog.
    state = state.copyWith(now: now, shouldShowAlarm: reachedTarget || state.shouldShowAlarm, hasAlarmPlayedForCurrentTask: reachedTarget || state.hasAlarmPlayedForCurrentTask);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _lastHeartbeat = null;
  }

  void clearFinishedForToday() {
    state = state.copyWith(shouldShowFinishedForToday: false);
  }
}
