import '../../core/events/app_event.dart';

/// Routine ids whose most recent event is a completion. Expects [events] in
/// chronological order.
Set<String> completedRoutineIds(Iterable<AppEvent> events) {
  final completed = <String>{};
  for (final event in events) {
    final routineId = event.payload['routineId'];
    if (routineId is! String) continue;
    switch (event.type) {
      case EventType.routineCompleted:
        completed.add(routineId);
      case EventType.routineUndone:
        completed.remove(routineId);
      case EventType.recallCompleted:
      case EventType.feedbackSubmitted:
        break;
    }
  }
  return completed;
}
