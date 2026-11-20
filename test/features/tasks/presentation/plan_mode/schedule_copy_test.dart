import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/domain/entities/task_draft.dart';

import '../../../../helpers/fake_notification_service.dart';
import '../../../../helpers/fake_preferences.dart';
import '../../../../helpers/fake_task_repository.dart';
import '../../../../helpers/task_builders.dart';

/// Copying and moving a task keep its start/due times and reminder (#10).
void main() {
  final day = DateTime(2026, 11, 18);
  final schedule = TaskSchedule(startMinute: 14 * 60, dueDate: DateTime(2026, 11, 20), reminderMinutes: 30);

  Future<(ProviderContainer, FakeTaskRepository)> start() async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(id: 1, title: 'Call', assignedDate: day, schedule: schedule)],
    );
    final container = ProviderContainer.test(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        recurrenceRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
    );
    return (container, repository);
  }

  test('duplicating in the form and copying to another day keep the schedule', () async {
    final (container, repository) = await start();
    final plan = container.read(planModeNotifierProvider.notifier);

    await plan.duplicateDraft(TaskDraft.fromTask(repository.task(1)));
    await plan.duplicateTaskToDate(task: repository.task(1), date: day.addDays(3), keepTodoCompletion: false, subtractTimeSpent: true);

    expect([for (final task in repository.tasks) task.schedule], [schedule, schedule, schedule]);
  });

  test('moving the open tasks to another day (rollover) keeps the times', () async {
    final (container, repository) = await start();

    await container.read(planModeNotifierProvider.notifier).moveOpenTasks(from: day, to: day.addDays(1));

    final moved = repository.task(1);
    expect(moved.schedule, schedule);
    expect(moved.startAt, DateTime(2026, 11, 19, 14));
    expect(moved.assignedDate, day.addDays(1).dateOnly);
  });
}
