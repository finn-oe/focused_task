import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/tasks/domain/entities/task.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/task_form_screen.dart';
import 'package:focused_task/features/tasks/presentation/plan_mode/widgets/task_list_item.dart';

import '../../../helpers/fake_preferences.dart';
import '../../../helpers/fake_task_repository.dart';
import '../../../helpers/localized_app.dart';
import '../../../helpers/task_builders.dart';

/// Opens the form on top of a home page, so leaving it (and the discard prompt) can be tested.
Future<FakeTaskRepository> _openForm(WidgetTester tester, {TaskEntity? task, Size size = const Size(800, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = FakeTaskRepository(tasks: [?task]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        focusSessionRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(repository),
        inboxRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
      ],
      child: localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskFormScreen(task: task))),
                child: const Text('open form'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open form'));
  await tester.pumpAndSettle();
  return repository;
}

Finder get _formList => find.byType(Scrollable).first;

EditableText _editable(WidgetTester tester, String label) =>
    tester.widget<EditableText>(find.descendant(of: find.widgetWithText(TextField, label), matching: find.byType(EditableText)));

void main() {
  final today = DateTime.now().dateOnly;

  testWidgets('saving without a title shows an error and saves nothing', (tester) async {
    final repository = await _openForm(tester);

    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a title.'), findsOneWidget);
    expect(repository.tasks, isEmpty);
    expect(find.byType(TaskFormScreen), findsOneWidget, reason: 'the form stays open');
  });

  testWidgets('duration chips, priority and inline sub-tasks are saved', (tester) async {
    final repository = await _openForm(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Write report');
    await tester.tap(find.text('25 min'));
    await tester.tap(find.text('High'));
    await tester.pump();
    final newSubTask = find.widgetWithText(TextField, 'Add sub-task');
    await tester.scrollUntilVisible(newSubTask, 200, scrollable: _formList);
    for (final title in ['Outline', 'Draft']) {
      await tester.enterText(newSubTask, title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
    expect(tester.testTextInput.isVisible, isTrue, reason: 'Enter keeps the keyboard open for the next sub-task');

    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();

    final task = repository.tasks.single;
    expect((task.title, task.targetDurationMinutes, task.priority), ('Write report', 25, TaskPriority.high));
    expect(task.todos.map((todo) => todo.title), ['Outline', 'Draft']);
  });

  testWidgets('custom duration accepts hours and minutes up to 12 hours', (tester) async {
    final repository = await _openForm(tester, task: buildTask(assignedDate: today, targetDurationMinutes: 25));

    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '13');
    await tester.pump();
    expect(find.text('At most 12 hours.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '30');
    await tester.pump();
    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();

    expect(repository.task(1).targetDurationMinutes, 150);
  });

  testWidgets('the delete dialog names the tracked time and can be cancelled', (tester) async {
    final repository = await _openForm(
      tester,
      task: buildTask(title: 'Report', assignedDate: today, timeSpent: const Duration(minutes: 80).inMilliseconds),
    );

    await tester.tap(find.byTooltip('Delete Task'));
    await tester.pumpAndSettle();
    expect(find.textContaining('01:20 h of tracked time'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.tasks, hasLength(1));

    await tester.tap(find.byTooltip('Delete Task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.tasks, isEmpty);
    expect(find.byType(TaskFormScreen), findsNothing);
  });

  testWidgets('back after an edit asks to discard; without edits it just leaves', (tester) async {
    await _openForm(
      tester,
      task: buildTask(title: 'Report', assignedDate: today),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Report v2');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsNothing);

    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(TaskFormScreen), findsNothing);
  });

  testWidgets('works on a 360 px screen with the keyboard open', (tester) async {
    await _openForm(
      tester,
      task: buildTask(
        assignedDate: today,
        todos: const [TaskTodoEntity(title: 'Sub', isCompleted: false, sortOrder: 'a0')],
      ),
      size: const Size(360, 640),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Tracked time'), 200, scrollable: _formList);
    expect(tester.takeException(), isNull);
  });

  testWidgets('past tasks can be edited; moving and copying stay available', (tester) async {
    final past = buildTask(title: 'Yesterday', assignedDate: today.addDays(-1), priority: TaskPriority.medium);
    final repository = FakeTaskRepository(tasks: [past]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          focusSessionRepositoryProvider.overrideWithValue(repository),
          categoryRepositoryProvider.overrideWithValue(repository),
          inboxRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(await fakePreferences()),
        ],
        child: localizedApp(
          home: Scaffold(
            body: ReorderableListView(
              onReorderItem: (_, _) {},
              children: [TaskListItem(key: const ValueKey(1), task: past, index: 0)],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit Task'), findsOneWidget);
    expect(find.byTooltip('Move or copy'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget, reason: 'medium priority shows a flag');
  });

  group('keyboard (#56)', () {
    testWidgets('tapping outside the fields closes the keyboard after adding sub-tasks', (tester) async {
      await _openForm(tester, size: const Size(400, 700));
      final newSubTask = find.widgetWithText(TextField, 'Add sub-task');
      await tester.scrollUntilVisible(newSubTask, 200, scrollable: _formList);
      await tester.enterText(newSubTask, 'Outline');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_editable(tester, 'Add sub-task').focusNode.hasFocus, isTrue);

      // A plain heading: the tap lands on the form's empty background, i.e. outside every field.
      await tester.tap(find.text('Sub-tasks'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(_editable(tester, 'Add sub-task').focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('the app bar save works while the sub-task field has focus', (tester) async {
      final repository = await _openForm(tester, size: const Size(400, 700));
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Write report');
      final newSubTask = find.widgetWithText(TextField, 'Add sub-task');
      await tester.scrollUntilVisible(newSubTask, 200, scrollable: _formList);
      for (final title in ['Outline', 'Draft']) {
        await tester.enterText(newSubTask, title);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byTooltip('Save Task'));
      await tester.pumpAndSettle();

      expect(repository.tasks.single.todos.map((todo) => todo.title), ['Outline', 'Draft']);
      expect(find.byType(TaskFormScreen), findsNothing);
    });

    testWidgets('tapping another field moves the focus there', (tester) async {
      await _openForm(tester);
      await tester.tap(find.widgetWithText(TextFormField, 'Description'));
      await tester.pump();
      expect(_editable(tester, 'Description').focusNode.hasFocus, isTrue);

      await tester.tap(find.widgetWithText(TextFormField, 'Title'));
      await tester.pump();

      expect(_editable(tester, 'Title').focusNode.hasFocus, isTrue);
      expect(_editable(tester, 'Description').focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });
}
