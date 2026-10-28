import 'app_event.dart';

abstract class EventRepository {
  /// Stores the event. An event whose id already exists is ignored.
  Future<void> append(AppEvent event);

  /// Events that occurred at or after [since], oldest first.
  Future<List<AppEvent>> occurredSince(DateTime since);
}
