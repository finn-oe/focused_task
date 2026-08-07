import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';

void main() {
  group('AppDatabase day filtering', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('focus query only returns tasks for the selected day', () async {
      final today = DateTime(2026, 8, 8);
      final tomorrow = today.add(const Duration(days: 1));

      await database.createTask(TasksCompanion.insert(title: 'today task', assignedDate: today, sortOrder: 'a0'));

      await database.createTask(TasksCompanion.insert(title: 'tomorrow task', assignedDate: tomorrow, sortOrder: 'a1'));

      final next = await database.getNextIncompleteTaskForDay(today);

      expect(next, isNotNull);
      expect(next!.title, 'today task');
      expect(DateTime(next.assignedDate.year, next.assignedDate.month, next.assignedDate.day), today);
    });
  });
}
