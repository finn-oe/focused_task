import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';

/// Schema of version 3 (before `last_seen_at`), as created by older app versions.
const _v3Schema = [
  '''CREATE TABLE tasks (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NULL,
    assigned_date INTEGER NOT NULL,
    sort_order TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    priority INTEGER NOT NULL DEFAULT 0,
    time_spent INTEGER NOT NULL DEFAULT 0,
    latest_start INTEGER NULL,
    target_duration_minutes INTEGER NULL
  )''',
  '''CREATE TABLE task_todos (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    sort_order TEXT NOT NULL
  )''',
  "INSERT INTO tasks (title, assigned_date, sort_order, time_spent, latest_start) VALUES ('legacy', 1767222000, 'a0', 600000, 1767225600)",
  'PRAGMA user_version = 3',
];

void main() {
  test('migrates v3 databases to v4 and keeps existing data', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _v3Schema) {
            raw.execute(statement);
          }
        },
      ),
    );
    addTearDown(database.close);

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'legacy');
    expect(task.timeSpent, 600000);
    expect(task.latestStart, isNotNull);
    expect(task.lastSeenAt, isNull, reason: 'legacy sessions have no heartbeat yet');

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, database.schemaVersion);
  });
}
