import 'package:focused_task/features/inbox/domain/inbox_item.dart';

/// The distraction inbox (#28).
abstract class IInboxRepository {
  /// Parks [text] at [at], linked to the focus session [sessionId] if given. Returns the new item's id.
  Future<int> addInboxItem({required String text, required DateTime at, int? sessionId});

  /// Items waiting for review, oldest first.
  Stream<List<InboxItem>> watchOpenInboxItems();

  /// Items parked in `[start, endExclusive)`, newest first, at most [limit] (for the statistics).
  Stream<List<InboxItem>> watchInboxItemsCreated(DateTime start, DateTime endExclusive, {int limit = 5});

  /// Marks item [id] as reviewed (turned into a task or dismissed) at [at].
  Future<void> resolveInboxItem(int id, DateTime at);

  /// Puts item [id] back into the inbox (undo).
  Future<void> reopenInboxItem(int id);
}
