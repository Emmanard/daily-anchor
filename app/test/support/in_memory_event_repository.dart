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
}
