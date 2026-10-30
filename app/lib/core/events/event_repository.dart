import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_event.dart';

abstract class EventRepository {
  /// Stores the event. An event whose id already exists is ignored.
  Future<void> append(AppEvent event);

  /// Events that occurred at or after [since], oldest first.
  Future<List<AppEvent>> occurredSince(DateTime since);

  /// Events not yet uploaded, oldest first.
  Future<List<AppEvent>> unsynced({int limit = 100});

  Future<int> unsyncedCount();

  /// Marks events as uploaded. Unknown ids are ignored.
  Future<void> markSynced(Iterable<String> ids);
}

/// Overridden in main() with the opened database.
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => throw UnimplementedError('eventRepositoryProvider not overridden'),
);
