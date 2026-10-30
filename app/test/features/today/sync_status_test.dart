import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:daily_anchor/core/sync/api_config.dart';
import 'package:daily_anchor/core/sync/device_id.dart';
import 'package:daily_anchor/core/sync/events_api.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_events_api.dart';
import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app({
  required InMemoryEventRepository events,
  required FakeEventsApi api,
  String baseUrl = 'http://api.test',
}) => ProviderScope(
  overrides: [
    initialSettingsProvider.overrideWithValue(
      const AppSettings(welcomeSeen: true),
    ),
    eventRepositoryProvider.overrideWithValue(events),
    routineRepositoryProvider.overrideWithValue(InMemoryRoutineRepository()),
    apiBaseUrlProvider.overrideWithValue(baseUrl),
    eventsApiProvider.overrideWithValue(api),
    deviceIdProvider.overrideWith((ref) async => 'device-1'),
  ],
  child: const DailyAnchorApp(),
);

Future<void> _completeMorningWater(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Mark Morning water as done'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says everything is saved when nothing is waiting', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(events: InMemoryEventRepository(), api: FakeEventsApi()),
    );
    await tester.pumpAndSettle();

    expect(find.text('All saved'), findsOneWidget);
  });

  testWidgets('says sync is off when no server is configured', (tester) async {
    await tester.pumpWidget(
      _app(
        events: InMemoryEventRepository(),
        api: FakeEventsApi(),
        baseUrl: '',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved on this phone. Sync is off.'), findsOneWidget);
  });

  testWidgets('an action taken online is uploaded straight away', (
    tester,
  ) async {
    final events = InMemoryEventRepository();
    final api = FakeEventsApi();
    await tester.pumpWidget(_app(events: events, api: api));
    await tester.pumpAndSettle();

    await _completeMorningWater(tester);

    expect(find.text('All saved'), findsOneWidget);
    expect(api.stored, hasLength(1));
    expect(await events.unsyncedCount(), 0);
  });

  testWidgets('offline actions wait, and upload once when back online', (
    tester,
  ) async {
    final events = InMemoryEventRepository();
    final api = FakeEventsApi()..fail = true;
    await tester.pumpWidget(_app(events: events, api: api));
    await tester.pumpAndSettle();

    await _completeMorningWater(tester);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting to sync (2 items)'), findsOneWidget);
    expect(api.stored, isEmpty);

    api.fail = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('All saved'), findsOneWidget);
    expect(api.stored, hasLength(2));
    expect(await events.unsyncedCount(), 0);
  });

  testWidgets('says one item in the singular', (tester) async {
    final api = FakeEventsApi()..fail = true;
    await tester.pumpWidget(_app(events: InMemoryEventRepository(), api: api));
    await tester.pumpAndSettle();

    await _completeMorningWater(tester);

    expect(find.text('Waiting to sync (1 item)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('uploads again when the app comes back to the foreground', (
    tester,
  ) async {
    final events = InMemoryEventRepository();
    final api = FakeEventsApi()..fail = true;
    await tester.pumpWidget(_app(events: events, api: api));
    await tester.pumpAndSettle();
    await _completeMorningWater(tester);
    expect(find.text('Waiting to sync (1 item)'), findsOneWidget);

    api.fail = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('All saved'), findsOneWidget);
    expect(api.stored, hasLength(1));
  });

  testWidgets('the Progress button opens the Progress screen', (tester) async {
    await tester.pumpWidget(
      _app(
        events: InMemoryEventRepository(),
        api: FakeEventsApi(),
        baseUrl: '',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Progress'));
    await tester.pumpAndSettle();

    expect(find.text('Active on 0 of the last 7 days'), findsOneWidget);
  });
}
