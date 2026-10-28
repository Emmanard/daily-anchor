import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/events/app_event.dart';
import '../../core/events/event_repository.dart';
import '../../core/ids.dart';
import 'completed_routines.dart';

/// Overridden in main() with the opened database.
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => throw UnimplementedError('eventRepositoryProvider not overridden'),
);

class TodayNotifier extends AsyncNotifier<Set<String>> {
  final _inFlight = <String>{};

  @override
  Future<Set<String>> build() async {
    final now = ref.read(clockProvider)();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final events = await ref
        .read(eventRepositoryProvider)
        .occurredSince(startOfDay);
    return completedRoutineIds(events);
  }

  /// Completes the routine, or undoes it if it is already done. Returns false
  /// if the event could not be stored; the visible state is then unchanged.
  Future<bool> toggle(String routineId) async {
    final current = state.value;
    // A second tap while the first is still being stored is ignored.
    if (current == null || !_inFlight.add(routineId)) return false;

    try {
      final wasDone = current.contains(routineId);
      await ref
          .read(eventRepositoryProvider)
          .append(
            AppEvent(
              id: newUuid(),
              type: wasDone
                  ? EventType.routineUndone
                  : EventType.routineCompleted,
              payload: {'routineId': routineId},
              occurredAt: ref.read(clockProvider)().toUtc(),
            ),
          );
      state = AsyncData(
        wasDone
            ? (Set.of(current)..remove(routineId))
            : {...current, routineId},
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _inFlight.remove(routineId);
    }
  }
}

final todayProvider = AsyncNotifierProvider<TodayNotifier, Set<String>>(
  TodayNotifier.new,
);
