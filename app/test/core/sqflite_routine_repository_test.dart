import 'dart:io';

import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/events/sqflite_event_repository.dart';
import 'package:daily_anchor/core/storage/app_database.dart';
import 'package:daily_anchor/features/today/routine.dart';
import 'package:daily_anchor/features/today/routine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _eventsTable = '''
  CREATE TABLE events (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    payload TEXT NOT NULL,
    occurred_at INTEGER NOT NULL,
    synced INTEGER NOT NULL DEFAULT 0
  )
''';

AppEvent _event(String id) => AppEvent(
  id: id,
  type: EventType.routineCompleted,
  payload: {'routineId': 'morning-water'},
  occurredAt: DateTime.utc(2026, 10, 28, 9),
);

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('daily_anchor_routines');
  });

  tearDown(() => dir.delete(recursive: true));

  test('a new database has no routines', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);

    expect(await SqfliteRoutineRepository(db).list(), isEmpty);
    await db.close();
  });

  test('adds, renames and deletes routines, keeping the order added', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteRoutineRepository(db);

    await repository.add(const Routine(id: 'r1', title: 'Stretch'));
    await repository.add(
      const Routine(id: 'r2', title: 'Water', iconKey: 'water'),
    );
    await repository.add(const Routine(id: 'r3', title: 'Read'));
    await repository.rename('r1', 'Gentle stretch');
    await repository.delete('r2');
    final routines = await repository.list();

    expect(routines.map((r) => r.id), ['r1', 'r3']);
    expect(routines.first.title, 'Gentle stretch');
    expect(routines.first.iconKey, Routine.defaultIconKey);
    await db.close();
  });

  test('deleting a routine keeps its completion events', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    await SqfliteRoutineRepository(db)
        .add(const Routine(id: 'morning-water', title: 'Morning water'));
    await SqfliteEventRepository(db).append(_event('e1'));

    await SqfliteRoutineRepository(db).delete('morning-water');

    expect(await SqfliteRoutineRepository(db).list(), isEmpty);
    final events = await SqfliteEventRepository(db)
        .occurredSince(DateTime.utc(2026, 10, 28));
    expect(events.map((e) => e.id), ['e1']);
    await db.close();
  });

  test('ignores adding a routine with an existing id', () async {
    final db = await openAppDatabase(path: inMemoryDatabasePath);
    final repository = SqfliteRoutineRepository(db);

    await repository.add(const Routine(id: 'r1', title: 'Stretch'));
    await repository.add(const Routine(id: 'r1', title: 'Other'));

    final routines = await repository.list();
    expect(routines, hasLength(1));
    expect(routines.single.title, 'Stretch');
    await db.close();
  });

  test('upgrading from version 1 adds an empty routines table', () async {
    final path = '${dir.path}/v1.db';
    final old = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(_eventsTable),
    );
    await SqfliteEventRepository(old).append(_event('e1'));
    await old.close();

    final upgraded = await openAppDatabase(path: path);

    expect(await SqfliteRoutineRepository(upgraded).list(), isEmpty);
    final events = await SqfliteEventRepository(upgraded)
        .occurredSince(DateTime.utc(2026, 10, 28));
    expect(events.map((e) => e.id), ['e1']);
    await upgraded.close();
  });

  test(
    'upgrading from version 2 drops deleted routines and keeps the rest',
    () async {
      final path = '${dir.path}/v2.db';
      final old = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute(_eventsTable);
          await db.execute('''
          CREATE TABLE routines (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            icon_key TEXT NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
          await db.insert('routines', {
            'id': 'a',
            'title': 'First',
            'icon_key': 'water',
          });
          await db.insert('routines', {
            'id': 'b',
            'title': 'Hidden',
            'icon_key': 'task',
            'archived': 1,
          });
          await db.insert('routines', {
            'id': 'c',
            'title': 'Third',
            'icon_key': 'walk',
          });
        },
      );
      await old.close();

      final upgraded = await openAppDatabase(path: path);

      final routines = await SqfliteRoutineRepository(upgraded).list();
      expect(routines.map((r) => r.id), ['a', 'c']);
      expect(routines.first.iconKey, 'water');
      await upgraded.close();
    },
  );
}
