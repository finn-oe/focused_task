import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/day_summary.dart';

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

  final monday = DateTime(2026, 2, 2);
  final tuesday = DateTime(2026, 2, 3);
  final wednesday = DateTime(2026, 2, 4);
  final week = DateRange(monday, DateTime(2026, 2, 8));

  Future<int> createTask(DateTime day, {bool completed = false}) async {
    final id = await repository.createTask(title: 'Task', assignedDate: day, sortOrder: 'a0');
    if (completed) await repository.setTaskCompletion(taskId: id, isCompleted: true);
    return id;
  }

  test('counts tasks and completed tasks per assigned day', () async {
    await createTask(monday);
    await createTask(monday, completed: true);
    await createTask(monday, completed: true);
    await createTask(wednesday);
    await createTask(DateTime(2026, 2, 9)); // next week, outside the range
    await createTask(DateTime(2026, 2, 1)); // the Sunday before

    final summaries = await repository.getDaySummaries(week);

    expect(summaries, {monday: const DaySummary(total: 3, completed: 2), wednesday: const DaySummary(total: 1)});
  });

  test('a session across midnight counts on both days, on the day it happened', () async {
    // Planned for Wednesday, worked on Monday night into Tuesday.
    final id = await createTask(wednesday);
    final session = await sessions.start(taskId: id, at: DateTime(2026, 2, 2, 23, 30));
    await sessions.end(session.id, DateTime(2026, 2, 3, 0, 45), EndReason.paused);
    // A break doesn't count as focus time.
    final pause = await sessions.start(kind: SessionKind.breakTime, at: DateTime(2026, 2, 3, 9));
    await sessions.end(pause.id, DateTime(2026, 2, 3, 9, 15), EndReason.paused);

    final summaries = await repository.getDaySummaries(week);

    expect(summaries[monday], const DaySummary(focusTime: Duration(minutes: 30)));
    expect(summaries[tuesday], const DaySummary(focusTime: Duration(minutes: 45)));
    expect(summaries[wednesday], const DaySummary(total: 1));
  });

  test('watchTasksInRange orders by day and sort order and follows moves', () async {
    final late = await repository.createTask(title: 'Late', assignedDate: monday, sortOrder: 'a2');
    await repository.createTask(title: 'Early', assignedDate: monday, sortOrder: 'a1');
    await repository.createTask(title: 'Tuesday', assignedDate: tuesday, sortOrder: 'a0');

    final stream = repository.watchTasksInRange(week).map((tasks) => [for (final task in tasks) task.title]);
    expect(await stream.first, ['Early', 'Late', 'Tuesday']);

    await repository.updateTaskDetails(taskId: late, title: 'Late', assignedDate: DateTime(2026, 2, 20));
    expect(await stream.first, ['Early', 'Tuesday']);
  });
}
