import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';
import 'package:focused_task/features/tasks/presentation/stats/stats_screen.dart';

import '../../helpers/fake_task_repository.dart';
import '../../helpers/localized_app.dart';
import '../../helpers/task_builders.dart';

/// Renders [builder] with the localizations of [locale] and returns its result.
Future<T> _withContext<T>(WidgetTester tester, Locale locale, T Function(BuildContext context) builder) async {
  late T result;
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      home: Builder(
        builder: (context) {
          result = builder(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('plan screen shows German texts for de', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(FakeTaskRepository())],
        child: localizedApp(home: const PlanScreen(), locale: const Locale('de')),
      ),
    );
    await tester.pump();

    expect(find.text('Planen'), findsOneWidget);
    expect(find.text('Ausgewählter Tag: Heute'), findsOneWidget);
    expect(find.text('Keine Aufgaben für diesen Tag.'), findsOneWidget);
    expect(find.text('Aufgabe hinzufügen'), findsOneWidget);
  });

  testWidgets('first day of the week is Sunday for en_US and Monday for de', (tester) async {
    expect(await _withContext(tester, const Locale('en', 'US'), firstDayOfWeek), DateTime.sunday);
    expect(await _withContext(tester, const Locale('de'), firstDayOfWeek), DateTime.monday);
  });

  testWidgets('dates other than today, tomorrow and yesterday use the locale format', (tester) async {
    final today = DateTime(2026, 11, 17);
    String label(BuildContext context) => relativeDayLabel(context, DateTime(2026, 11, 25), today: today);

    expect(await _withContext(tester, const Locale('en'), label), 'Wed, Nov 25, 2026');
    expect(await _withContext(tester, const Locale('de'), label), 'Mi., 25. Nov. 2026');
    expect(await _withContext(tester, const Locale('de'), (context) => relativeDayLabel(context, DateTime(2026, 11, 18), today: today)), 'Morgen');
  });

  for (final (locale, expected) in [(const Locale('en', 'US'), '1/1 task completed'), (const Locale('de'), '0/1 Aufgabe erledigt')]) {
    testWidgets('stats week follows the first weekday of $locale', (tester) async {
      // Wednesday. en_US week: Sun 15 – Sat 21; de week: Mon 16 – Sun 22.
      await withClock(Clock.fixed(DateTime(2026, 11, 18, 12)), () async {
        final repository = FakeTaskRepository(
          tasks: [
            buildTask(id: 1, assignedDate: DateTime(2026, 11, 15), isCompleted: true),
            buildTask(id: 2, assignedDate: DateTime(2026, 11, 22), sortOrder: 'a1'),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [taskRepositoryProvider.overrideWithValue(repository)],
            child: localizedApp(home: const StatsScreen(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.date_range));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      });
    });
  }
}
