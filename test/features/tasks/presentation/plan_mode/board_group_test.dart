import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/categories/domain/task_category.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

import '../../../../helpers/task_builders.dart';

void main() {
  const work = TaskCategory(id: 1, name: 'Work', colorIndex: 0, sortOrder: 'a0');
  final now = DateTime(2026, 11, 20, 14);

  test('counts, completion rate and tracked time of a group', () {
    final group = BoardGroup(work, [
      buildTask(id: 1, isCompleted: true, timeSpent: const Duration(minutes: 80).inMilliseconds),
      buildTask(id: 2, timeSpent: const Duration(minutes: 20).inMilliseconds),
      buildTask(id: 3),
      buildTask(id: 4, isCompleted: true),
    ]);

    expect((group.completedCount, group.openCount, group.totalCount, group.completionRate), (2, 2, 4, 0.5));
    expect(group.trackedAt(now), const Duration(minutes: 100));
  });

  test('a running session counts up to now, like the day total', () {
    final group = BoardGroup(work, [buildTask(id: 1, timeSpent: const Duration(minutes: 10).inMilliseconds, latestStart: now.subtract(const Duration(minutes: 5)))]);

    expect(group.trackedAt(now), const Duration(minutes: 15));
    expect(group.trackedAt(now.add(const Duration(minutes: 1))), const Duration(minutes: 16));
  });

  test('an empty group has no completion rate and no tracked time', () {
    const group = BoardGroup(null, []);

    expect((group.completedCount, group.totalCount, group.completionRate), (0, 0, null));
    expect(group.trackedAt(now), Duration.zero);
  });

  test('all done is a rate of 1', () {
    final group = BoardGroup(work, [buildTask(id: 1, isCompleted: true)]);

    expect(group.completionRate, 1);
  });
}
