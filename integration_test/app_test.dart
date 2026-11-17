import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

import 'test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add a task with 2 sub-tasks and a 25 min target', (tester) async {
    await TestApp.start(tester);

    await tester.tapAndSettle(find.text('Add Task'));
    await tester.enterTextInField('Title', 'Write report');

    for (final subTask in ['Outline', 'Draft']) {
      await tester.tapAndSettle(find.byTooltip('Add Sub-task'));
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), subTask);
      await tester.tapAndSettle(find.text('Save'));
    }

    await tester.tapAndSettle(find.text('Target Duration (Optional)'));
    await tester.tapAndSettle(find.byIcon(Icons.keyboard_outlined)); // time picker: type instead of dialing
    final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '00');
    await tester.enterText(fields.at(1), '25');
    await tester.tapAndSettle(find.text('OK'));
    expect(find.text('0h 25m'), findsOneWidget);

    await tester.tapAndSettle(find.text('Save Task'));

    expect(find.text('Write report'), findsOneWidget);
    await tester.tapAndSettle(find.byTooltip('Edit Task'));
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('0h 25m'), findsOneWidget);
  });

  testWidgets('focus: tick a sub-task, complete the task, see it in the statistics', (tester) async {
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    final id = await tasks.createTask(title: 'Deep work', assignedDate: DateTime.now(), sortOrder: 'a0', targetDurationMinutes: 25);
    await tasks.replaceTaskTodos(id, const [TaskTodoEntity(title: 'First step', isCompleted: false, sortOrder: 'a0')]);
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.text('Start focus'));
    expect(find.text('Deep work'), findsOneWidget);
    expect(app.alarm.scheduledAt, isNotNull, reason: 'the 25 min target alarm is armed');

    await tester.tapAndSettle(find.text('First step'));
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);

    await tester.tapAndSettle(find.text('Complete Task'));
    expect(find.text('Finished for Today!'), findsOneWidget);
    expect(app.alarm.scheduledAt, isNull, reason: 'completing cancels the alarm');

    await tester.tapAndSettle(find.text('View Statistics'));
    expect(find.text('1/1 task completed'), findsOneWidget);
  });

  testWidgets('switch to tomorrow, add a task, go back to today', (tester) async {
    await TestApp.start(tester);

    await tester.tapAndSettle(find.byTooltip('Next day'));
    expect(find.text('Tomorrow'), findsOneWidget);

    await tester.tapAndSettle(find.text('Add Task'));
    await tester.enterTextInField('Title', 'Plan the week');
    await tester.tapAndSettle(find.text('Save Task'));
    expect(find.text('Plan the week'), findsOneWidget, reason: 'new tasks go to the shown day');

    await tester.tapAndSettle(find.widgetWithText(ActionChip, 'Today'));
    expect(find.text('Plan the week'), findsNothing);
    expect(find.text('No tasks for this day.'), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('Next day'));
    expect(find.text('Plan the week'), findsOneWidget);
  });

  testWidgets('dark theme survives a restart', (tester) async {
    final app = await TestApp.start(tester);
    Brightness brightness() => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    await tester.tapAndSettle(find.text('Settings').first);
    await tester.tapAndSettle(find.text('Dark'));
    expect(brightness(), Brightness.dark);

    await app.restart(tester);
    expect(brightness(), Brightness.dark);
    expect(app.preferences.getString('settings.theme_mode'), 'dark');
  });

  testWidgets('the session log records focus time on the day it happened', (tester) async {
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    // Planned for next week, worked on today.
    await tasks.createTask(title: 'Early start', assignedDate: DateTime.now().addDays(7), sortOrder: 'a0');
    final today = DateTime.now().dateOnly;
    final session = await app.database.startSession(taskId: 1, kind: 'focus', at: today.add(const Duration(hours: 8)));
    await app.database.endSession(session.id, today.add(const Duration(hours: 8, minutes: 30)), 'paused');

    await tester.tapAndSettle(find.text('Statistics').first);

    expect(find.text('30 min'), findsWidgets);
  });
}
