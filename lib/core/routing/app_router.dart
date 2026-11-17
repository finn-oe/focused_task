import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/ui/app_shell.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/calendar/presentation/calendar_screen.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/finished_for_today_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/pause_screen.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/task_form_screen.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

/// Paths of the app's routes.
abstract final class AppRoutes {
  static const plan = '/plan';
  static const calendar = '/calendar';
  static const stats = '/stats';
  static const settings = '/settings';
  static const focus = '/focus';
  static const pause = '/pause';
  static const finishedForToday = '/finished-for-today';
  static const taskForm = '/task-form';

  /// Query parameter of [plan] with the shown day (`YYYY-MM-DD`); missing = today.
  static const dateParameter = 'date';

  /// Location of the plan for [day]; today has no date parameter.
  static String planFor(DateTime day, {required DateTime today}) {
    return day.isSameDate(today) ? plan : Uri(path: plan, queryParameters: {dateParameter: day.isoDate}).toString();
  }
}

/// Creates the app's router. The four main views live in a [StatefulShellRoute] (each keeps its state); focus mode
/// and the task form are full-screen routes on top of it.
GoRouter createAppRouter({String initialLocation = AppRoutes.plan}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.plan,
                builder: (context, state) => PlanScreen(day: tryParseIsoDate(state.uri.queryParameters[AppRoutes.dateParameter])),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.calendar, builder: (context, state) => const CalendarScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.stats, builder: (context, state) => const StatsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(path: AppRoutes.focus, builder: (context, state) => const FocusScreen()),
      GoRoute(path: AppRoutes.finishedForToday, builder: (context, state) => const FinishedForTodayScreen()),
      GoRoute(path: AppRoutes.pause, builder: (context, state) => const PauseScreen()),
      GoRoute(
        path: AppRoutes.taskForm,
        builder: (context, state) => TaskFormScreen(task: state.extra as TaskEntity?),
      ),
    ],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
