import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/settings/settings_repository.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app({AppSettings settings = const AppSettings()}) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(settings),
    eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
    routineRepositoryProvider.overrideWithValue(
      InMemoryRoutineRepository(routines: []),
    ),
  ],
  child: const DailyAnchorApp(),
);

Future<void> _acceptDisclaimer(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('I understand'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('first launch asks the user to accept before starting', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Before you start'), findsOneWidget);
    expect(find.textContaining('not a medical product'), findsOneWidget);
    expect(find.text('I understand'), findsOneWidget);

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    expect(find.text('Before you start'), findsNothing);
    expect(find.text('Welcome to Daily Anchor'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('the cards can be stepped through with Next and Back', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _acceptDisclaimer(tester);

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Your routines, your way'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A short word exercise'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Works without internet'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('Get started saves the welcome and shows the empty Today', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _acceptDisclaimer(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Daily Anchor'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Add your first routine'), findsOneWidget);
    expect((await SettingsRepository().load()).welcomeSeen, isTrue);
  });

  testWidgets('Skip goes straight to the empty Today', (tester) async {
    await tester.pumpWidget(_app());
    await _acceptDisclaimer(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Add your first routine'), findsOneWidget);
    expect((await SettingsRepository().load()).welcomeSeen, isTrue);
  });

  testWidgets('works with reduce motion on', (tester) async {
    await tester.pumpWidget(
      _app(settings: const AppSettings(reduceMotion: true)),
    );
    await _acceptDisclaimer(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 4'), findsOneWidget);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(settings: const AppSettings(textScale: 2.0)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Get started'), findsOneWidget);
  });
}
