import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/fractional_indexer.dart';
import 'package:focused_task/features/inbox/domain/i_inbox_repository.dart';
import 'package:focused_task/features/inbox/domain/inbox_item.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';

class InboxState {
  const InboxState({required this.open, required this.isLoading});

  static const initial = InboxState(open: [], isLoading: true);

  /// Parked thoughts waiting for review, oldest first.
  final List<InboxItem> open;
  final bool isLoading;
}

/// The distraction inbox (#28): the thoughts waiting for review and what to do with them.
class InboxNotifier extends Notifier<InboxState> {
  late IInboxRepository _inbox;
  late ITaskRepository _tasks;
  StreamSubscription<List<InboxItem>>? _subscription;

  @override
  InboxState build() {
    _inbox = ref.watch(inboxRepositoryProvider);
    _tasks = ref.watch(taskRepositoryProvider);
    _subscription = _inbox.watchOpenInboxItems().listen((items) => state = InboxState(open: items, isLoading: false));
    ref.onDispose(() => _subscription?.cancel());
    return InboxState.initial;
  }

  /// Turns [item] into a task at the end of [day]'s plan and takes it out of the inbox. Returns the task's id.
  Future<int> convertToTask(InboxItem item, DateTime day) async {
    final planned = await _tasks.getTasksForDay(day);
    final sortOrder = FractionalIndexer.between(planned.isEmpty ? null : planned.last.sortOrder, null);
    final id = await _tasks.createTask(title: item.text, assignedDate: day, sortOrder: sortOrder);
    await _inbox.resolveInboxItem(item.id, clock.now());
    return id;
  }

  /// Takes [item] out of the inbox without a task; [reopen] undoes it.
  Future<void> dismiss(InboxItem item) => _inbox.resolveInboxItem(item.id, clock.now());

  Future<void> reopen(InboxItem item) => _inbox.reopenInboxItem(item.id);
}
