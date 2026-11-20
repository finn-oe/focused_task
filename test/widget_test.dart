import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/plan_screen.dart';

import 'helpers/fake_preferences.dart';
import 'helpers/fake_task_repository.dart';
import 'helpers/task_builders.dart';
import 'helpers/localized_app.dart';

Future<Widget> _app(FakeTaskRepository repository) async {
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      focusSessionRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(repository),
      inboxRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
    ],
    child: localizedApp(home: const PlanScreen()),
  );
}

void main() {
  testWidgets('App boots into plan mode shell', (tester) async {
    await tester.pumpWidget(await _app(FakeTaskRepository()));
    await tester.pump();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Start focus'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('No tasks for this day.'), findsOneWidget);
  });

  testWidgets('Tapping the completion flag toggles a task to completed', (tester) async {
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Write tests', assignedDate: DateTime.now())],
    );

    await tester.pumpWidget(await _app(repository));
    await tester.pump();

    expect(find.text('Write tests'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pump();

    expect(repository.task(1).isCompleted, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('offers to recover an unfinished session up to its last activity', (tester) async {
    final start = DateTime.now().subtract(const Duration(hours: 8));
    final repository = FakeTaskRepository(
      tasks: [buildTask(title: 'Crashed task', assignedDate: DateTime.now(), latestStart: start).copyWith(lastSeenAt: start.add(const Duration(minutes: 30)))],
    );

    await tester.pumpWidget(await _app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Recover unfinished session?'), findsOneWidget);
    expect(find.text('Until last activity (00:30)'), findsOneWidget);
    await tester.tap(find.text('Until last activity (00:30)'));
    await tester.pumpAndSettle();

    expect(repository.task(1).isRunning, isFalse);
    expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(minutes: 30));
  });
}
