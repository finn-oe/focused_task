import 'package:focused_task/core/services/target_alarm.dart';

/// Records alarm calls; [scheduledAt] is the currently pending alarm (or `null`).
class FakeTargetAlarm implements TargetAlarm {
  DateTime? scheduledAt;
  int scheduleCount = 0;
  int cancelCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule({required String taskTitle, required DateTime at}) async {
    scheduledAt = at;
    scheduleCount++;
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    cancelCount++;
  }
}
