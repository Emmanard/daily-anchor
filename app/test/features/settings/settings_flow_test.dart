import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/settings/settings_repository.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app(AppSettings initial) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(initial),
    eventRepositoryProvider.overrideWithValue(InMemoryEventRepository()),
    routineRepositoryProvider.overrideWithValue(InMemoryRoutineRepository()),
  ],
  child: const DailyAnchorApp(),
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('high contrast switch changes the theme and is persisted', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AppSettings(welcomeSeen: true)));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final before = Theme.of(tester.element(find.text('Settings').first));
    expect(before.colorScheme.brightness, Brightness.light);

    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();

    final after = Theme.of(tester.element(find.text('Settings').first));
    expect(after.colorScheme.brightness, Brightness.dark);
    expect((await SettingsRepository().load()).highContrast, isTrue);
  });

  testWidgets('Today screen has no overflow at 200% text on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const AppSettings(textScale: 2.0, welcomeSeen: true)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Morning water'), findsOneWidget);
  });

  testWidgets('Today screen meets the tap target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const AppSettings(welcomeSeen: true)));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
