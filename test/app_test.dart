import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/main.dart';

import 'helpers/fake_preferences.dart';
import 'helpers/fake_task_repository.dart';

Widget _app(SharedPreferences preferences) {
  return ProviderScope(
    overrides: [taskRepositoryProvider.overrideWithValue(FakeTaskRepository()), sharedPreferencesProvider.overrideWithValue(preferences)],
    child: const FocusedTaskApp(),
  );
}

void main() {
  testWidgets('switching the language updates the UI immediately and survives a restart', (tester) async {
    final preferences = await fakePreferences({'settings.locale': 'en'});
    await tester.pumpWidget(_app(preferences));
    await tester.pumpAndSettle();
    expect(find.text('Plan Mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(preferences.getString('settings.locale'), 'de');

    // "Restart": a fresh widget tree reading the same preferences.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(preferences));
    await tester.pumpAndSettle();
    expect(find.text('Planen'), findsOneWidget);

    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(preferences.getString('settings.locale'), isNull);
  });
}
