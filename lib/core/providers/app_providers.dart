import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/repositories/i_task_repository.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_notifier.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(appDatabaseProvider));
});

final planModeNotifierProvider = StateNotifierProvider<PlanModeNotifier, PlanModeState>((ref) {
  return PlanModeNotifier(ref.watch(taskRepositoryProvider));
});

final focusModeNotifierProvider = StateNotifierProvider<FocusModeNotifier, FocusModeState>((ref) {
  final notifier = FocusModeNotifier(ref.watch(taskRepositoryProvider));
  ref.onDispose(notifier.disposeNotifier);
  return notifier;
});
