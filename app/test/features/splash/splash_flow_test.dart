import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app() => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(
      const AppSettings(welcomeSeen: true),
    ),
    eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
    routineRepositoryProvider.overrideWithValue(InMemoryRoutineRepository()),
  ],
  child: const DailyAnchorApp(showSplash: true),
);

void main() {
  testWidgets('shows the splash and then the app after 1.5 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Daily Anchor'), findsOneWidget);
    expect(find.text('Today'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('Today'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('tapping the splash skips it', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Daily Anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('leaving before it ends cancels the timer cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
  });
}
