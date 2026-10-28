import 'dart:io';

import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/events/sqflite_event_repository.dart';
import 'package:daily_anchor/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppEvent _event(String id, DateTime occurredAt) => AppEvent(
  id: id,
  type: EventType.routineCompleted,
  payload: {'routineId': 'morning-water'},
  occurredAt: occurredAt,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('stores an event and reads it back with its payload', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    final when = DateTime.utc(2026, 10, 28, 9);

    await repository.append(_event('e1', when));
    final events = await repository.occurredSince(DateTime.utc(2026, 10, 28));

    expect(events, hasLength(1));
    expect(events.single.id, 'e1');
    expect(events.single.type, EventType.routineCompleted);
    expect(events.single.payload['routineId'], 'morning-water');
    expect(events.single.occurredAt, when);
    expect(events.single.synced, isFalse);
    await db.close();
  });

  test('ignores a second event with the same id', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteEventRepository(db);
    final when = DateTime.utc(2026, 10, 28, 9);

    await repository.append(_event('e1', when));
    await repository.append(_event('e1', when));

    expect(
      await repository.occurredSince(DateTime.utc(2026, 10, 28)),
      hasLength(1),
    );
    await db.close();
  });

  test(
    'only returns events from the given time onwards, oldest first',
    () async {
      final db = await openAppDatabase(path: inMemoryDatabasePath);
      final repository = SqfliteEventRepository(db);

      await repository.append(_event('late', DateTime.utc(2026, 10, 28, 12)));
      await repository.append(_event('old', DateTime.utc(2026, 10, 27, 12)));
      await repository.append(_event('early', DateTime.utc(2026, 10, 28, 8)));

      final events = await repository.occurredSince(DateTime.utc(2026, 10, 28));

      expect(events.map((e) => e.id), ['early', 'late']);
      await db.close();
    },
  );

  test('events survive closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('daily_anchor_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/events.db';

    final first = await openAppDatabase(path: path);
    await SqfliteEventRepository(first)
        .append(_event('e1', DateTime.utc(2026, 10, 28, 9)));
    await first.close();

    final second = await openAppDatabase(path: path);
    final events = await SqfliteEventRepository(second)
        .occurredSince(DateTime.utc(2026, 10, 28));

    expect(events.map((e) => e.id), ['e1']);
    await second.close();
  });
}
