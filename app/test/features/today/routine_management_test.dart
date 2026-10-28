import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app(InMemoryRoutineRepository routines) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(
      const AppSettings(welcomeSeen: true),
    ),
    eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
    routineRepositoryProvider.overrideWithValue(routines),
  ],
  child: const DailyAnchorApp(),
);

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('More options for $title'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adds a routine and shows it on the list', (tester) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Water the plants ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Water the plants'), findsOneWidget);
    expect(routines.routines.last.title, 'Water the plants');
    expect(routines.routines, hasLength(4));
  });

  testWidgets('an empty name is rejected and nothing is added', (tester) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a name.'), findsOneWidget);
    expect(routines.routines, hasLength(3));
  });

  testWidgets('a failed save keeps the form open with a message', (
    tester,
  ) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    routines.failWrite = true;
    await tester.tap(find.text('Add a routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Stretch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('That did not save. Please try again.'), findsOneWidget);
    expect(find.text('Add routine'), findsOneWidget);
    expect(routines.routines, hasLength(3));
  });

  testWidgets('edits a routine name', (tester) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Short walk');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Short walk'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Long walk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Long walk'), findsOneWidget);
    expect(find.text('Short walk'), findsNothing);
    expect(routines.routines[1].title, 'Long walk');
  });

  testWidgets('deleting asks first and then removes the routine', (
    tester,
  ) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Short walk');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Short walk"?'), findsOneWidget);
    expect(find.text('Your past completions are kept.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Short walk'), findsNothing);
    expect(routines.routines.map((r) => r.id), isNot(contains('short-walk')));
  });

  testWidgets('cancelling the delete keeps the routine', (tester) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository();
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Short walk');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Short walk'), findsOneWidget);
    expect(routines.routines, hasLength(3));
  });

  testWidgets('an empty list shows an invitation, ideas and no other cards', (
    tester,
  ) async {
    _useTallScreen(tester);
    await tester.pumpWidget(_app(InMemoryRoutineRepository(routines: [])));
    await tester.pumpAndSettle();

    expect(find.text('Add your first routine'), findsOneWidget);
    expect(find.text('Add a routine'), findsOneWidget);
    expect(find.text('Some ideas'), findsOneWidget);
    expect(find.text('Morning water'), findsOneWidget);
    expect(find.text('Short walk'), findsOneWidget);
    expect(find.text('Word recall'), findsNothing);
    expect(find.text('Share your ideas'), findsNothing);
  });

  testWidgets('choosing an idea fills in the form and keeps its icon', (
    tester,
  ) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository(routines: []);
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Short walk'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Short walk'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(routines.routines.single.title, 'Short walk');
    expect(routines.routines.single.iconKey, 'walk');
    expect(find.text('Add your first routine'), findsNothing);
    expect(find.text('Word recall'), findsOneWidget);
    expect(find.text('Share your ideas'), findsOneWidget);
  });

  testWidgets('deleting the last routine returns to the invitation', (
    tester,
  ) async {
    _useTallScreen(tester);
    final routines = InMemoryRoutineRepository(
      routines: [starterRoutines.first],
    );
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await _openMenu(tester, 'Morning water');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Add your first routine'), findsOneWidget);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(textScale: 2.0, welcomeSeen: true),
          ),
          eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
          routineRepositoryProvider.overrideWithValue(
            InMemoryRoutineRepository(),
          ),
        ],
        child: const DailyAnchorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('More options for Morning water'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Edit'), findsOneWidget);
  });
}
