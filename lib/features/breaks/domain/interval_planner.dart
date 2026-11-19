import 'package:focused_task/features/breaks/domain/interval_settings.dart';

/// Phase of a work/break cycle.
enum IntervalPhase {
  work,
  shortBreak,
  longBreak;

  bool get isBreak => this != work;
}

/// Pure state machine of the work/break cycle: work → short break → work → … → long break (every
/// [IntervalSettings.longBreakEvery]th break) → work …
///
/// Immutable; every transition returns a new planner. A phase is *running* (counting down since [startedAt]),
/// *paused* (keeps [elapsedBefore]) or *waiting* (not started yet, e.g. the next work interval after a break without
/// auto-start). Time is always passed in, so it can be tested with fake time.
class IntervalPlanner {
  const IntervalPlanner({required this.settings, this.phase = IntervalPhase.work, this.completedWork = 0, this.startedAt, this.elapsedBefore = Duration.zero});

  final IntervalSettings settings;
  final IntervalPhase phase;

  /// Work intervals finished so far; decides when the long break comes.
  final int completedWork;

  /// When the running part of [phase] started; `null` while paused or waiting.
  final DateTime? startedAt;

  /// Time of [phase] that ran before the last pause.
  final Duration elapsedBefore;

  bool get isRunning => startedAt != null;

  /// The phase hasn't started yet (or was paused before any time ran).
  bool get isWaiting => startedAt == null && elapsedBefore == Duration.zero;

  /// Length of the current phase.
  Duration get phaseDuration => switch (phase) {
    IntervalPhase.work => settings.work,
    IntervalPhase.shortBreak => settings.shortBreak,
    IntervalPhase.longBreak => settings.longBreak,
  };

  /// The phase that follows the current one.
  IntervalPhase get nextPhase {
    if (phase.isBreak) return IntervalPhase.work;
    final every = settings.longBreakEvery < 1 ? 1 : settings.longBreakEvery;
    return (completedWork + 1) % every == 0 ? IntervalPhase.longBreak : IntervalPhase.shortBreak;
  }

  Duration elapsed(DateTime now) {
    final running = startedAt == null ? Duration.zero : now.difference(startedAt!);
    return elapsedBefore + (running.isNegative ? Duration.zero : running);
  }

  /// Time left in the current phase; zero once it is over.
  Duration remaining(DateTime now) {
    final left = phaseDuration - elapsed(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// When the running phase is over; `null` while paused or waiting.
  DateTime? get endsAt => startedAt?.add(phaseDuration - elapsedBefore);

  /// Whether the running phase is over at [now].
  bool isDue(DateTime now) => isRunning && remaining(now) == Duration.zero;

  /// Starts or resumes the current phase at [now]. Does nothing if it is running.
  IntervalPlanner start(DateTime now) => isRunning ? this : _copy(startedAt: now);

  /// Freezes the current phase at [now]; [start] continues it with the time that was left.
  IntervalPlanner pause(DateTime now) => isRunning ? _copy(elapsedBefore: elapsed(now), clearStartedAt: true) : this;

  /// Finishes the current phase at [at] (normally its [endsAt]) and moves on: a finished work interval counts towards
  /// the long break. The next phase starts at [at] if [start] is true, otherwise it waits.
  IntervalPlanner next(DateTime at, {bool start = true}) => _advance(at, countWork: true, start: start);

  /// Ends the current phase early at [now] and starts the next one: skipping a break goes back to work; a skipped work
  /// interval doesn't count, so a short break follows.
  IntervalPlanner skip(DateTime now) => _advance(now, countWork: false, start: true);

  IntervalPlanner _advance(DateTime at, {required bool countWork, required bool start}) {
    return IntervalPlanner(
      settings: settings,
      phase: phase.isBreak || countWork ? nextPhase : IntervalPhase.shortBreak,
      completedWork: phase == IntervalPhase.work && countWork ? completedWork + 1 : completedWork,
      startedAt: start ? at : null,
    );
  }

  IntervalPlanner _copy({DateTime? startedAt, Duration? elapsedBefore, bool clearStartedAt = false}) {
    return IntervalPlanner(
      settings: settings,
      phase: phase,
      completedWork: completedWork,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      elapsedBefore: elapsedBefore ?? this.elapsedBefore,
    );
  }

  @override
  String toString() => 'IntervalPlanner($phase, completed: $completedWork, startedAt: $startedAt, elapsedBefore: $elapsedBefore)';
}
