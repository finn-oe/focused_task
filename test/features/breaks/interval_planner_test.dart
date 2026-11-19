import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/features/breaks/domain/interval_planner.dart';
import 'package:focused_task/features/breaks/domain/interval_settings.dart';

void main() {
  const settings = IntervalSettings(isEnabled: true);
  final start = DateTime(2026, 11, 17, 9);
  DateTime at(int minutes) => start.add(Duration(minutes: minutes));

  test('a fresh planner waits for work until it is started', () {
    const planner = IntervalPlanner(settings: settings);
    expect(planner.phase, IntervalPhase.work);
    expect(planner.isWaiting, isTrue);
    expect(planner.isRunning, isFalse);
    expect(planner.endsAt, isNull);
    expect(planner.isDue(at(100)), isFalse);
    expect(planner.remaining(at(100)), const Duration(minutes: 25));
  });

  test('counts down the running phase', () {
    final planner = const IntervalPlanner(settings: settings).start(start);
    expect(planner.remaining(at(10)), const Duration(minutes: 15));
    expect(planner.endsAt, at(25));
    expect(planner.isDue(at(24)), isFalse);
    expect(planner.isDue(at(25)), isTrue);
    expect(planner.remaining(at(30)), Duration.zero);
  });

  test('a full cycle: four work intervals, short breaks in between, then a long break', () {
    var planner = const IntervalPlanner(settings: settings).start(start);
    final phases = <IntervalPhase>[];
    for (var i = 0; i < 8; i++) {
      planner = planner.next(planner.endsAt!);
      phases.add(planner.phase);
    }
    expect(phases, [
      IntervalPhase.shortBreak,
      IntervalPhase.work,
      IntervalPhase.shortBreak,
      IntervalPhase.work,
      IntervalPhase.shortBreak,
      IntervalPhase.work,
      IntervalPhase.longBreak,
      IntervalPhase.work,
    ]);
    expect(planner.completedWork, 4);
    // 4 × 25 min work + 3 × 5 min + 15 min long break.
    expect(planner.startedAt, at(4 * 25 + 3 * 5 + 15));
  });

  test('the long break follows the configured number of intervals', () {
    var planner = const IntervalPlanner(settings: IntervalSettings(isEnabled: true, longBreakEvery: 2)).start(start);
    planner = planner.next(planner.endsAt!); // short
    expect(planner.phase, IntervalPhase.shortBreak);
    planner = planner.next(planner.endsAt!).next(at(60)); // work, then long
    expect(planner.phase, IntervalPhase.longBreak);
    expect(planner.phaseDuration, const Duration(minutes: 15));
  });

  test('next without start leaves the following phase waiting', () {
    final onBreak = const IntervalPlanner(settings: settings).start(start).next(at(25));
    final waiting = onBreak.next(at(30), start: false);
    expect(waiting.phase, IntervalPhase.work);
    expect(waiting.isWaiting, isTrue);
    expect(waiting.start(at(40)).endsAt, at(65));
  });

  test('skipping a break goes back to work right away', () {
    final onBreak = const IntervalPlanner(settings: settings).start(start).next(at(25));
    final skipped = onBreak.skip(at(27));
    expect(skipped.phase, IntervalPhase.work);
    expect(skipped.startedAt, at(27));
    expect(skipped.completedWork, 1);
  });

  test('a skipped work interval does not count towards the long break', () {
    var planner = const IntervalPlanner(settings: IntervalSettings(isEnabled: true, longBreakEvery: 1)).start(start);
    planner = planner.skip(at(5));
    expect(planner.phase, IntervalPhase.shortBreak);
    expect(planner.completedWork, 0);
  });

  test('pause freezes the remaining time and start continues it', () {
    var planner = const IntervalPlanner(settings: settings).start(start);
    planner = planner.pause(at(10));
    expect(planner.isRunning, isFalse);
    expect(planner.isWaiting, isFalse);
    expect(planner.remaining(at(50)), const Duration(minutes: 15));
    expect(planner.isDue(at(500)), isFalse);

    planner = planner.start(at(60));
    expect(planner.endsAt, at(75));
    expect(planner.isDue(at(75)), isTrue);
  });

  test('pausing during a break keeps the rest of the break', () {
    var planner = const IntervalPlanner(settings: settings).start(start).next(at(25));
    planner = planner.pause(at(27));
    expect(planner.phase, IntervalPhase.shortBreak);
    expect(planner.remaining(at(90)), const Duration(minutes: 3));
    expect(planner.start(at(90)).endsAt, at(93));
  });

  test('start and pause are idempotent', () {
    final running = const IntervalPlanner(settings: settings).start(start);
    expect(running.start(at(10)).startedAt, start);
    final paused = running.pause(at(5));
    expect(paused.pause(at(20)).elapsedBefore, const Duration(minutes: 5));
  });
}
