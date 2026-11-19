import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/features/calendar/presentation/calendar_screen.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_preferences.dart';
import '../../helpers/fake_target_alarm.dart';
import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

Future<GoRouter> _pumpCalendar(WidgetTester tester, FakeTaskRepository repository, {required String location, Locale locale = const Locale('en'), Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
        targetAlarmProvider.overrideWithValue(FakeTargetAlarm()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      ],
      child: localizedRouterApp(routerConfig: router, locale: locale),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.routeInformationProvider.value.uri.toString();

const _dayKeyPrefix = 'calendar-day-';

/// Days shown in the calendar (`YYYY-MM-DD`), in layout order.
List<String> _shownDays(WidgetTester tester) {
  final cells = find.byWidgetPredicate((widget) => widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith(_dayKeyPrefix));
  return [for (final element in cells.evaluate()) (element.widget.key! as ValueKey<String>).value.substring(_dayKeyPrefix.length)];
}

void main() {
  group('month grid', () {
    testWidgets('February 2026 with weeks starting on Monday: 5 rows from 26 January', (tester) async {
      await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-02-10', locale: const Locale('de'));

      final days = _shownDays(tester);
      expect(days, hasLength(35));
      expect(days.first, '2026-01-26');
      expect(days.last, '2026-03-01');
      expect(find.text('Februar 2026'), findsOneWidget);
      // 1 February (a Sunday) ends the first row.
      final firstRow = tester.getTopLeft(find.byKey(calendarDayKey(DateTime(2026, 1, 26))));
      final sunday = tester.getTopLeft(find.byKey(calendarDayKey(DateTime(2026, 2, 1))));
      expect(sunday.dy, firstRow.dy);
      expect(sunday.dx, greaterThan(firstRow.dx));
      expect(tester.getTopLeft(find.byKey(calendarDayKey(DateTime(2026, 2, 2)))).dy, greaterThan(firstRow.dy));
    });

    testWidgets('February 2026 with weeks starting on Sunday: exactly 4 rows', (tester) async {
      await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-02-10');

      final days = _shownDays(tester);
      expect(days, hasLength(28));
      expect(days.first, '2026-02-01');
      expect(days.last, '2026-02-28');
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('August 2026 needs 6 weeks', (tester) async {
      await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-08-01', locale: const Locale('de'));

      final days = _shownDays(tester);
      expect(days, hasLength(42));
      expect(days.first, '2026-07-27');
      expect(days.last, '2026-09-06');
    });

    testWidgets('cells show done/total and a focus bar', (tester) async {
      final day = DateTime(2026, 2, 10);
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, assignedDate: day, isCompleted: true),
          buildTask(id: 2, assignedDate: day, sortOrder: 'a1'),
        ],
      );
      await repository.addManualTime(taskId: 1, day: day, duration: const Duration(minutes: 50));
      await _pumpCalendar(tester, repository, location: '/calendar?view=month&date=2026-02-10');

      final cell = find.byKey(calendarDayKey(day));
      expect(find.descendant(of: cell, matching: find.text('1/2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Focus time 00:50')), findsOneWidget);
    });

    testWidgets('works at 360 px', (tester) async {
      await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-08-01', size: const Size(360, 640));

      expect(_shownDays(tester), hasLength(42));
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    testWidgets('tapping a day opens it in the plan', (tester) async {
      final router = await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-02-10');

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 2, 17))));
      await tester.pumpAndSettle();

      expect(_location(router), '/plan?date=2026-02-17');
    });

    testWidgets('previous/next and the view toggle update the URL; Today returns to the current period', (tester) async {
      final router = await _pumpCalendar(tester, FakeTaskRepository(), location: '/calendar?view=month&date=2026-02-10');

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(_location(router), '/calendar?view=month&date=2026-03-01');
      expect(find.text('March 2026'), findsOneWidget);

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(_location(router), '/calendar?view=week&date=2026-03-01');

      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      expect(_location(router), '/calendar?view=week&date=2026-02-22');

      await tester.tap(find.widgetWithText(ActionChip, 'Today'));
      await tester.pumpAndSettle();
      expect(_location(router), '/calendar?view=week');
      expect(find.widgetWithText(ActionChip, 'Today'), findsNothing);
    });
  });

  group('week', () {
    final monday = DateTime(2026, 2, 2);
    final wednesday = DateTime(2026, 2, 4);

    testWidgets('wide: 7 columns with task titles; dragging a task moves it to the end of the target day', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [
          buildTask(id: 1, title: 'Move me', assignedDate: monday),
          buildTask(id: 2, title: 'Done already', assignedDate: monday, sortOrder: 'a1', isCompleted: true),
          buildTask(id: 3, title: 'Already there', assignedDate: wednesday, sortOrder: 'a5'),
        ],
      );
      await _pumpCalendar(tester, repository, location: '/calendar?view=week&date=2026-02-04', locale: const Locale('de'), size: const Size(1440, 900));

      expect(_shownDays(tester), ['2026-02-02', '2026-02-03', '2026-02-04', '2026-02-05', '2026-02-06', '2026-02-07', '2026-02-08']);
      final done = tester.widget<Text>(find.text('Done already'));
      expect(done.style?.decoration, TextDecoration.lineThrough);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Move me')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.byKey(calendarDayKey(wednesday))));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final moved = repository.task(1);
      expect(moved.assignedDate, wednesday);
      expect(moved.sortOrder.compareTo('a5'), greaterThan(0), reason: 'goes after the tasks already on the day');
      expect(find.descendant(of: find.byKey(calendarDayKey(wednesday)), matching: find.text('Move me')), findsOneWidget);
      expect(find.descendant(of: find.byKey(calendarDayKey(monday)), matching: find.text('Move me')), findsNothing);
    });

    testWidgets('narrow: an agenda with a "Move to…" action', (tester) async {
      final repository = FakeTaskRepository(
        tasks: [buildTask(id: 1, title: 'Move me', assignedDate: monday)],
      );
      await _pumpCalendar(tester, repository, location: '/calendar?view=week&date=2026-02-04', locale: const Locale('de'), size: const Size(360, 740));

      expect(find.text('Move me'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('calendar-task-1')), matching: find.byType(PopupMenuButton<void>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verschieben nach…'));
      await tester.pumpAndSettle();
      final options = find.descendant(of: find.byType(SimpleDialog), matching: find.byType(SimpleDialogOption));
      expect(options, findsNWidgets(7), reason: 'the 6 other days of the week and "Other date…"');
      await tester.tap(options.at(1)); // Wednesday (Monday is the task's own day)
      await tester.pumpAndSettle();

      expect(repository.task(1).assignedDate, wednesday);
      expect(tester.takeException(), isNull);
    });
  });
}
