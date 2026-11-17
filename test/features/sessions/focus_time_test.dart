import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';
import 'package:focused_task/features/sessions/domain/focus_time.dart';

FocusSession _session(DateTime start, DateTime? end, {int? taskId = 1, SessionKind kind = SessionKind.focus, DateTime? lastSeenAt, int id = 1}) {
  return FocusSession(id: id, taskId: taskId, kind: kind, startedAt: start, endedAt: end, lastSeenAt: lastSeenAt ?? end ?? start);
}

void main() {
  final day1 = DateTime(2026, 11, 16);
  final day2 = DateTime(2026, 11, 17);

  test('a session from 23:30 to 00:30 counts 30 minutes on each day', () {
    final session = _session(DateTime(2026, 11, 16, 23, 30), DateTime(2026, 11, 17, 0, 30));

    expect(focusTimeByDay([session], DateRange(day1, day2)), {day1: const Duration(minutes: 30), day2: const Duration(minutes: 30)});
    expect(focusTimeByTask([session], DateRange(day2, day2)), {1: const Duration(minutes: 30)});
  });

  test('splits at local midnight on daylight-saving days', () {
    // Europe/Berlin falls back on 2026-10-25; the day boundaries come from calendar arithmetic either way.
    final session = _session(DateTime(2026, 10, 25, 22), DateTime(2026, 10, 26, 2));
    final byDay = focusTimeByDay([session], DateRange(DateTime(2026, 10, 25), DateTime(2026, 10, 26)));

    expect(byDay[DateTime(2026, 10, 25)], DateTime(2026, 10, 26).difference(DateTime(2026, 10, 25, 22)));
    expect(byDay[DateTime(2026, 10, 26)], const Duration(hours: 2));
  });

  test('open sessions count until their last heartbeat; breaks never count', () {
    final open = _session(DateTime(2026, 11, 17, 9), null, lastSeenAt: DateTime(2026, 11, 17, 9, 20));
    final pause = _session(DateTime(2026, 11, 17, 10), DateTime(2026, 11, 17, 10, 15), kind: SessionKind.breakTime, id: 2);

    expect(focusTimeByDay([open, pause], DateRange(day2, day2)), {day2: const Duration(minutes: 20)});
  });

  test('deleted tasks are collected under null', () {
    final sessions = [_session(DateTime(2026, 11, 17, 9), DateTime(2026, 11, 17, 10), taskId: null)];

    expect(focusTimeByTask(sessions, DateRange(day2, day2)), {null: const Duration(hours: 1)});
  });

  test('EndReason and SessionKind round-trip through their stored names', () {
    for (final reason in EndReason.values) {
      expect(EndReason.fromStorage(reason.name), reason);
    }
    expect(SessionKind.fromStorage(SessionKind.breakTime.storageName), SessionKind.breakTime);
    expect(SessionKind.fromStorage('focus'), SessionKind.focus);
  });
}
