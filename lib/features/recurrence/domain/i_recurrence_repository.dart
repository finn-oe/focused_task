import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/features/recurrence/domain/recurrence_rule.dart';

/// Recurring tasks (#24). Occurrences are ordinary tasks; deleting one through `ITaskRepository.deleteTask` remembers
/// its day, so it isn't created again.
abstract class IRecurrenceRepository {
  Future<RecurrenceRule?> getRule(int id);

  /// Saves a new [rule]. With [taskId], that existing task becomes the rule's occurrence of its start date.
  Future<int> createRule(RecurrenceRule rule, {int? taskId});

  /// "This and future" (#24): the rule [ruleId] ends the day before [from] and [next] (if given) takes over from
  /// [from]. Task [taskId] (the occurrence being edited) moves to the new rule, or becomes a one-off task without one.
  /// Later occurrences that are open and untracked are removed (the new rule creates them again); the others keep their
  /// tracked time and move to the new rule (or become one-off tasks).
  ///
  /// Returns the id of the new rule.
  Future<int?> replaceFrom({required int ruleId, required DateTime from, required int taskId, RecurrenceRule? next});

  /// "Delete this and future": like [replaceFrom] without a new rule, and task [taskId] is deleted.
  Future<void> endBefore({required int ruleId, required DateTime from, required int taskId});

  /// Creates the missing occurrences of all rules for the days of [range] from today on (idempotent). Days in the past
  /// keep what they have; deleted occurrences don't come back.
  Future<void> ensureOccurrences(DateRange range);
}
