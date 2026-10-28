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
