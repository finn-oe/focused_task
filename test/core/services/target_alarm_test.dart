import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/services/target_alarm.dart';

const _notification = AlarmNotification(title: 'Time is up!', body: 'Task', stopButton: 'Stop');

void main() {
  group('TimerTargetAlarm', () {
    late int rings;
    late int stops;
    late TimerTargetAlarm alarm;

    setUp(() {
      rings = 0;
      stops = 0;
      alarm = TimerTargetAlarm(ring: () async => rings++, stop: () async => stops++);
    });

    test('rings at the scheduled time', () {
      fakeAsync((async) {
        alarm.schedule(notification: _notification, at: clock.now().add(const Duration(minutes: 5)));

        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(rings, 0);
        async.elapse(const Duration(seconds: 1));
        expect(rings, 1);
      });
    });

    test('cancel prevents a pending alarm from ringing', () {
      fakeAsync((async) {
        alarm.schedule(notification: _notification, at: clock.now().add(const Duration(minutes: 5)));
        alarm.cancel();

        async.elapse(const Duration(hours: 1));
        expect(rings, 0);
        expect(stops, 1);
        expect(alarm.isPending, isFalse);
      });
    });

    test('rescheduling replaces the previous alarm instead of adding a second one', () {
      fakeAsync((async) {
        alarm.schedule(notification: _notification, at: clock.now().add(const Duration(minutes: 5)));
        alarm.schedule(notification: _notification, at: clock.now().add(const Duration(minutes: 10)));

        async.elapse(const Duration(minutes: 5));
        expect(rings, 0);
        async.elapse(const Duration(minutes: 5));
        expect(rings, 1);
        async.elapse(const Duration(hours: 1));
        expect(rings, 1);
      });
    });

    test('a time in the past rings immediately', () {
      fakeAsync((async) {
        alarm.schedule(notification: _notification, at: clock.now().subtract(const Duration(minutes: 1)));
        async.flushTimers();
        expect(rings, 1);
      });
    });
  });
}
