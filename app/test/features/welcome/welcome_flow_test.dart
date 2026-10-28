import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/settings/settings_repository.dart';
import 'package:daily_anchor/features/today/routine.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app(InMemoryRoutineRepository routines, {double textScale = 1.0}) =>
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(textScale: textScale),
        ),
        eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
        routineRepositoryProvider.overrideWithValue(routines),
      ],
      child: const DailyAnchorApp(),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('first launch shows the welcome screen with the disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(_app(InMemoryRoutineRepository(routines: [])));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Daily Anchor'), findsOneWidget);
    expect(find.textContaining('not a medical product'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('chosen suggestions become routines and the welcome is saved', (
    tester,
  ) async {
    final routines = InMemoryRoutineRepository(routines: []);
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning water'));
    await tester.tap(find.text('Call someone'));
    await tester.pump();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Daily Anchor'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Morning water'), findsOneWidget);
    expect(find.text('Call someone'), findsOneWidget);
    expect(find.text('Short walk'), findsNothing);
    expect(routines.routines.map((r) => r.title), [
      'Morning water',
      'Call someone',
    ]);
    expect(routines.routines.first.iconKey, 'water');
    expect((await SettingsRepository().load()).welcomeSeen, isTrue);
  });

  testWidgets('starting with nothing chosen leads to an empty Today', (
    tester,
  ) async {
    final routines = InMemoryRoutineRepository(routines: []);
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(
      find.text('No routines yet. Add your first one below.'),
      findsOneWidget,
    );
    expect(routines.routines, isEmpty);
  });

  testWidgets('a failed save stays on the welcome screen with a message', (
    tester,
  ) async {
    final routines = InMemoryRoutineRepository(routines: [])..failWrite = true;
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning water'));
    await tester.pump();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('That did not save. Please try again.'), findsOneWidget);
    expect(find.text('Welcome to Daily Anchor'), findsOneWidget);
    expect((await SettingsRepository().load()).welcomeSeen, isFalse);
  });

  testWidgets('routines that already exist are not offered again', (
    tester,
  ) async {
    final routines = InMemoryRoutineRepository(
      routines: [const Routine(id: 'x', title: 'Morning water')],
    );
    await tester.pumpWidget(_app(routines));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(CheckboxListTile, 'Morning water'),
      findsNothing,
    );
    expect(find.text('Short walk'), findsOneWidget);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(InMemoryRoutineRepository(routines: []), textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome to Daily Anchor'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Get started'), 200);
    expect(tester.takeException(), isNull);
  });
}
