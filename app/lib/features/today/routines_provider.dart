import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import 'routine.dart';
import 'routine_repository.dart';

/// Overridden in main() with the opened database.
final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => throw UnimplementedError('routineRepositoryProvider not overridden'),
);

class RoutinesNotifier extends AsyncNotifier<List<Routine>> {
  @override
  Future<List<Routine>> build() => ref.read(routineRepositoryProvider).list();

  // Each change returns false if it could not be stored, and then leaves the
  // visible list unchanged.

  Future<bool> add(
    String title, {
    String iconKey = Routine.defaultIconKey,
  }) async {
    final current = state.value;
    if (current == null) return false;
    final routine = Routine(
      id: newUuid(),
      title: title.trim(),
      iconKey: iconKey,
    );
    try {
      await ref.read(routineRepositoryProvider).add(routine);
    } catch (_) {
      return false;
    }
    state = AsyncData([...current, routine]);
    return true;
  }

  Future<bool> rename(String id, String title) async {
    final current = state.value;
    if (current == null) return false;
    final trimmed = title.trim();
    try {
      await ref.read(routineRepositoryProvider).rename(id, trimmed);
    } catch (_) {
      return false;
    }
    state = AsyncData([
      for (final routine in current)
        if (routine.id == id)
          Routine(id: id, title: trimmed, iconKey: routine.iconKey)
        else
          routine,
    ]);
    return true;
  }

  Future<bool> remove(String id) async {
    final current = state.value;
    if (current == null) return false;
    try {
      await ref.read(routineRepositoryProvider).delete(id);
    } catch (_) {
      return false;
    }
    state = AsyncData([
      for (final routine in current)
        if (routine.id != id) routine,
    ]);
    return true;
  }
}

final routinesProvider = AsyncNotifierProvider<RoutinesNotifier, List<Routine>>(
  RoutinesNotifier.new,
);
