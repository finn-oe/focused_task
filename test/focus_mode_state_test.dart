import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/tasks/presentation/focus_mode/focus_notifier.dart';

import 'helpers/task_builders.dart';

void main() {
  group('FocusModeState', () {
    test('clears the current task when requested', () {
      final state = FocusModeState.initial().copyWith(currentTask: buildTask());

      final cleared = state.copyWith(clearCurrentTask: true);

      expect(cleared.currentTask, isNull);
    });
  });
}
