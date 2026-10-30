import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'app_event.dart';
import 'event_repository.dart';

class SqfliteEventRepository implements EventRepository {
  SqfliteEventRepository(this._db);

  final Database _db;

  @override
  Future<void> append(AppEvent event) async {
    await _db.insert('events', {
      'id': event.id,
      'type': event.type.wireName,
      'payload': jsonEncode(event.payload),
      'occurred_at': event.occurredAt.millisecondsSinceEpoch,
      'synced': event.synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<AppEvent>> occurredSince(DateTime since) async {
    final rows = await _db.query(
      'events',
      where: 'occurred_at >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
      orderBy: 'occurred_at ASC, rowid ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<AppEvent>> unsynced({int limit = 100}) async {
    final rows = await _db.query(
      'events',
      where: 'synced = 0',
      orderBy: 'occurred_at ASC, rowid ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> unsyncedCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM events WHERE synced = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    // Chunked to stay well below SQLite's limit on bound variables.
    for (var start = 0; start < list.length; start += 500) {
      final chunk = list.sublist(start, (start + 500).clamp(0, list.length));
      await _db.update(
        'events',
        {'synced': 1},
        where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }
  }

  AppEvent _fromRow(Map<String, Object?> row) {
    return AppEvent(
      id: row['id']! as String,
      type: EventType.fromWireName(row['type']! as String),
      payload: Map<String, Object?>.from(
        jsonDecode(row['payload']! as String) as Map,
      ),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at']! as int,
        isUtc: true,
      ),
      synced: (row['synced']! as int) == 1,
    );
  }
}
