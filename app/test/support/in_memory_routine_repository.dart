import 'package:daily_anchor/features/today/routine.dart';
import 'package:daily_anchor/features/today/routine_repository.dart';

const starterRoutines = [
  Routine(id: 'morning-water', title: 'Morning water', iconKey: 'water'),
  Routine(id: 'short-walk', title: 'Short walk', iconKey: 'walk'),
  Routine(id: 'call-someone', title: 'Call someone', iconKey: 'call'),
];

class InMemoryRoutineRepository implements RoutineRepository {
  InMemoryRoutineRepository({
    List<Routine> routines = starterRoutines,
    this.failList = false,
    this.failWrite = false,
  }) : routines = List.of(routines);

  final List<Routine> routines;
  bool failList;
  bool failWrite;

  @override
  Future<List<Routine>> list() async {
    if (failList) throw StateError('list failed');
    return List.of(routines);
  }

  @override
  Future<void> add(Routine routine) async {
    if (failWrite) throw StateError('write failed');
    routines.add(routine);
  }

  @override
  Future<void> rename(String id, String title) async {
    if (failWrite) throw StateError('write failed');
    final index = routines.indexWhere((r) => r.id == id);
    routines[index] = Routine(
      id: id,
      title: title,
      iconKey: routines[index].iconKey,
    );
  }

  @override
  Future<void> delete(String id) async {
    if (failWrite) throw StateError('write failed');
    routines.removeWhere((r) => r.id == id);
  }
}
