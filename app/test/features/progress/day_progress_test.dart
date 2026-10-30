import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/features/progress/day_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/events.dart';

// Local times, so the tests do not depend on the machine's time zone.
final _now = DateTime(2026, 10, 28, 12);

AppEvent _done(String routine, DateTime at) =>
    routineEvent(routineId: routine, at: at);
AppEvent _undone(String routine, DateTime at) =>
    routineEvent(routineId: routine, type: EventType.routineUndone, at: at);

void main() {
  group('buildLocalProgress', () {
    test('returns one entry per day, oldest first, with zeros when empty', () {
      final days = buildLocalProgress([], _now, 7);

      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 10, 22));
      expect(days.last.date, DateTime(2026, 10, 28));
      expect(days.every((d) => !d.active && d.recallAttempts == 0), isTrue);
    });

    test('counts each routine done once a day', () {
      final days = buildLocalProgress(
        [
          _done('a', DateTime(2026, 10, 28, 8)),
          _done('a', DateTime(2026, 10, 28, 9)),
          _done('b', DateTime(2026, 10, 28, 10)),
        ],
        _now,
        7,
      );

      expect(days.last.routinesCompleted, 2);
      expect(days.last.active, isTrue);
    });

    test('an undo means not done, and a later completion means done again', () {
      final undone = buildLocalProgress(
        [
          _done('a', DateTime(2026, 10, 28, 8)),
          _undone('a', DateTime(2026, 10, 28, 8, 5)),
        ],
        _now,
        7,
      );
      final redone = buildLocalProgress(
        [
          _done('a', DateTime(2026, 10, 28, 8)),
          _undone('a', DateTime(2026, 10, 28, 8, 5)),
          _done('a', DateTime(2026, 10, 28, 8, 10)),
        ],
        _now,
        7,
      );

      expect(undone.last.routinesCompleted, 0);
      expect(undone.last.active, isFalse);
      expect(redone.last.routinesCompleted, 1);
    });

    test('does not depend on the order events are given in', () {
      final days = buildLocalProgress(
        [
          _undone('a', DateTime(2026, 10, 28, 8, 5)),
          _done('a', DateTime(2026, 10, 28, 8)),
        ],
        _now,
        7,
      );

      expect(days.last.routinesCompleted, 0);
    });

    test('keeps days separate and ignores events outside the range', () {
      final days = buildLocalProgress(
        [
          _done('a', DateTime(2026, 10, 27, 20)),
          _done('b', DateTime(2026, 10, 28, 8)),
          _done('c', DateTime(2026, 10, 1, 8)),
          _done('d', DateTime(2026, 10, 29, 8)),
        ],
        _now,
        7,
      );

      expect(days[days.length - 2].routinesCompleted, 1);
      expect(days.last.routinesCompleted, 1);
      expect(days.fold<int>(0, (sum, d) => sum + d.routinesCompleted), 2);
    });

    test('counts word exercises and ignores ideas', () {
      final days = buildLocalProgress(
        [
          recallEvent(at: DateTime(2026, 10, 28, 9)),
          recallEvent(at: DateTime(2026, 10, 28, 10)),
          AppEvent(
            id: 'idea',
            type: EventType.feedbackSubmitted,
            payload: {'message': 'hello'},
            occurredAt: DateTime(2026, 10, 28, 11),
          ),
        ],
        _now,
        7,
      );

      expect(days.last.recallAttempts, 2);
      expect(days.last.routinesCompleted, 0);
    });

    test('works for a single day', () {
      final days = buildLocalProgress(
        [_done('a', DateTime(2026, 10, 28, 8))],
        _now,
        1,
      );

      expect(days, hasLength(1));
      expect(days.single.routinesCompleted, 1);
    });

    test('crosses a month boundary', () {
      final days = buildLocalProgress([], DateTime(2026, 11, 2, 12), 5);

      expect(days.map((d) => d.date), [
        DateTime(2026, 10, 29),
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ]);
    });
  });

  group('dayLabel', () {
    test('says Today and Yesterday', () {
      expect(dayLabel(DateTime(2026, 10, 28), _now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 27), _now), 'Yesterday');
    });

    test('otherwise gives a short date', () {
      expect(dayLabel(DateTime(2026, 10, 26), _now), 'Mon 26 Oct');
      expect(dayLabel(DateTime(2026, 10, 24), _now), 'Sat 24 Oct');
    });
  });
}
