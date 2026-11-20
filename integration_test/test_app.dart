import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/main.dart';

import '../test/helpers/fake_target_alarm.dart';

/// The real app on an in-memory database, with a fake alarm and mock preferences.
///
/// Keep the [database] and [preferences] to "restart" the app with [restart] (a fresh widget tree, same data).
class TestApp {
  TestApp._(this.database, this.preferences, this.alarm);

  final AppDatabase database;
  final SharedPreferences preferences;
  final FakeTargetAlarm alarm;

  /// Boots the app; English unless [preferences] say otherwise. [seed] fills the database before the first frame.
  static Future<TestApp> start(WidgetTester tester, {Map<String, Object> preferences = const {'settings.locale': 'en'}, Future<void> Function(AppDatabase database)? seed}) async {
    SharedPreferences.setMockInitialValues(preferences);
    final app = TestApp._(AppDatabase(NativeDatabase.memory()), await SharedPreferences.getInstance(), FakeTargetAlarm());
    addTearDown(app.database.close);
    await seed?.call(app.database);
    await app._pump(tester);
    return app;
  }

  /// Replaces the widget tree with a new app instance on the same data.
  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _pump(tester);
  }

  Future<void> _pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The test owns the database; the provider must not close it when the tree is replaced.
          appDatabaseProvider.overrideWith((ref) => database),
          sharedPreferencesProvider.overrideWithValue(preferences),
          targetAlarmProvider.overrideWithValue(alarm),
        ],
        child: const FocusedTaskApp(),
      ),
    );
    await tester.settle();
  }
}

/// Small helpers shared by the flows.
extension FlowActions on WidgetTester {
  /// [pumpAndSettle] that gives up after 30 s instead of 10 min, so a hang fails with the stack of the step that hangs.
  Future<void> settle() {
    debugPrint('[flow] settle'); // TEMP: Linux CI hang (#62)
    return pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
  }

  Future<void> tapAndSettle(Finder finder) async {
    debugPrint('[flow] tap ${finder.describeMatch(Plurality.one)}'); // TEMP: Linux CI hang (#62)
    await ensureVisible(finder);
    await tap(finder);
    await settle();
  }

  Future<void> enterTextInField(String label, String text) async {
    await enterText(find.widgetWithText(TextField, label), text);
    await settle();
  }
}
