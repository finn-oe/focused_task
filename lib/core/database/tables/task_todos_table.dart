import 'package:drift/drift.dart';
import 'package:focused_task/core/database/tables/tasks_table.dart';

class TaskTodos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get sortOrder => text()();
}
