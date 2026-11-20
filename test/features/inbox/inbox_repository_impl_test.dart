import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focused_task/core/database/app_database.dart';
import 'package:focused_task/features/inbox/data/inbox_repository_impl.dart';
import 'package:focused_task/features/sessions/data/focus_session_repository_impl.dart';
import 'package:focused_task/features/sessions/domain/focus_session.dart';

void main() {
  late AppDatabase database;
  late InboxRepositoryImpl inbox;
  final nine = DateTime(2026, 11, 20, 9);
  DateTime at(int minutes) => nine.add(Duration(minutes: minutes));

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    inbox = InboxRepositoryImpl(database);
  });
  tearDown(() => database.close());

  test('parks thoughts (trimmed) with their session; open items come oldest first', () async {
    final session = await FocusSessionRepositoryImpl(database).start(at: nine);
    await inbox.addInboxItem(text: ' buy milk  ', at: at(5), sessionId: session.id);
    await inbox.addInboxItem(text: 'call Anna', at: at(2));

    final open = await inbox.watchOpenInboxItems().first;
    expect(open.map((item) => item.text), ['call Anna', 'buy milk']);
    expect(open.last.sessionId, session.id);
    expect(open.last.createdAt, at(5));
    expect(open.first.sessionId, isNull);
  });

  test('resolving takes an item out of the inbox and reopening puts it back', () async {
    final id = await inbox.addInboxItem(text: 'idea', at: at(0));
    final stream = inbox.watchOpenInboxItems();
    final emissions = <int>[];
    final subscription = stream.listen((items) => emissions.add(items.length));
    await pumpEventQueue();

    await inbox.resolveInboxItem(id, at(30));
    await pumpEventQueue();
    await inbox.reopenInboxItem(id);
    await pumpEventQueue();
    await subscription.cancel();

    expect(emissions, [1, 0, 1]);
    final row = await database.select(database.inboxItems).getSingle();
    expect(row.resolvedAt, isNull);
  });

  test('items created in a range: newest first, at most the limit, resolved ones included', () async {
    for (var minute = 0; minute < 7; minute++) {
      await inbox.addInboxItem(text: 'thought $minute', at: at(minute * 10));
    }
    await inbox.addInboxItem(text: 'tomorrow', at: DateTime(2026, 11, 21, 9));
    await inbox.resolveInboxItem(1, at(100));

    final recent = await inbox.watchInboxItemsCreated(DateTime(2026, 11, 20), DateTime(2026, 11, 21)).first;
    expect(recent.map((item) => item.text), ['thought 6', 'thought 5', 'thought 4', 'thought 3', 'thought 2']);

    final all = await inbox.watchInboxItemsCreated(DateTime(2026, 11, 20), DateTime(2026, 11, 21), limit: 10).first;
    expect(all, hasLength(7));
    expect(all.last.isResolved, isTrue);
  });

  test('interruptions are counted on a session, also after it ended', () async {
    final sessions = FocusSessionRepositoryImpl(database);
    final session = await sessions.start(at: nine);
    await sessions.addInterruption(session.id);
    await sessions.end(session.id, at(25), EndReason.paused);
    await sessions.addInterruption(session.id);

    final row = await database.select(database.focusSessions).getSingle();
    expect(row.interruptions, 2);
    expect(row.endedAt, at(25), reason: 'counting does not change the session');
  });
}
