import 'dart:io';

import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/events/sqflite_event_repository.dart';
import 'package:daily_anchor/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppEvent _event(String id, DateTime at) => AppEvent(
  id: id,
  type: EventType.routineCompleted,
  payload: {'routineId': 'morning-water'},
  occurredAt: at,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('new events are waiting to upload', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);

    await repository.append(_event('a', DateTime.utc(2026, 10, 28, 9)));
    await repository.append(_event('b', DateTime.utc(2026, 10, 28, 10)));

    expect(await repository.unsyncedCount(), 2);
    expect((await repository.unsynced()).map((e) => e.id), ['a', 'b']);
    await db.close();
  });

  test('returns the oldest waiting events first, up to the limit', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    await repository.append(_event('late', DateTime.utc(2026, 10, 28, 12)));
    await repository.append(_event('early', DateTime.utc(2026, 10, 28, 8)));
    await repository.append(_event('middle', DateTime.utc(2026, 10, 28, 10)));

    final firstTwo = await repository.unsynced(limit: 2);

    expect(firstTwo.map((e) => e.id), ['early', 'middle']);
    await db.close();
  });

  test('marked events leave the waiting list and stay stored', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    await repository.append(_event('a', DateTime.utc(2026, 10, 28, 9)));
    await repository.append(_event('b', DateTime.utc(2026, 10, 28, 10)));

    await repository.markSynced(['a']);

    expect((await repository.unsynced()).map((e) => e.id), ['b']);
    expect(await repository.unsyncedCount(), 1);
    final all = await repository.occurredSince(DateTime.utc(2026, 10, 28));
    expect(all.map((e) => e.id), ['a', 'b']);
    expect(all.firstWhere((e) => e.id == 'a').synced, isTrue);
    expect(all.firstWhere((e) => e.id == 'b').synced, isFalse);
    await db.close();
  });

  test('marking nothing, or unknown ids, does no harm', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    await repository.append(_event('a', DateTime.utc(2026, 10, 28, 9)));

    await repository.markSynced([]);
    await repository.markSynced(['does-not-exist']);

    expect(await repository.unsyncedCount(), 1);
    await db.close();
  });

  test('can mark more events than one SQL statement allows', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    final ids = List.generate(1200, (i) => 'event-$i');
    for (final id in ids) {
      await repository.append(_event(id, DateTime.utc(2026, 10, 28, 9)));
    }

    await repository.markSynced(ids);

    expect(await repository.unsyncedCount(), 0);
    await db.close();
  });

  test('the waiting queue survives closing and reopening the app', () async {
    final dir = await Directory.systemTemp.createTemp('daily_anchor_queue');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/queue.db';

    final first = await openAppDatabase(path: path);
    final before = SqfliteEventRepository(first);
    await before.append(_event('a', DateTime.utc(2026, 10, 28, 9)));
    await before.append(_event('b', DateTime.utc(2026, 10, 28, 10)));
    await before.markSynced(['a']);
    await first.close();

    final second = await openAppDatabase(path: path);
    final after = SqfliteEventRepository(second);

    expect((await after.unsynced()).map((e) => e.id), ['b']);
    expect(await after.unsyncedCount(), 1);
    await second.close();
  });
}
