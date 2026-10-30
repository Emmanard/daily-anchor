import 'package:daily_anchor/core/events/app_event.dart';

int _counter = 0;

AppEvent routineEvent({
  String routineId = 'morning-water',
  EventType type = EventType.routineCompleted,
  DateTime? at,
  bool synced = false,
}) {
  _counter += 1;
  return AppEvent(
    id: 'event-$_counter',
    type: type,
    payload: {'routineId': routineId},
    occurredAt: at ?? DateTime.utc(2026, 10, 28, 9),
    synced: synced,
  );
}

AppEvent recallEvent({DateTime? at}) {
  _counter += 1;
  return AppEvent(
    id: 'event-$_counter',
    type: EventType.recallCompleted,
    payload: {'correctCount': 4, 'durationMs': 9000},
    occurredAt: at ?? DateTime.utc(2026, 10, 28, 9),
  );
}
