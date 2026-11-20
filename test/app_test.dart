import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/main.dart';

import 'helpers/fake_preferences.dart';
import 'helpers/fake_task_repository.dart';

Widget _app(SharedPreferences preferences) {
  final repository = FakeTaskRepository();
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      recurrenceRepositoryProvider.overrideWithValue(repository),
      inboxRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
    child: const FocusedTaskApp(),
  );
}

void main() {
  testWidgets('switching the language updates the UI immediately and survives a restart', (tester) async {
    final preferences = await fakePreferences({'settings.locale': 'en'});
    await tester.pumpWidget(_app(preferences));
    await tester.pumpAndSettle();
    expect(find.text('Start focus'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsWidgets);
    expect(find.text('Sprache'), findsOneWidget);
    expect(preferences.getString('settings.locale'), 'de');

    // "Restart": a fresh widget tree reading the same preferences.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(preferences));
    await tester.pumpAndSettle();
    expect(find.text('Fokus starten'), findsOneWidget);

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(preferences.getString('settings.locale'), isNull);
  });
}
