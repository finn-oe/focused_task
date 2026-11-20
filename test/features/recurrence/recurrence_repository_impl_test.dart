import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/recurrence/data/recurrence_repository_impl.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';
import 'package:focused_task/features/reminders/domain/reminder_scheduler.dart';
import 'package:focused_task/features/reminders/domain/reminder_settings.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

/// Monday.
final _today = DateTime(2026, 3, 2);

void main() {
  late AppDatabase database;
  late RecurrenceRepositoryImpl rules;
  late TaskRepositoryImpl tasks;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    rules = RecurrenceRepositoryImpl(database);
    tasks = TaskRepositoryImpl(database);
  });
  tearDown(() => database.close());

  Future<T> at<T>(Future<T> Function() body) => withClock(Clock.fixed(_today.add(const Duration(hours: 8))), body);

  RecurrenceRule daily({List<String> todos = const [], DateTime? start}) => RecurrenceRule(
    title: 'Stretch',
    pattern: const RepeatPattern(frequency: RepeatFrequency.daily),
    startDate: start ?? _today,
    todoTitles: todos,
    targetDurationMinutes: 15,
  );

  Future<List<TaskEntity>> on(DateTime day) => tasks.getTasksForDay(day);

  test('rules round-trip with their pattern and template', () async {
    final rule = RecurrenceRule(
      title: 'Review',
      description: 'weekly',
      priority: TaskPriority.high,
      todoTitles: const ['inbox', 'calendar'],
      pattern: RepeatPattern(frequency: RepeatFrequency.weekly, weekdays: const {DateTime.monday, DateTime.friday}, endDate: DateTime(2026, 6, 30)),
      startDate: _today,
      startMinute: 600,
      dueOffsetDays: 1,
      dueMinute: 720,
      reminderMinutes: 10,
    );
    final loaded = (await rules.getRule(await rules.createRule(rule)))!;
    expect((loaded.title, loaded.description, loaded.priority), ('Review', 'weekly', TaskPriority.high));
    expect(loaded.todoTitles, ['inbox', 'calendar']);
    expect(loaded.pattern, rule.pattern);
    expect((loaded.startDate, loaded.startMinute, loaded.dueOffsetDays, loaded.dueMinute, loaded.reminderMinutes), (_today, 600, 1, 720, 10));
  });

  test('materialisation creates normal tasks with sub-tasks, after the tasks of the day', () async {
    await tasks.createTask(title: 'Existing', assignedDate: _today, sortOrder: 'a0');
    await rules.createRule(daily(todos: ['neck', 'back']));
    await at(() => rules.ensureOccurrences(DateRange(_today, _today.addDays(1))));

    final today = await on(_today);
    expect([for (final task in today) task.title], ['Existing', 'Stretch']);
    final occurrence = today.last;
    expect((occurrence.isRecurring, occurrence.occurrenceDate, occurrence.targetDurationMinutes, occurrence.isCompleted), (true, _today, 15, false));
    expect([for (final todo in occurrence.todos) todo.title], ['neck', 'back']);
    expect(await on(_today.addDays(1)), hasLength(1));
  });

  test('materialisation is idempotent: running it twice gives no duplicates', () async {
    await rules.createRule(daily(todos: ['neck']));
    final week = DateRange(_today, _today.addDays(6));
    await at(() => rules.ensureOccurrences(week));
    await at(() => rules.ensureOccurrences(week));
    await at(() => Future.wait([rules.ensureOccurrences(week), rules.ensureOccurrences(week)]));

    final all = await tasks.watchTasksInRange(week).first;
    expect(all, hasLength(7));
    expect(await database.select(database.taskTodos).get(), hasLength(7), reason: 'sub-tasks are not copied twice');
  });

  test('deleting an occurrence does not bring it back', () async {
    await rules.createRule(daily());
    final range = DateRange(_today, _today.addDays(2));
    await at(() => rules.ensureOccurrences(range));
    final tomorrow = (await on(_today.addDays(1))).single;

    await tasks.deleteTask(tomorrow.id);
    await at(() => rules.ensureOccurrences(range));
    expect(await on(_today.addDays(1)), isEmpty);
    expect(await on(_today.addDays(2)), hasLength(1));
  });

  test('a moved occurrence is not created again on its old day', () async {
    await rules.createRule(daily());
    await at(() => rules.ensureOccurrences(DateRange(_today, _today)));
    final task = (await on(_today)).single;
    await tasks.moveTasks(taskIds: [task.id], to: _today.addDays(3));

    await at(() => rules.ensureOccurrences(DateRange(_today, _today)));
    expect(await on(_today), isEmpty);
  });

  test('cleaned-up completed occurrences do not come back', () async {
    await rules.createRule(daily(start: _today.addDays(-40)));
    // Created while that day was today.
    await withClock(Clock.fixed(_today.addDays(-40)), () => rules.ensureOccurrences(DateRange(_today.addDays(-40), _today.addDays(-40))));
    final old = (await on(_today.addDays(-40))).single;
    await tasks.setTaskCompletion(taskId: old.id, isCompleted: true);

    expect(await at(() => tasks.deleteCompletedTasksOlderThanDays(30)), 1);
    expect(await database.select(database.recurrenceExceptions).get(), hasLength(1));
  });

  test('past days are not filled in; days from today on are', () async {
    await rules.createRule(daily(start: _today.addDays(-5)));
    await at(() => rules.ensureOccurrences(DateRange(_today.addDays(-5), _today.addDays(1))));
    expect(await on(_today.addDays(-1)), isEmpty);
    expect(await on(_today), hasLength(1));
    expect(await on(_today.addDays(1)), hasLength(1));
  });

  test('occurrences get the start time, reminder and relative deadline; reminders are planned like any task', () async {
    await rules.createRule(daily().copyWith(pattern: const RepeatPattern(frequency: RepeatFrequency.weekdays)));
    final rule = RecurrenceRule(
      title: 'Report',
      pattern: const RepeatPattern(frequency: RepeatFrequency.daily),
      startDate: _today,
      startMinute: 9 * 60,
      dueOffsetDays: 2,
      dueMinute: 16 * 60,
      reminderMinutes: 20,
    );
    await rules.createRule(rule);
    await at(() => rules.ensureOccurrences(DateRange(_today, _today.addDays(1))));

    final tomorrow = (await on(_today.addDays(1))).firstWhere((task) => task.title == 'Report');
    expect(tomorrow.schedule, TaskSchedule(startMinute: 540, dueDate: _today.addDays(3), dueMinute: 960, reminderMinutes: 20));
    expect(tomorrow.startAt, DateTime(2026, 3, 3, 9));

    final scheduled = await tasks.watchScheduledOpenTasks().first;
    expect(scheduled.where((task) => task.title == 'Report'), hasLength(2));
    final reminder = const ReminderScheduler().reminderFor(tomorrow, const ReminderSettings());
    expect(reminder?.at, DateTime(2026, 3, 3, 8, 40));
  });

  group('this and future', () {
    late int ruleId;

    setUp(() async {
      ruleId = await rules.createRule(daily());
      await at(() => rules.ensureOccurrences(DateRange(_today, _today.addDays(4))));
    });

    Future<TaskEntity> occurrenceOn(int offset) async => (await on(_today.addDays(offset))).single;

    test('replacing from a day ends the old rule before it and the new one takes over', () async {
      final edited = await occurrenceOn(2);
      final tracked = await occurrenceOn(3);
      await FocusSessionRepositoryImpl(database).addManualTime(taskId: tracked.id, day: _today, duration: const Duration(minutes: 5));

      final next = daily().copyWith(pattern: const RepeatPattern(frequency: RepeatFrequency.interval, intervalDays: 2));
      final nextId = (await rules.replaceFrom(ruleId: ruleId, from: edited.occurrenceDate!, taskId: edited.id, next: next))!;

      expect((await rules.getRule(ruleId))!.pattern.endDate, _today.addDays(1));
      expect((await rules.getRule(nextId))!.startDate, _today.addDays(2));
      expect((await tasks.getTaskById(edited.id))!.recurrenceId, nextId);
      expect((await tasks.getTaskById(tracked.id))!.recurrenceId, nextId, reason: 'tracked time is kept');
      expect(await on(_today.addDays(4)), isEmpty, reason: 'the untouched occurrence is removed …');

      await at(() => rules.ensureOccurrences(DateRange(_today, _today.addDays(6))));
      expect(await on(_today.addDays(4)), hasLength(1), reason: '… and the new rule creates it again');
      expect(await on(_today.addDays(5)), isEmpty, reason: 'every 2 days from day 2');
      expect(await on(_today.addDays(1)), hasLength(1), reason: 'earlier days keep the old rule');
    });

    test('without a new rule the edited task becomes a one-off task', () async {
      final edited = await occurrenceOn(1);
      await rules.replaceFrom(ruleId: ruleId, from: edited.occurrenceDate!, taskId: edited.id);
      final task = (await tasks.getTaskById(edited.id))!;
      expect((task.isRecurring, task.occurrenceDate), (false, null));
      await at(() => rules.ensureOccurrences(DateRange(_today, _today.addDays(4))));
      expect(await on(_today.addDays(2)), isEmpty);
      expect(await on(_today), hasLength(1));
    });

    test('deleting from the first day deletes the rule; completed occurrences stay as one-off tasks', () async {
      final first = await occurrenceOn(0);
      final done = await occurrenceOn(2);
      await tasks.setTaskCompletion(taskId: done.id, isCompleted: true);

      await rules.endBefore(ruleId: ruleId, from: _today, taskId: first.id);
      expect(await rules.getRule(ruleId), isNull);
      expect(await tasks.getTaskById(first.id), isNull);
      expect((await tasks.getTaskById(done.id))!.isRecurring, isFalse);
      expect(await tasks.watchTasksInRange(DateRange(_today, _today.addDays(4))).first, hasLength(1));
    });
  });
}
