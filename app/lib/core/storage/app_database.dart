import 'package:sqflite/sqflite.dart';

/// Opens the local database. [path] is only set by tests.
Future<Database> openAppDatabase({String? path}) async {
  final resolvedPath = path ?? '${await getDatabasesPath()}/daily_anchor.db';
  return openDatabase(
    resolvedPath,
    version: 3,
    onCreate: (db, version) async {
      await _createEvents(db);
      await _createRoutines(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await _createRoutines(db);
      } else if (oldVersion == 2) {
        await _removeArchivedRoutines(db);
      }
    },
  );
}

Future<void> _createEvents(Database db) async {
  // occurred_at is epoch milliseconds (UTC); sqflite has no date type.
  await db.execute('''
    CREATE TABLE events (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      payload TEXT NOT NULL,
      occurred_at INTEGER NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('CREATE INDEX events_occurred_at ON events(occurred_at)');
}

Future<void> _createRoutines(Database db) async {
  await db.execute('''
    CREATE TABLE routines (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      icon_key TEXT NOT NULL
    )
  ''');
}

/// Version 2 hid deleted routines with an "archived" flag. Deleting now removes
/// the row, so flagged rows are dropped and the column is left behind. SQLite
/// older than 3.35 cannot drop a column, hence the table is rebuilt.
Future<void> _removeArchivedRoutines(Database db) async {
  await db.execute('ALTER TABLE routines RENAME TO routines_v2');
  await _createRoutines(db);
  await db.execute('''
    INSERT INTO routines (id, title, icon_key)
    SELECT id, title, icon_key FROM routines_v2
    WHERE archived = 0
    ORDER BY rowid
  ''');
  await db.execute('DROP TABLE routines_v2');
}
