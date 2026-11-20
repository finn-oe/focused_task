import 'package:drift/drift.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/inbox/domain/i_inbox_repository.dart';
import 'package:focused_task/features/inbox/domain/inbox_item.dart';

class InboxRepositoryImpl implements IInboxRepository {
  InboxRepositoryImpl(this._database);

  final AppDatabase _database;

  static InboxItem toEntity(InboxItemRow row) {
    return InboxItem(id: row.id, text: row.content, createdAt: row.createdAt, sessionId: row.sessionId, resolvedAt: row.resolvedAt);
  }

  @override
  Future<int> addInboxItem({required String text, required DateTime at, int? sessionId}) {
    return _database.addInboxItem(InboxItemsCompanion.insert(content: text.trim(), createdAt: at, sessionId: Value(sessionId)));
  }

  @override
  Stream<List<InboxItem>> watchOpenInboxItems() => _database.watchOpenInboxItems().map((rows) => rows.map(toEntity).toList(growable: false));

  @override
  Stream<List<InboxItem>> watchInboxItemsCreated(DateTime start, DateTime endExclusive, {int limit = 5}) {
    return _database.watchInboxItemsCreated(start, endExclusive, limit: limit).map((rows) => rows.map(toEntity).toList(growable: false));
  }

  @override
  Future<void> resolveInboxItem(int id, DateTime at) => _database.setInboxItemResolved(id, at);

  @override
  Future<void> reopenInboxItem(int id) => _database.setInboxItemResolved(id, null);
}
