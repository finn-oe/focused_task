import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/task_form_screen.dart';

import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/localized_app.dart';
import '../../../helpers/task_builders.dart';

void main() {
  testWidgets('Add time records a manual session and updates the tracked time', (tester) async {
    final yesterday = DateTime.now().dateOnly.addDays(-1);
    final task = buildTask(assignedDate: yesterday, timeSpent: const Duration(minutes: 15).inMilliseconds);
    final repository = FakeTaskRepository(tasks: [task]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(repository),
          inboxRepositoryProvider.overrideWithValue(repository),
        ],
        child: localizedApp(home: TaskFormScreen(task: task)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tracked time'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Tracked time'), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);

    await tester.ensureVisible(find.text('Add time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time picker starts at 00:30
    await tester.pumpAndSettle();

    expect(find.text('00:45'), findsOneWidget);
    final manual = repository.sessions.single;
    expect((manual.endReason, manual.duration, manual.startedAt.dateOnly), (EndReason.manual, const Duration(minutes: 30), yesterday));
    expect(Duration(milliseconds: repository.task(1).timeSpent), const Duration(minutes: 45));
  });
}
