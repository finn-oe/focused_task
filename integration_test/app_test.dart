import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/calendar/presentation/calendar_screen.dart';
import 'package:focused_task/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';

import 'test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add a task with 2 sub-tasks and a 25 min target', (tester) async {
    await TestApp.start(tester);

    await tester.tapAndSettle(find.text('Add Task'));
    await tester.tapAndSettle(find.text('Save Task'));
    expect(find.text('Please enter a title.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Write report');
    await tester.tapAndSettle(find.text('25 min'));
    final newSubTask = find.widgetWithText(TextField, 'Add sub-task');
    for (final subTask in ['Outline', 'Draft']) {
      await tester.ensureVisible(newSubTask);
      await tester.enterText(newSubTask, subTask);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await tester.tapAndSettle(find.text('Save Task'));

    expect(find.text('Write report'), findsOneWidget);
    await tester.tapAndSettle(find.byTooltip('Edit Task'));
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '25 min')).selected, isTrue);
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
  testWidgets('calendar: see the week, move a task to another day, open a day from the month', (tester) async {
    // Phone width: the week is an agenda with "Move to…".
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    final today = DateTime.now().dateOnly;
    final id = await tasks.createTask(title: 'Weekly review', assignedDate: today, sortOrder: 'a0');
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.text('Calendar').first);
    expect(find.text('Weekly review'), findsOneWidget);

    // Weeks start on Sunday in English, so Saturday's neighbour in the same week is the day before.
    final toYesterday = today.weekday == DateTime.saturday;
    final target = today.addDays(toYesterday ? -1 : 1);
    await tester.tapAndSettle(find.descendant(of: find.byKey(ValueKey('calendar-task-$id')), matching: find.byType(PopupMenuButton<void>)));
    await tester.tapAndSettle(find.text('Move to…'));
    await tester.tapAndSettle(find.descendant(of: find.byType(SimpleDialog), matching: find.text(toYesterday ? 'Yesterday' : 'Tomorrow')));
    expect((await tasks.getTaskById(id))!.assignedDate, target);

    await tester.tapAndSettle(find.text('Month'));
    final cell = find.byKey(calendarDayKey(target));
    await tester.ensureVisible(cell);
    expect(find.descendant(of: cell, matching: find.text('0/1')), findsOneWidget);

    await tester.tapAndSettle(cell);
    expect(find.text(toYesterday ? 'Yesterday' : 'Tomorrow'), findsOneWidget, reason: 'the plan shows the tapped day');
    expect(find.text('Weekly review'), findsOneWidget);
  });

  testWidgets('unfinished tasks move to today: the daily prompt and the task menu', (tester) async {
    final today = DateTime.now().dateOnly;
    final yesterday = today.addDays(-1);
    final app = await TestApp.start(
      tester,
      seed: (database) async {
        final tasks = TaskRepositoryImpl(database);
        await tasks.createTask(title: 'Write report', assignedDate: yesterday, sortOrder: 'a0');
        await tasks.createTask(title: 'Call back', assignedDate: yesterday, sortOrder: 'a1');
        // 20 minutes of work yesterday stay on yesterday after the move.
        await database.addManualSession(taskId: 1, start: yesterday.add(const Duration(hours: 9)), duration: const Duration(minutes: 20));
      },
    );

    expect(find.text('Unfinished tasks'), findsOneWidget);
    await tester.tapAndSettle(find.widgetWithText(CheckboxListTile, 'Call back'));
    await tester.tapAndSettle(find.text('Move 1 task to today'));
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Call back'), findsNothing);

    await app.restart(tester);
    expect(find.text('Unfinished tasks'), findsNothing, reason: 'the prompt shows once per day');

    await tester.tapAndSettle(find.byTooltip('Previous day'));
    expect(find.text('Call back'), findsOneWidget);
    await tester.tapAndSettle(find.byTooltip('Move or copy'));
    await tester.tapAndSettle(find.text('Move to today'));
    expect(find.text('No tasks for this day.'), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('Next day'));
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Call back'), findsOneWidget);

    final moved = (await TaskRepositoryImpl(app.database).getTaskById(1))!;
    expect((moved.assignedDate, Duration(milliseconds: moved.timeSpent)), (today, const Duration(minutes: 20)));
    final sessions = await app.database.getSessionsOverlapping(yesterday, today);
    expect(sessions, hasLength(1), reason: 'the session stays on the day it was worked');
  });
}
