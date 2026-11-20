import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/calendar/presentation/calendar_screen.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/settings/presentation/settings_screen.dart';
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
      // The form is a lazy list: scroll until the field is built.
      await tester.scrollUntilVisible(newSubTask, 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(newSubTask, subTask);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    bool subTaskHasFocus() => tester.widget<EditableText>(find.descendant(of: newSubTask, matching: find.byType(EditableText))).focusNode.hasFocus;
    expect(subTaskHasFocus(), isTrue, reason: 'Enter keeps the keyboard open for the next sub-task');

    // Tapping outside the fields closes the keyboard; the app bar's save is reachable either way (#56).
    // A plain heading: the tap lands on the form's empty background, i.e. outside every field.
    await tester.ensureVisible(find.text('Sub-tasks'));
    await tester.tap(find.text('Sub-tasks'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(subTaskHasFocus(), isFalse);
    await tester.tapAndSettle(find.byTooltip('Save Task'));

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
    expect(find.text('Early start'), findsOneWidget, reason: 'top tasks include tasks planned on other days');
  });

  testWidgets('statistics: switch periods, navigate back and forth, see the empty state', (tester) async {
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    final id = await tasks.createTask(title: 'Write report', assignedDate: DateTime.now(), sortOrder: 'a0', targetDurationMinutes: 60);
    await FocusSessionRepositoryImpl(app.database).addManualTime(taskId: id, day: DateTime.now(), duration: const Duration(minutes: 90));

    await tester.tapAndSettle(find.text('Statistics').first);
    expect(find.text('1 h 30 min'), findsWidgets);
    expect(find.text('Focus time per hour'), findsOneWidget);
    expect(find.text('Planned vs. actual'), findsOneWidget);

    await tester.tapAndSettle(find.text('Year'));
    expect(find.text('Focus time per month'), findsOneWidget);
    final thisYear = tester.widget<Text>(find.byKey(const Key('statsPeriodLabel'))).data;

    await tester.tapAndSettle(find.byTooltip('Previous period'));
    expect(tester.widget<Text>(find.byKey(const Key('statsPeriodLabel'))).data, '${DateTime.now().year - 1}');
    expect(find.text('No data for this period'), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('Go to current period'));
    expect(tester.widget<Text>(find.byKey(const Key('statsPeriodLabel'))).data, thisYear);
    expect(find.text('Write report'), findsWidgets);
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

  testWidgets('daily goal: set it in the settings, see the ring, the summary of today and the streak', (tester) async {
    // Tall enough for the goal dropdown and its menu; the desktop window size differs per machine.
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    final id = await tasks.createTask(title: 'Write report', assignedDate: DateTime.now(), sortOrder: 'a0');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planGoalRing')), findsNothing, reason: 'the goal is off by default');

    await tester.tapAndSettle(find.text('Settings').first);
    // Scroll past the dropdown, so its menu has room to open.
    await tester.scrollUntilVisible(
      find.text('Working days'),
      200,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.tapAndSettle(find.byKey(const Key('settingsDailyGoal')));
    await tester.tapAndSettle(find.text('30 min').last);
    expect(app.preferences.getInt('settings.daily_goal_minutes'), 30);

    await tester.tapAndSettle(find.text('Plan').first);
    expect(find.byTooltip('Today’s focus: 0 min of 30 min'), findsOneWidget);

    await tester.tapAndSettle(find.text('Start focus'));
    await tester.tapAndSettle(find.text('Complete Task'));
    expect(find.text('Finished for Today!'), findsOneWidget);
    expect(find.text('Not reached (0 min of 30 min)'), findsOneWidget);
    await tester.tapAndSettle(find.text('Back to Plan'));

    // 30 min at the very start of today: "Add time" never goes into the future, so shortly after midnight it would put
    // part of the time on yesterday and the goal would not be reached.
    final sessions = FocusSessionRepositoryImpl(app.database);
    final midnight = DateTime.now().dateOnly;
    final session = await sessions.start(taskId: id, at: midnight);
    await sessions.end(session.id, midnight.add(const Duration(minutes: 30)), EndReason.manual);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Daily goal reached: 30 min of 30 min'), findsOneWidget);

    await tester.tapAndSettle(find.byKey(const Key('planGoalRing')));
    await tester.scrollUntilVisible(find.byKey(const Key('statsCurrentStreak')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('statsGoalDaysChart')), findsOneWidget);
  });

  testWidgets('categories: create one, give a task its category, filter, board and focus on the category', (tester) async {
    final app = await TestApp.start(tester);
    final tasks = TaskRepositoryImpl(app.database);
    await tasks.createTask(title: 'Groceries', assignedDate: DateTime.now(), sortOrder: 'a0');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show as board'), findsNothing, reason: 'the plan stays a plain list without categories');

    await tester.tapAndSettle(find.text('Settings').first);
    await tester.tapAndSettle(find.text('Categories'));
    await tester.tapAndSettle(find.text('Add category'));
    await tester.enterTextInField('Name', 'Work');
    await tester.tapAndSettle(find.text('Save'));
    expect(find.text('Work'), findsOneWidget);

    await tester.tapAndSettle(find.text('Plan').first);
    await tester.tapAndSettle(find.text('Add Task'));
    await tester.enterTextInField('Title', 'Write report');
    await tester.tapAndSettle(find.widgetWithText(ChoiceChip, 'Work'));
    await tester.tapAndSettle(find.text('Save Task'));

    await tester.tapAndSettle(find.widgetWithText(FilterChip, 'Work'));
    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await tester.tapAndSettle(find.widgetWithText(FilterChip, 'All'));
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tapAndSettle(find.byTooltip('Show as board'));
    expect(find.text('No category'), findsOneWidget);
    await tester.tapAndSettle(find.byTooltip('Focus on Work'));
    expect(find.text('Focus: Work'), findsOneWidget);
    expect(find.text('Write report'), findsOneWidget);

    await tester.tapAndSettle(find.text('Complete Task'));
    expect(find.text('Finished for Today!'), findsOneWidget, reason: 'the queue had only the Work task');
    final remaining = await tasks.getTasksForDay(DateTime.now());
    expect(remaining.map((task) => (task.title, task.isCompleted)), [('Groceries', false), ('Write report', true)]);

    await app.restart(tester);
    expect(find.byTooltip('Show as list'), findsOneWidget, reason: 'the board view is remembered');

    // Each group shows how many of its tasks are done (#57).
    expect(find.byTooltip('1 of 1 task done (100%)'), findsOneWidget, reason: 'Work');
    expect(find.byTooltip('0 of 1 task done (0%)'), findsOneWidget, reason: 'no category');
    await tester.tapAndSettle(
      find.descendant(
        of: find.ancestor(of: find.text('Groceries'), matching: find.byType(Card)),
        matching: find.byType(Checkbox),
      ),
    );
    expect(find.byTooltip('1 of 1 task done (100%)'), findsNWidgets(2));
  });

  testWidgets('intervals: a break left open by a crash is closed without asking; turned on, focus shows the next break', (tester) async {
    // The desktop window size differs per machine (and on CI); this size keeps every control on screen.
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.start(
      tester,
      seed: (database) async {
        await TaskRepositoryImpl(database).createTask(title: 'Deep work', assignedDate: DateTime.now(), sortOrder: 'a0');
        // The app was killed during a break.
        await database.startSession(kind: 'break', at: DateTime.now().subtract(const Duration(minutes: 3)));
      },
    );
    expect(find.text('Recover unfinished session?'), findsNothing);
    expect(await app.database.getOpenSession(), isNull, reason: 'the break session was closed');

    await tester.tapAndSettle(find.text('Settings').first);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsIntervals')),
      200,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.tapAndSettle(find.byKey(const Key('settingsIntervals')));
    expect(app.preferences.getBool('settings.intervals_enabled'), isTrue);
    expect(find.text('Work interval'), findsOneWidget);

    await tester.tapAndSettle(find.text('Plan').first);
    await tester.tapAndSettle(find.text('Start focus'));
    expect(find.textContaining('Break in 00:2'), findsOneWidget);

    await tester.tapAndSettle(find.text('Exit Focus'));
    expect(await app.database.getOpenSession(), isNull);
  });

  testWidgets('distractions: count one, park a thought in focus, review it on the plan and turn it into a task', (tester) async {
    // The desktop window size differs per machine (and on CI); this size keeps every control on screen.
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.start(tester);
    await TaskRepositoryImpl(app.database).createTask(title: 'Deep work', assignedDate: DateTime.now(), sortOrder: 'a0');
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.text('Start focus'));
    await tester.tapAndSettle(find.byTooltip('I got distracted'));
    await tester.enterText(find.byKey(const Key('focusParkThought')), 'Book dentist');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // The close button in the app bar; the snack bars cover the bottom of the screen.
    await tester.tapAndSettle(find.byTooltip('Exit focus'));

    final session = (await app.database.select(app.database.focusSessions).get()).single;
    expect(session.interruptions, 1);
    expect(find.text('1 parked thought'), findsOneWidget);

    await tester.tapAndSettle(find.text('Review'));
    await tester.tapAndSettle(find.byTooltip('Add as a task for tomorrow'));
    expect(find.text('Added to tomorrow.'), findsOneWidget);
    final task = (await app.database.select(app.database.tasks).get()).last;
    expect((task.title, task.assignedDate), ('Book dentist', DateTime.now().dateOnly.nextDay));
    expect((await app.database.select(app.database.inboxItems).getSingle()).resolvedAt, isNotNull);
  });
}
