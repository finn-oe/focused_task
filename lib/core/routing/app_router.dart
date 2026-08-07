import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/features/tasks/presentation/focus_mode/focus_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/pause_screen.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/plan',
    routes: [
      GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
      GoRoute(path: '/pause', builder: (context, state) => const PauseScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});
