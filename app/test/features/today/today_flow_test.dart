import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app(
  InMemoryEventRepository repository, {
  InMemoryRoutineRepository? routines,
}) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(
      const AppSettings(welcomeSeen: true),
    ),
    eventRepositoryProvider.overrideWithValue(repository),
    routineRepositoryProvider.overrideWithValue(
      routines ?? InMemoryRoutineRepository(),
    ),
  ],
  child: const DailyAnchorApp(),
);

void main() {
  testWidgets('completing then undoing a routine writes both events', (
    tester,
  ) async {
    final repository = InMemoryEventRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Not done yet'), findsNWidgets(3));

    await tester.tap(find.bySemanticsLabel('Mark Morning water as done'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(repository.events.single.type, EventType.routineCompleted);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
    expect(find.text('Not done yet'), findsNWidgets(3));
    expect(repository.events.map((e) => e.type), [
      EventType.routineCompleted,
      EventType.routineUndone,
    ]);
    expect(repository.events.map((e) => e.id).toSet(), hasLength(2));
  });

  testWidgets('restores completed routines from stored events', (tester) async {
    final repository = InMemoryEventRepository();
    repository.events.add(
      AppEvent(
        id: 'e1',
        type: EventType.routineCompleted,
        payload: {'routineId': 'short-walk'},
        occurredAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Not done yet'), findsNWidgets(2));
  });

  testWidgets('shows a retry when loading fails and recovers', (tester) async {
    final repository = InMemoryEventRepository(failLoad: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Your routines could not be loaded.'), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Morning water'), findsOneWidget);
  });

  testWidgets('a failed save leaves the card unchanged and says so', (
    tester,
  ) async {
    final repository = InMemoryEventRepository(failAppend: true);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Mark Morning water as done'));
    await tester.pumpAndSettle();

    expect(find.text('That did not save. Please try again.'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(repository.events, isEmpty);
  });
}
