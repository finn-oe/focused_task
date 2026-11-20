import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/reminders/domain/reminder_scheduler.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// What the reminders are currently scheduled for (#10).
class RemindersState {
  const RemindersState({this.taskReminders = const [], this.dailyPlanningAt, this.inactivityAt});

  final List<PlannedTaskReminder> taskReminders;
  final DateTime? dailyPlanningAt;
  final DateTime? inactivityAt;
}

/// When the app was opened: counts as activity for the inactivity reminder, so opening the app doesn't nag at once.
final appOpenedAtProvider = Provider<DateTime>((ref) => clock.now());

/// Keeps the system notifications in line with the tasks, sessions and settings (#10): task reminders, the daily
/// planning nudge and the inactivity reminder. Replans on startup and whenever one of them changes. Kept alive by the
/// app root.
class RemindersNotifier extends Notifier<RemindersState> {
  /// Task reminders handed to the system, as `taskId|reminder ms|anchor ms` (see [DeliveredReminder]).
  static const deliveredKey = 'reminders.delivered';

  static const _scheduler = ReminderScheduler();

  late ReminderSettings _settings;
  late Set<int> _workingDays;
  late NotificationService _notifications;
  late SharedPreferences _prefs;
  late AppLocalizations _l10n;
  late DateTime _openedAt;

  List<TaskEntity> _scheduledTasks = const [];
  Set<DateTime> _daysWithTasks = const {};
  List<FocusSession> _recentSessions = const [];
  bool _replanQueued = false;
  Future<void> _replanning = Future.value();

  @override
  RemindersState build() {
    _settings = ref.watch(reminderSettingsProvider);
    _workingDays = ref.watch(focusGoalProvider.select((goal) => goal.workingDays));
    _notifications = ref.watch(notificationServiceProvider);
    _prefs = ref.watch(sharedPreferencesProvider);
    _l10n = ref.watch(appLocalizationsProvider);
    _openedAt = ref.watch(appOpenedAtProvider);
    final tasks = ref.watch(taskRepositoryProvider);
    final sessions = ref.watch(focusSessionRepositoryProvider);

    final today = clock.now().dateOnly;
    final subscriptions = <StreamSubscription<Object?>>[
      tasks.watchScheduledOpenTasks().listen((scheduled) {
        _scheduledTasks = scheduled;
        _queueReplan();
      }),
      if (_settings.dailyPlanning)
        tasks.watchTasksInRange(DateRange(today, today.addDays(ReminderScheduler.lookAheadDays))).listen((inRange) {
          _daysWithTasks = {for (final task in inRange) task.assignedDate.dateOnly};
          _queueReplan();
        }),
      if (_settings.inactivity)
        sessions.watchInRange(today.addDays(-1), DateTime(9999)).listen((recent) {
          _recentSessions = recent;
          _queueReplan();
        }),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
    _queueReplan();
    return const RemindersState();
  }

  /// Several changes in a row (e.g. the first events of all streams) lead to one replan.
  void _queueReplan() {
    if (_replanQueued) return;
    _replanQueued = true;
    scheduleMicrotask(() {
      _replanQueued = false;
      // A failed replan must not stop later ones; the next change tries again.
      _replanning = _replanning.then((_) => _replan()).catchError((Object error, StackTrace stack) => debugPrint('Planning reminders failed: $error $stack'));
    });
  }

  Future<void> _replan() async {
    if (!ref.mounted) return;
    // Replans can run before the app's localizations have loaded the date formats.
    await initializeDateFormatting(_l10n.localeName);
    final now = clock.now();
    final taskReminders = await _replanTasks(now);
    final dailyAt = _scheduler.nextDailyPlanning(_settings, workingDays: _workingDays, daysWithTasks: _daysWithTasks, now: now);
    await _scheduleOrCancel(
      NotificationIds.dailyPlanning,
      dailyAt,
      () => AppNotification(id: NotificationIds.dailyPlanning, channel: NotificationChannel.reminders, title: _l10n.reminderPlanDayTitle, body: _l10n.reminderPlanDayBody),
    );

    final focus = _recentSessions.where((session) => session.kind == SessionKind.focus);
    final running = focus.any((session) => session.isOpen);
    final lastEnd = focus.map((session) => session.endedAt).whereType<DateTime>().fold<DateTime?>(null, (latest, end) => latest == null || end.isAfter(latest) ? end : latest);
    final lastActivity = lastEnd != null && lastEnd.isAfter(_openedAt) ? lastEnd : _openedAt;
    final inactivityAt = _scheduler.nextInactivity(_settings, workingDays: _workingDays, lastActivity: lastActivity, sessionRunning: running, now: now);
    await _scheduleOrCancel(
      NotificationIds.inactivity,
      inactivityAt,
      () => AppNotification(
        id: NotificationIds.inactivity,
        channel: NotificationChannel.reminders,
        title: _l10n.reminderInactivityTitle,
        body: _l10n.reminderInactivityBody(_l10n.durationLabel(_settings.idle)),
      ),
    );
    if (ref.mounted) state = RemindersState(taskReminders: taskReminders, dailyPlanningAt: dailyAt, inactivityAt: inactivityAt);
  }

  Future<void> _scheduleOrCancel(int id, DateTime? at, AppNotification Function() notification) async {
    if (at == null) {
      await _notifications.cancel(id);
    } else {
      await _notifications.schedule(notification(), at);
    }
  }

  Future<List<PlannedTaskReminder>> _replanTasks(DateTime now) async {
    final delivered = _loadDelivered();
    final planned = _scheduler.planTasks(_scheduledTasks, _settings, now, delivered: delivered);
    final plannedIds = {for (final reminder in planned) reminder.task.id};

    // Still pending in the system but no longer wanted (task done, times changed, reminder off, …).
    for (final MapEntry(key: taskId, value: previous) in delivered.entries) {
      if (!plannedIds.contains(taskId) && previous.at.isAfter(now)) await _notifications.cancel(NotificationIds.taskReminder(taskId));
    }

    final next = <int, DeliveredReminder>{
      // Fired ones are kept while the task still has times, so they aren't shown again.
      for (final task in _scheduledTasks)
        if (delivered[task.id] case final previous? when !previous.at.isAfter(now)) task.id: previous,
    };
    for (final reminder in planned) {
      final notification = AppNotification(
        id: NotificationIds.taskReminder(reminder.task.id),
        channel: NotificationChannel.reminders,
        title: reminder.task.title,
        body: _taskBody(reminder.time),
      );
      if (reminder.immediate) {
        await _notifications.show(notification);
        next[reminder.task.id] = DeliveredReminder(at: now, anchor: reminder.time.anchor);
      } else {
        await _notifications.schedule(notification, reminder.time.at);
        next[reminder.task.id] = DeliveredReminder(at: reminder.time.at, anchor: reminder.time.anchor);
      }
    }
    await _saveDelivered(next);
    return planned;
  }

  String _taskBody(TaskReminderTime time) {
    final locale = _l10n.localeName;
    final sameDay = time.anchor.isSameDate(time.at);
    final label = (sameDay ? DateFormat.jm(locale) : DateFormat.E(locale).add_jm()).format(time.anchor);
    return switch (time.kind) {
      TaskReminderKind.start => _l10n.reminderTaskStartBody(label),
      TaskReminderKind.due => _l10n.reminderTaskDueBody(label),
    };
  }

  Map<int, DeliveredReminder> _loadDelivered() {
    final result = <int, DeliveredReminder>{};
    for (final entry in _prefs.getStringList(deliveredKey) ?? const <String>[]) {
      final parts = entry.split('|').map(int.tryParse).toList();
      if (parts.length != 3 || parts.contains(null)) continue;
      result[parts[0]!] = DeliveredReminder(at: DateTime.fromMillisecondsSinceEpoch(parts[1]!), anchor: DateTime.fromMillisecondsSinceEpoch(parts[2]!));
    }
    return result;
  }

  Future<void> _saveDelivered(Map<int, DeliveredReminder> delivered) {
    return _prefs.setStringList(deliveredKey, [
      for (final MapEntry(key: taskId, value: reminder) in delivered.entries) '$taskId|${reminder.at.millisecondsSinceEpoch}|${reminder.anchor.millisecondsSinceEpoch}',
    ]);
  }

  /// Waits until stream events and the replans they queued are done (for tests).
  Future<void> get settled async {
    for (var round = 0; round < 10; round++) {
      await Future<void>.delayed(Duration.zero);
      await _replanning;
    }
  }
}
