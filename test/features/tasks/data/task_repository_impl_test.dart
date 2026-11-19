import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

void main() {
  late AppDatabase database;
  late TaskRepositoryImpl repository;
  late FocusSessionRepositoryImpl sessions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TaskRepositoryImpl(database);
    sessions = FocusSessionRepositoryImpl(database);
  });

  tearDown(() => database.close());

  Future<int> createTask({DateTime? day, String title = 'Task'}) => repository.createTask(title: title, assignedDate: day ?? DateTime.now(), sortOrder: 'a0');

  group('setTaskCompletion', () {
    test('closes a running session so the timer stops counting', () async {
      final id = await createTask();
      await sessions.start(taskId: id, at: DateTime.now().subtract(const Duration(hours: 1)));

      await repository.setTaskCompletion(taskId: id, isCompleted: true);

      final task = (await repository.getTaskById(id))!;
      expect(task.isCompleted, isTrue);
      expect(task.latestStart, isNull);
      expect(Duration(milliseconds: task.timeSpent).inMinutes, 60);
      expect((await database.select(database.focusSessions).getSingle()).endReason, 'completed');

      final later = task.elapsedAt(DateTime.now().add(const Duration(hours: 5)));
      expect(later.inMinutes, 60, reason: 'elapsed time must not grow after completion');
    });

    test('un-completing does not restart the timer', () async {
      final id = await createTask();
      await repository.setTaskCompletion(taskId: id, isCompleted: true);
      await repository.setTaskCompletion(taskId: id, isCompleted: false);

      final task = (await repository.getTaskById(id))!;
      expect(task.isCompleted, isFalse);
      expect(task.isRunning, isFalse);
    });
  });

  test('priority round-trips through create and update', () async {
    final id = await repository.createTask(title: 'Task', assignedDate: DateTime.now(), sortOrder: 'a0', priority: TaskPriority.medium);
    expect((await repository.getTaskById(id))!.priority, TaskPriority.medium);

    await repository.updateTaskDetails(taskId: id, title: 'Task', priority: TaskPriority.high);
    expect((await repository.getTaskById(id))!.priority, TaskPriority.high);

    await repository.updateTaskDetails(taskId: id, title: 'Renamed');
    expect((await repository.getTaskById(id))!.priority, TaskPriority.high, reason: 'omitting the priority keeps it');
  });

  test('countCompletedTasksOlderThanDays matches what cleanup deletes', () async {
    final old = DateTime.now().subtract(const Duration(days: 40));
    final done = await createTask(day: old);
    await repository.setTaskCompletion(taskId: done, isCompleted: true);
    await createTask(day: old); // not completed
    await repository.setTaskCompletion(taskId: await createTask(), isCompleted: true); // recent

    expect(await repository.countCompletedTasksOlderThanDays(30), 1);
    expect(await repository.deleteCompletedTasksOlderThanDays(30), 1);
    expect(await repository.countCompletedTasksOlderThanDays(30), 0);
  });

  group('focus sessions', () {
    final start = DateTime(2026, 11, 17, 9);

    test('the running state of a task comes from its open session, including the heartbeat', () async {
      final id = await createTask();
      final session = await sessions.start(taskId: id, at: start);
      expect((await repository.getTaskById(id))!.lastActivityAt, start);

      await sessions.heartbeat(session.id, start.add(const Duration(minutes: 20)));
      expect((await repository.getTaskById(id))!.lastActivityAt, start.add(const Duration(minutes: 20)));

      await sessions.end(session.id, start.add(const Duration(minutes: 25)), EndReason.paused);
      final paused = (await repository.getTaskById(id))!;
      expect(paused.isRunning, isFalse);
      expect(paused.lastActivityAt, isNull);
      expect(Duration(milliseconds: paused.timeSpent), const Duration(minutes: 25));
    });

    test('the plan list reflects running sessions', () async {
      final id = await createTask(day: start);
      await sessions.start(taskId: id, at: start);

      final tasks = await repository.watchTasksForDay(start).first;
      expect(tasks.single.latestStart, start);
    });

    test('at most one session is open: starting closes the previous one at its last activity', () async {
      final first = await createTask(title: 'first');
      final second = await createTask(title: 'second');
      final leftover = await sessions.start(taskId: first, at: start);
      await sessions.heartbeat(leftover.id, start.add(const Duration(minutes: 10)));

      await sessions.start(taskId: second, at: start.add(const Duration(hours: 2)));

      final open = await sessions.openSession();
      expect(open?.taskId, second);
      expect(Duration(milliseconds: (await repository.getTaskById(first))!.timeSpent), const Duration(minutes: 10));
      expect((await sessions.unfinishedSessions()).map((session) => session.taskTitle), ['second']);
    });

    test('discarding drops the time; ending twice changes nothing', () async {
      final id = await createTask();
      final session = await sessions.start(taskId: id, at: start);

      await sessions.end(session.id, start.add(const Duration(hours: 1)), EndReason.discarded);
      await sessions.end(session.id, start.add(const Duration(hours: 2)), EndReason.paused);

      expect((await repository.getTaskById(id))!.timeSpent, 0);
      final row = await database.select(database.focusSessions).getSingle();
      expect(row.endReason, 'discarded');
      expect(row.endedAt, start);
    });

    test('30 minutes worked today on a task planned for another day count today', () async {
      final today = DateTime.now().dateOnly;
      final id = await createTask(day: today.addDays(3));
      final session = await sessions.start(taskId: id, at: today.add(const Duration(hours: 9)));
      await sessions.end(session.id, today.add(const Duration(hours: 9, minutes: 30)), EndReason.paused);

      final todayStats = await repository.getTaskStats(start: today, end: today);
      expect(todayStats.totalFocusMinutes, 30);
      expect(todayStats.totalTasks, 0, reason: 'task counts still use the assigned day');

      final plannedDay = await repository.getTaskStats(start: today.addDays(3), end: today.addDays(3));
      expect(plannedDay.totalFocusMinutes, 0);
      expect(plannedDay.totalTasks, 1);
    });

    test('deleting a task keeps its sessions so totals stay correct', () async {
      final today = DateTime.now().dateOnly;
      final id = await createTask(day: today);
      final session = await sessions.start(taskId: id, at: today.add(const Duration(hours: 8)));
      await sessions.end(session.id, today.add(const Duration(hours: 8, minutes: 45)), EndReason.completed);

      await repository.deleteTask(id);

      final row = await database.select(database.focusSessions).getSingle();
      expect(row.taskId, isNull);
      expect((await repository.getTaskStats(start: today, end: today)).totalFocusMinutes, 45);
      expect(await sessions.focusTimeByDay(DateRange(today, today)), {today: const Duration(minutes: 45)});
    });

    test('manual time is added as a closed session and to the tracked total', () async {
      final day = DateTime(2026, 11, 10);
      final id = await createTask(day: day);

      await sessions.addManualTime(taskId: id, day: day, duration: const Duration(minutes: 50));

      expect(Duration(milliseconds: (await repository.getTaskById(id))!.timeSpent), const Duration(minutes: 50));
      final row = await database.select(database.focusSessions).getSingle();
      expect((row.startedAt, row.endReason), (DateTime(2026, 11, 10, 12), 'manual'));
      expect(await sessions.focusTimeByDay(DateRange(day, day)), {day: const Duration(minutes: 50)});
    });

    test('watchInRange emits sessions overlapping the range', () async {
      final id = await createTask();
      final session = await sessions.start(taskId: id, at: DateTime(2026, 11, 16, 23, 30));
      await sessions.end(session.id, DateTime(2026, 11, 17, 0, 30), EndReason.paused);

      final onDay = await sessions.watchInRange(DateTime(2026, 11, 17), DateTime(2026, 11, 18)).first;
      expect(onDay.map((session) => session.id), [session.id]);
      expect(await sessions.watchInRange(DateTime(2026, 11, 18), DateTime(2026, 11, 19)).first, isEmpty);
    });
  });

  group('moveTasks', () {
    final past = DateTime(2026, 11, 10);
    final today = DateTime(2026, 11, 17);

    test('keeps id, sub-tasks, tracked time and session history; the old day no longer counts the task', () async {
      final id = await repository.createTask(title: 'Report', assignedDate: past, sortOrder: 'a0');
      await repository.replaceTaskTodos(id, const [TaskTodoEntity(title: 'Draft', isCompleted: true, sortOrder: '00000')]);
      await sessions.addManualTime(taskId: id, day: past, duration: const Duration(minutes: 40));
      final todayBefore = await repository.getTaskStats(start: today, end: today);

      expect(await repository.moveTasks(taskIds: [id], to: today), [id]);

      final moved = (await repository.getTaskById(id))!;
      expect(moved.assignedDate, today);
      expect(moved.todos.map((todo) => (todo.title, todo.isCompleted)), [('Draft', true)]);
      expect(Duration(milliseconds: moved.timeSpent), const Duration(minutes: 40));
      expect(await sessions.focusTimeByDay(DateRange(past, today)), {past: const Duration(minutes: 40)}, reason: 'history stays on the day it was worked');

      final pastStats = await repository.getTaskStats(start: past, end: past);
      expect((pastStats.totalTasks, pastStats.totalFocusMinutes), (0, 40));
      final todayAfter = await repository.getTaskStats(start: today, end: today);
      expect(todayAfter.totalFocusMinutes, todayBefore.totalFocusMinutes, reason: 'moving adds no focus time to today');
    });

    test('appends after the tasks of the target day, in the given order, and skips completed tasks', () async {
      final existing = await repository.createTask(title: 'Existing', assignedDate: today, sortOrder: 'a5');
      final first = await repository.createTask(title: 'First', assignedDate: past, sortOrder: 'a0');
      final second = await repository.createTask(title: 'Second', assignedDate: past.addDays(1), sortOrder: 'a0');
      final done = await repository.createTask(title: 'Done', assignedDate: past, sortOrder: 'a1');
      await repository.setTaskCompletion(taskId: done, isCompleted: true);

      expect(await repository.moveTasks(taskIds: [first, second, done], to: today), [first, second]);

      expect((await repository.getTasksForDay(today)).map((task) => task.id), [existing, first, second]);
      expect((await repository.getTaskById(done))!.assignedDate, past, reason: 'completed tasks can only be copied');
    });

    test('getOpenTasksBetween lists open tasks by day, then plan order', () async {
      final later = await repository.createTask(title: 'Later', assignedDate: past.addDays(2), sortOrder: 'a0');
      final b = await repository.createTask(title: 'B', assignedDate: past, sortOrder: 'a1');
      final a = await repository.createTask(title: 'A', assignedDate: past, sortOrder: 'a0');
      final done = await repository.createTask(title: 'Done', assignedDate: past, sortOrder: 'a2');
      await repository.setTaskCompletion(taskId: done, isCompleted: true);
      await repository.createTask(title: 'Outside', assignedDate: past.addDays(-1), sortOrder: 'a0');

      final open = await repository.getOpenTasksBetween(start: past, end: past.addDays(2));
      expect(open.map((task) => task.id), [a, b, later]);
    });
  });
}
