import 'package:sqflite/sqflite.dart';

import 'routine.dart';

abstract class RoutineRepository {
  /// Routines in the order they were added.
  Future<List<Routine>> list();

  Future<void> add(Routine routine);

  Future<void> rename(String id, String title);

  /// Removes the routine and its name. Completion events that refer to it hold
  /// only its id, so they are kept.
  Future<void> delete(String id);
}

class SqfliteRoutineRepository implements RoutineRepository {
  SqfliteRoutineRepository(this._db);

  final Database _db;

  @override
  Future<List<Routine>> list() async {
    final rows = await _db.query('routines', orderBy: 'rowid ASC');
    return [
      for (final row in rows)
        Routine(
          id: row['id']! as String,
          title: row['title']! as String,
          iconKey: row['icon_key']! as String,
        ),
    ];
  }

  @override
  Future<void> add(Routine routine) async {
    await _db.insert('routines', {
      'id': routine.id,
      'title': routine.title,
      'icon_key': routine.iconKey,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> rename(String id, String title) async {
    await _db.update(
      'routines',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }
}
