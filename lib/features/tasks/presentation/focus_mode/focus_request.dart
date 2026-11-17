import 'package:focused_task/core/utils/date_utils.dart';

/// What focus mode works on: the open tasks of [day], starting with [startTaskId] if given.
class FocusRequest {
  FocusRequest(DateTime day, {this.startTaskId, this.categoryId}) : day = day.dateOnly;

  final DateTime day;
  final int? startTaskId;

  /// Focus on one category only; used from #2 on.
  final int? categoryId;

  @override
  bool operator ==(Object other) => other is FocusRequest && other.day == day && other.startTaskId == startTaskId && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(day, startTaskId, categoryId);
}
