import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/utils/date_utils.dart';

import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

/// Pumps the real router in a window [width] px wide and returns it.
Future<GoRouter> _pumpApp(WidgetTester tester, {double width = 800, String initialLocation = AppRoutes.plan, FakeTaskRepository? repository}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = repository ?? FakeTaskRepository();
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(fake),
        focusSessionRepositoryProvider.overrideWithValue(fake),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
      ],
      child: localizedRouterApp(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.routeInformationProvider.value.uri.toString();

void main() {
  final today = DateTime.now().dateOnly;

  group('adaptive navigation', () {
    testWidgets('400 px: bottom navigation bar', (tester) async {
      await _pumpApp(tester, width: 400);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('800 px: navigation rail', (tester) async {
      await _pumpApp(tester, width: 800);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isFalse);
    });

    testWidgets('1300 px: extended navigation rail (sidebar)', (tester) async {
      await _pumpApp(tester, width: 1300);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
    });
  });

  group('day navigation', () {
    testWidgets('previous, next and Today change the day and the URL', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [buildTask(title: 'Tomorrow task', assignedDate: today.addDays(1))],
      );
      final router = await _pumpApp(tester, repository: repository);
      expect(find.text('Today'), findsOneWidget);

      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(_location(router), '/plan?date=${today.addDays(1).isoDate}');
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Tomorrow task'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(_location(router), '/plan', reason: 'today has no date parameter');
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(_location(router), '/plan?date=${today.addDays(-1).isoDate}');
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Today'));
      await tester.pumpAndSettle();
      expect(_location(router), '/plan');
      expect(find.byType(ActionChip), findsNothing, reason: 'the Today chip only shows for other days');
    });

    testWidgets('the app bar fits a 360 px phone on a long date', (tester) async {
      await _pumpApp(tester, width: 360, initialLocation: '/plan?date=2026-09-30');

      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.byTooltip('Today'), findsOneWidget);
      expect(find.byTooltip('Start focus'), findsOneWidget);
    });

    testWidgets('/plan?date=… opens that day', (tester) async {
      final day = DateTime(2026, 3, 9);
      final repository = FakeTaskRepository(
        tasks: [buildTask(title: 'Deep-linked', assignedDate: day)],
      );
      await _pumpApp(tester, initialLocation: '/plan?date=2026-03-09', repository: repository);

      expect(find.text('Deep-linked'), findsOneWidget);
      expect(find.text('Mon, Mar 9, 2026'), findsOneWidget);
    });

    testWidgets('Alt+→ / Alt+← change the day on desktop', (tester) async {
      final router = await _pumpApp(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(_location(router), '/plan?date=${today.addDays(1).isoDate}');
    });

    testWidgets('swiping the list changes the day', (tester) async {
      final router = await _pumpApp(tester, width: 400);

      await tester.fling(find.text('No tasks for this day.'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(_location(router), '/plan?date=${today.addDays(1).isoDate}');

      await tester.fling(find.text('No tasks for this day.'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(_location(router), '/plan');
    });
  });

  testWidgets('each branch keeps its state when switching tabs', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<Object>>(find.byWidgetPredicate((widget) => widget is SegmentedButton));
    expect(segmented.selected.single.toString(), 'StatsRange.month');
  });

  testWidgets('the old /stats and /settings routes still work', (tester) async {
    final router = await _pumpApp(tester, initialLocation: AppRoutes.stats);
    expect(find.text('Completion score'), findsOneWidget);

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });
}
