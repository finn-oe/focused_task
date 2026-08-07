import 'package:flutter/material.dart';

import 'package:focused_task/features/tasks/domain/entities/task.dart';

class TaskListItem extends StatelessWidget {
  const TaskListItem({super.key, required this.task});

  final TaskEntity task;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(task.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(title: Text(task.title), subtitle: Text(task.description ?? 'No description'), trailing: const Icon(Icons.drag_handle)),
    );
  }
}
