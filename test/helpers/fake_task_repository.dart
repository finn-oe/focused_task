import 'dart:async';

import 'package:clock/clock.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/categories/domain/i_category_repository.dart';
import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/inbox/domain/i_inbox_repository.dart';
import 'package:focused_task/features/inbox/domain/inbox_item.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart' as focus_time;
import 'package:focused_task/features/sessions/domain/i_focus_session_repository.dart';
import 'package:focused_task/features/tasks/domain/entities/day_summary.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_calculator.dart';
import 'package:focused_task/features/tasks/domain/stats/stats_report.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

/// Simple in-memory [ITaskRepository], [IFocusSessionRepository], [ICategoryRepository] **and** [IInboxRepository] for
/// widget and notifier tests, so tasks, sessions, categories and parked thoughts share one consistent store. Override
/// all four providers with the same instance.
///
/// It mirrors the behaviour of the Drift implementation closely enough for presentation-layer tests.
/// Repository behaviour itself is tested against a real in-memory database.
///
/// Seeded tasks with a `latestStart` (and `lastSeenAt`) get an open session, like data left by a crash.
class FakeTaskRepository implements ITaskRepository, IFocusSessionRepository, ICategoryRepository, IInboxRepository {
  FakeTaskRepository({List<TaskEntity> tasks = const [], List<FocusSession> sessions = const [], List<TaskCategory> categories = const []}) {
    for (final category in categories) {
      _categories[category.id] = category;
    }
    _nextCategoryId = _categories.keys.fold(0, (max, id) => id > max ? id : max) + 1;
    for (final task in tasks) {
      _tasks[task.id] = task.copyWith(clearLatestStart: true);
      final start = task.latestStart;
      if (start != null) {
        _sessions.add(FocusSession(id: _nextSessionId++, taskId: task.id, kind: SessionKind.focus, startedAt: start, lastSeenAt: task.lastSeenAt ?? start));
      }
    }
    for (final session in sessions) {
      _sessions.add(session);
      if (session.id >= _nextSessionId) _nextSessionId = session.id + 1;
    }
    _nextId = _tasks.keys.fold(0, (max, id) => id > max ? id : max) + 1;
  }

  final Map<int, TaskEntity> _tasks = {};
  final Map<int, TaskCategory> _categories = {};
  late int _nextCategoryId;
  final List<FocusSession> _sessions = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late int _nextId;
  int _nextSessionId = 1;

  List<TaskEntity> get tasks => _sorted(_tasks.values);

  /// All sessions, oldest first.
  List<FocusSession> get sessions => List.unmodifiable(_sessions);

  TaskEntity task(int id) => _withSession(_tasks[id]!);

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  FocusSession? _openSessionOf(int taskId) => _sessions.where((session) => session.isOpen && session.taskId == taskId).firstOrNull;

  /// Adds the running state of the task's open session, like the Drift implementation.
  TaskEntity _withSession(TaskEntity task) {
    final open = _openSessionOf(task.id);
    return open == null ? task : task.copyWith(latestStart: open.startedAt, lastSeenAt: open.lastSeenAt);
  }

  List<TaskEntity> _sorted(Iterable<TaskEntity> tasks) => tasks.map(_withSession).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<TaskEntity> _forDay(DateTime day) => _sorted(_tasks.values.where((task) => _day(task.assignedDate) == _day(day)));

  void _put(TaskEntity task) {
    _tasks[task.id] = task;
    _changes.add(null);
  }

  void _update(int id, TaskEntity Function(TaskEntity task) update) {
    final task = _tasks[id];
    if (task != null) {
      _put(update(task));
    }
  }

  void _replaceSession(FocusSession session) {
    _sessions[_sessions.indexWhere((candidate) => candidate.id == session.id)] = session;
    _changes.add(null);
  }

  void _addTrackedTime(int? taskId, SessionKind kind, Duration duration) {
    if (taskId == null || kind != SessionKind.focus || duration <= Duration.zero) return;
    _update(taskId, (task) => task.copyWith(timeSpent: task.timeSpent + duration.inMilliseconds));
  }

  // --- ITaskRepository ----------------------------------------------------------------------------------------------

  @override
  Stream<List<TaskEntity>> watchTasksForDay(DateTime day) async* {
    yield _forDay(day);
    yield* _changes.stream.map((_) => _forDay(day));
  }

  @override
  Future<List<TaskEntity>> getTasksForDay(DateTime day) async => _forDay(day);

  @override
  Future<TaskEntity?> getTaskById(int id) async => _tasks.containsKey(id) ? task(id) : null;

  bool _isIn(TaskEntity task, DateRange range) => !_day(task.assignedDate).isBefore(range.start) && !_day(task.assignedDate).isAfter(range.end);

  List<TaskEntity> _inRangeTasks(DateRange range) {
    return _tasks.values.where((task) => _isIn(task, range)).toList()..sort((a, b) {
      final byDay = a.assignedDate.compareTo(b.assignedDate);
      return byDay != 0 ? byDay : a.sortOrder.compareTo(b.sortOrder);
    });
  }

  @override
  Stream<List<TaskEntity>> watchTasksInRange(DateRange range) async* {
    yield _inRangeTasks(range);
    yield* _changes.stream.map((_) => _inRangeTasks(range));
  }

  @override
  Future<Map<DateTime, DaySummary>> getDaySummaries(DateRange range) async {
    final result = <DateTime, DaySummary>{};
    for (final task in _inRangeTasks(range)) {
      final day = _day(task.assignedDate);
      final summary = result[day] ?? DaySummary.empty;
      result[day] = summary.copyWith(total: summary.total + 1, completed: summary.completed + (task.isCompleted ? 1 : 0));
    }
    focus_time.focusTimeByDay(_sessions, range).forEach((day, time) => result[day] = (result[day] ?? DaySummary.empty).copyWith(focusTime: time));
    return result;
  }

  @override
  Future<int> createTask({
    required String title,
    String? description,
    required DateTime assignedDate,
    required String sortOrder,
    TaskPriority priority = TaskPriority.low,
    int? targetDurationMinutes,
    int? categoryId,
  }) async {
    final id = _nextId++;
    _put(
      TaskEntity(
        id: id,
        title: title,
        description: description,
        assignedDate: _day(assignedDate),
        sortOrder: sortOrder,
        isCompleted: false,
        priority: priority,
        timeSpent: 0,
        latestStart: null,
        targetDurationMinutes: targetDurationMinutes,
        todos: const [],
        categoryId: categoryId,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTaskDetails({
    required int taskId,
    required String title,
    String? description,
    int? targetDurationMinutes,
    DateTime? assignedDate,
    TaskPriority? priority,
    required int? categoryId,
  }) async {
    _update(
      taskId,
      (task) => task.copyWith(
        title: title,
        description: description,
        priority: priority,
        targetDurationMinutes: targetDurationMinutes,
        clearTargetDuration: targetDurationMinutes == null,
        assignedDate: assignedDate == null ? null : _day(assignedDate),
        categoryId: categoryId,
        clearCategory: categoryId == null,
      ),
    );
  }

  @override
  Future<void> updateTaskOrder({required int taskId, required String sortOrder}) async {
    _update(taskId, (task) => task.copyWith(sortOrder: sortOrder));
  }

  @override
  Future<List<TaskEntity>> getOpenTasksBetween({required DateTime start, required DateTime end}) async {
    final first = _day(start);
    final last = _day(end);
    final open = _tasks.values.where((task) => !task.isCompleted && !_day(task.assignedDate).isBefore(first) && !_day(task.assignedDate).isAfter(last));
    return open.map(_withSession).toList()..sort((a, b) {
      final byDay = a.assignedDate.compareTo(b.assignedDate);
      return byDay != 0 ? byDay : a.sortOrder.compareTo(b.sortOrder);
    });
  }

  @override
  Future<List<int>> moveTasks({required List<int> taskIds, required DateTime to}) async {
    final day = _day(to);
    final target = _forDay(day);
    var last = target.isEmpty ? null : target.last.sortOrder;
    final moved = <int>[];
    for (final id in taskIds) {
      final task = _tasks[id];
      if (task == null || task.isCompleted || _day(task.assignedDate) == day) continue;
      last = FractionalIndexer.between(last, null);
      _put(task.copyWith(assignedDate: day, sortOrder: last));
      moved.add(id);
    }
    return moved;
  }

  @override
  Future<void> setTaskCompletion({required int taskId, required bool isCompleted}) async {
    if (isCompleted) return completeTask(taskId: taskId, completedAt: clock.now());
    _update(taskId, (task) => task.copyWith(isCompleted: false));
  }

  /// Adds the task title like the Drift join does.
  FocusSession _withTitle(FocusSession session) {
    final title = _tasks[session.taskId]?.title;
    if (title == null || session.taskTitle != null) return session;
    return FocusSession(
      id: session.id,
      taskId: session.taskId,
      kind: session.kind,
      startedAt: session.startedAt,
      lastSeenAt: session.lastSeenAt,
      endedAt: session.endedAt,
      endReason: session.endReason,
      interruptions: session.interruptions,
      taskTitle: title,
      taskCategoryId: _tasks[session.taskId]?.categoryId,
    );
  }

  @override
  Future<StatsReport> getStatsReport(StatsQuery query) async {
    final range = query.range;
    final inRange = _tasks.values.where((task) => !_day(task.assignedDate).isBefore(range.start) && !_day(task.assignedDate).isAfter(range.end));
    final overlapping = _inRange(range.start, range.end.nextDay);
    return const StatsCalculator().compute(query, tasks: inRange, sessions: [for (final session in overlapping) _withTitle(session)], today: clock.now());
  }

  @override
  Future<void> completeTask({required int taskId, required DateTime completedAt}) async {
    final open = _openSessionOf(taskId);
    if (open != null) await end(open.id, completedAt, EndReason.completed);
    _update(taskId, (task) => task.copyWith(isCompleted: true));
  }

  @override
  Future<void> deleteTask(int taskId) async {
    _tasks.remove(taskId);
    for (final session in _sessions.where((session) => session.taskId == taskId).toList()) {
      _replaceSession(session.copyWith(clearTaskId: true));
    }
    _changes.add(null);
  }

  List<int> _cleanupCandidates(int days) {
    final now = clock.now();
    final cutoff = DateTime(now.year, now.month, now.day - days);
    return _tasks.values.where((task) => task.isCompleted && _openSessionOf(task.id) == null && task.assignedDate.isBefore(cutoff)).map((task) => task.id).toList();
  }

  @override
  Future<int> countCompletedTasksOlderThanDays(int days) async => _cleanupCandidates(days).length;

  @override
  Future<int> deleteCompletedTasksOlderThanDays(int days) async {
    final ids = _cleanupCandidates(days);
    for (final id in ids) {
      await deleteTask(id);
    }
    return ids.length;
  }

  @override
  Future<void> replaceTaskTodos(int taskId, List<TaskTodoEntity> newTodos) async {
    var nextTodoId = 1;
    _update(taskId, (task) => task.copyWith(todos: [for (final todo in newTodos) todo.copyWith(id: todo.id ?? nextTodoId++)]));
  }

  @override
  Future<void> setTodoCompletion({required int todoId, required bool isCompleted}) async {
    for (final task in _tasks.values.toList()) {
      if (task.todos.any((todo) => todo.id == todoId)) {
        _put(task.copyWith(todos: [for (final todo in task.todos) todo.id == todoId ? todo.copyWith(isCompleted: isCompleted) : todo]));
      }
    }
  }

  // --- IFocusSessionRepository --------------------------------------------------------------------------------------

  @override
  Future<FocusSession> start({int? taskId, SessionKind kind = SessionKind.focus, required DateTime at}) async {
    for (final open in _sessions.where((session) => session.isOpen).toList()) {
      await end(open.id, open.lastActivityAt, EndReason.recovered);
    }
    final session = FocusSession(id: _nextSessionId++, taskId: taskId, kind: kind, startedAt: at, lastSeenAt: at);
    _sessions.add(session);
    _changes.add(null);
    return session;
  }

  @override
  Future<void> heartbeat(int id, DateTime at) async {
    final session = _sessions.where((session) => session.id == id && session.isOpen).firstOrNull;
    if (session != null) _replaceSession(session.copyWith(lastSeenAt: at));
  }

  @override
  Future<void> end(int id, DateTime at, EndReason reason) async {
    final session = _sessions.where((session) => session.id == id).firstOrNull;
    if (session == null || !session.isOpen) return;
    final endAt = reason == EndReason.discarded || at.isBefore(session.startedAt) ? session.startedAt : at;
    _replaceSession(session.copyWith(endedAt: endAt, endReason: reason));
    _addTrackedTime(session.taskId, session.kind, endAt.difference(session.startedAt));
  }

  @override
  Future<void> addInterruption(int id) async {
    final session = _sessions.where((session) => session.id == id).firstOrNull;
    if (session != null) _replaceSession(session.copyWith(interruptions: session.interruptions + 1));
  }

  @override
  Future<FocusSession?> openSession() async => _sessions.where((session) => session.isOpen).lastOrNull;

  @override
  Future<List<FocusSession>> unfinishedSessions() async {
    return [
      for (final session in _sessions.where((session) => session.isOpen))
        FocusSession(
          id: session.id,
          taskId: session.taskId,
          kind: session.kind,
          startedAt: session.startedAt,
          lastSeenAt: session.lastSeenAt,
          taskTitle: _tasks[session.taskId]?.title,
        ),
    ];
  }

  List<FocusSession> _inRange(DateTime start, DateTime endExclusive) {
    return _sessions.where((session) => session.startedAt.isBefore(endExclusive) && (session.isOpen || session.endedAt!.isAfter(start))).toList();
  }

  @override
  Stream<List<FocusSession>> watchInRange(DateTime start, DateTime endExclusive) async* {
    yield _inRange(start, endExclusive);
    yield* _changes.stream.map((_) => _inRange(start, endExclusive));
  }

  @override
  Future<Map<DateTime, Duration>> focusTimeByDay(DateRange range) async => focus_time.focusTimeByDay(_sessions, range);

  @override
  Future<void> addManualTime({required int taskId, required DateTime day, required Duration duration}) async {
    final start = DateTime(day.year, day.month, day.day, 12);
    final session = FocusSession(
      id: _nextSessionId++,
      taskId: taskId,
      kind: SessionKind.focus,
      startedAt: start,
      endedAt: start.add(duration),
      lastSeenAt: start.add(duration),
      endReason: EndReason.manual,
    );
    _sessions.add(session);
    _addTrackedTime(taskId, SessionKind.focus, duration);
  }

  // --- ICategoryRepository ------------------------------------------------------------------------------------------

  /// All categories in their order.
  List<TaskCategory> get categories => _categories.values.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _ensureUniqueName(String name, {int? exceptId}) {
    if (_categories.values.any((category) => category.id != exceptId && category.name.toLowerCase() == name.toLowerCase())) {
      throw DuplicateCategoryNameException(name);
    }
  }

  @override
  Stream<List<TaskCategory>> watchCategories() async* {
    yield categories;
    yield* _changes.stream.map((_) => categories);
  }

  @override
  Future<int> createCategory({required String name, required int colorIndex}) async {
    _ensureUniqueName(name.trim());
    final id = _nextCategoryId++;
    final last = categories.lastOrNull?.sortOrder;
    _categories[id] = TaskCategory(id: id, name: name.trim(), colorIndex: colorIndex, sortOrder: FractionalIndexer.between(last, null));
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updateCategory(TaskCategory category) async {
    _ensureUniqueName(category.name.trim(), exceptId: category.id);
    final existing = _categories[category.id];
    if (existing == null) return;
    _categories[category.id] = existing.copyWith(name: category.name.trim(), colorIndex: category.colorIndex, archived: category.archived);
    _changes.add(null);
  }

  @override
  Future<void> updateCategoryOrder({required int categoryId, required String sortOrder}) async {
    final existing = _categories[categoryId];
    if (existing == null) return;
    _categories[categoryId] = existing.copyWith(sortOrder: sortOrder);
    _changes.add(null);
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
    _categories.remove(categoryId);
    for (final task in _tasks.values.where((task) => task.categoryId == categoryId).toList()) {
      _tasks[task.id] = task.copyWith(clearCategory: true);
    }
    _changes.add(null);
  }

  @override
  Future<void> setTaskCategory({required int taskId, required int? categoryId}) async {
    _update(taskId, (task) => task.copyWith(categoryId: categoryId, clearCategory: categoryId == null));
  }

  // --- IInboxRepository ---------------------------------------------------------------------------------------------

  final List<InboxItem> _inbox = [];
  int _nextInboxId = 1;

  /// All parked thoughts, oldest first.
  List<InboxItem> get inboxItems => List.unmodifiable(_inbox);

  List<InboxItem> get _openInbox => _inbox.where((item) => !item.isResolved).toList(growable: false);

  @override
  Future<int> addInboxItem({required String text, required DateTime at, int? sessionId}) async {
    final id = _nextInboxId++;
    _inbox.add(InboxItem(id: id, text: text.trim(), createdAt: at, sessionId: sessionId));
    _changes.add(null);
    return id;
  }

  @override
  Stream<List<InboxItem>> watchOpenInboxItems() async* {
    yield _openInbox;
    yield* _changes.stream.map((_) => _openInbox);
  }

  @override
  Stream<List<InboxItem>> watchInboxItemsCreated(DateTime start, DateTime endExclusive, {int limit = 5}) async* {
    List<InboxItem> created() => _inbox.reversed.where((item) => !item.createdAt.isBefore(start) && item.createdAt.isBefore(endExclusive)).take(limit).toList(growable: false);
    yield created();
    yield* _changes.stream.map((_) => created());
  }

  void _setResolved(int id, DateTime? at) {
    final index = _inbox.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _inbox[index] = _inbox[index].copyWith(resolvedAt: at, clearResolvedAt: at == null);
    _changes.add(null);
  }

  @override
  Future<void> resolveInboxItem(int id, DateTime at) async => _setResolved(id, at);

  @override
  Future<void> reopenInboxItem(int id) async => _setResolved(id, null);
}
