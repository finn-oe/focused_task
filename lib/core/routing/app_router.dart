import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/features/tasks/presentation/focus_mode/focus_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/pause_screen.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/finished_for_today_screen.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/task_form_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/plan',
    routes: [
      GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
      GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
      GoRoute(path: '/finished-for-today', builder: (context, state) => const FinishedForTodayScreen()),
      GoRoute(path: '/pause', builder: (context, state) => const PauseScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/task-form',
        builder: (context, state) {
          final task = state.extra as TaskEntity?;
          return TaskFormScreen(task: task);
        },
      ),
    ],
  );
});
