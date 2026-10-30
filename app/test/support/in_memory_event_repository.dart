import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/events/event_repository.dart';

class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository({this.failLoad = false, this.failAppend = false});

  final List<AppEvent> events = [];
  bool failLoad;
  bool failAppend;

  @override
  Future<void> append(AppEvent event) async {
    if (failAppend) throw StateError('append failed');
    if (events.any((e) => e.id == event.id)) return;
    events.add(event);
  }

  @override
  Future<List<AppEvent>> occurredSince(DateTime since) async {
    if (failLoad) throw StateError('load failed');
    return events.where((e) => !e.occurredAt.isBefore(since)).toList();
  }

  @override
  Future<List<AppEvent>> unsynced({int limit = 100}) async {
    final waiting = events.where((e) => !e.synced).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return waiting.take(limit).toList();
  }

  @override
  Future<int> unsyncedCount() async => events.where((e) => !e.synced).length;

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    final wanted = ids.toSet();
    for (var i = 0; i < events.length; i++) {
      if (wanted.contains(events[i].id)) events[i] = events[i].asSynced();
    }
  }
}
