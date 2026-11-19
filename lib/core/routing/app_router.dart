import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:focused_task/core/ui/app_shell.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/calendar/presentation/calendar_period.dart';
import 'package:focused_task/features/calendar/presentation/calendar_screen.dart';
import 'package:focused_task/features/categories/presentation/categories_screen.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/break_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/finished_for_today_screen.dart';
import 'package:focused_task/features/tasks/presentation/focus_mode/focus_request.dart';
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

  /// The break of a work/break cycle (#27).
  static const breakTime = '/break';
  static const finishedForToday = '/finished-for-today';
  static const taskForm = '/task-form';

  /// Category management, below [settings].
  static const categories = '/settings/categories';

  /// Query parameter of [plan] with the shown day (`YYYY-MM-DD`); missing = today.
  static const dateParameter = 'date';

  /// Query parameter of [calendar] with the view (`week` or `month`; missing = week). The shown day is [dateParameter].
  static const viewParameter = 'view';

  /// Query parameters of [focus]: the day (`YYYY-MM-DD`, missing = today), the task to start with and the category
  /// to focus on.
  static const dayParameter = 'day';
  static const taskParameter = 'task';
  static const categoryParameter = 'category';

  /// Location of focus mode for [request].
  static String focusFor(FocusRequest request) {
    return Uri(
      path: focus,
      queryParameters: {
        dayParameter: request.day.isoDate,
        if (request.startTaskId != null) taskParameter: '${request.startTaskId}',
        if (request.categoryId != null) categoryParameter: '${request.categoryId}',
      },
    ).toString();
  }

  /// Location of the plan for [day]; today has no date parameter.
  static String planFor(DateTime day, {required DateTime today}) {
    return day.isSameDate(today) ? plan : Uri(path: plan, queryParameters: {dateParameter: day.isoDate}).toString();
  }

  /// Location of the calendar showing the [view] around [date]; today has no date parameter.
  static String calendarFor(CalendarView view, DateTime date, {required DateTime today}) {
    return Uri(path: calendar, queryParameters: {viewParameter: view.name, if (!date.isSameDate(today)) dateParameter: date.isoDate}).toString();
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
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (context, state) {
                  final parameters = state.uri.queryParameters;
                  return CalendarScreen(view: CalendarView.tryParse(parameters[AppRoutes.viewParameter]), date: tryParseIsoDate(parameters[AppRoutes.dateParameter]));
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.stats, builder: (context, state) => const StatsScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [GoRoute(path: 'categories', builder: (context, state) => const CategoriesScreen())],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.focus,
        builder: (context, state) {
          final parameters = state.uri.queryParameters;
          final day = tryParseIsoDate(parameters[AppRoutes.dayParameter]) ?? DateTime.now();
          return FocusScreen(
            request: FocusRequest(
              day,
              startTaskId: int.tryParse(parameters[AppRoutes.taskParameter] ?? ''),
              categoryId: int.tryParse(parameters[AppRoutes.categoryParameter] ?? ''),
            ),
          );
        },
      ),
      GoRoute(path: AppRoutes.finishedForToday, builder: (context, state) => const FinishedForTodayScreen()),
      GoRoute(path: AppRoutes.pause, builder: (context, state) => const PauseScreen()),
      GoRoute(path: AppRoutes.breakTime, builder: (context, state) => const BreakScreen()),
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
