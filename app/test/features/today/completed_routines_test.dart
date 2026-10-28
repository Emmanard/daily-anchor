import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/features/today/completed_routines.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _event(EventType type, String routineId) => AppEvent(
  id: '$type-$routineId-${DateTime.now().microsecondsSinceEpoch}',
  type: type,
  payload: {'routineId': routineId},
  occurredAt: DateTime.utc(2026, 10, 28),
);

void main() {
  test('a completion marks the routine done', () {
    final done = completedRoutineIds([_event(EventType.routineCompleted, 'a')]);

    expect(done, {'a'});
  });

  test('an undo after a completion clears it', () {
    final done = completedRoutineIds([
      _event(EventType.routineCompleted, 'a'),
      _event(EventType.routineUndone, 'a'),
    ]);

    expect(done, isEmpty);
  });

  test('completing again after an undo marks it done', () {
    final done = completedRoutineIds([
      _event(EventType.routineCompleted, 'a'),
      _event(EventType.routineUndone, 'a'),
      _event(EventType.routineCompleted, 'a'),
    ]);

    expect(done, {'a'});
  });

  test('routines are tracked independently and other events are ignored', () {
    final done = completedRoutineIds([
      _event(EventType.routineCompleted, 'a'),
      _event(EventType.routineCompleted, 'b'),
      _event(EventType.routineUndone, 'b'),
      AppEvent(
        id: 'recall-1',
        type: EventType.recallCompleted,
        payload: {'correctCount': 4, 'durationMs': 9000},
        occurredAt: DateTime.utc(2026, 10, 28),
      ),
    ]);

    expect(done, {'a'});
  });
}
