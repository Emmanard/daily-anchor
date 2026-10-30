import 'package:daily_anchor/core/clock.dart';
import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:daily_anchor/core/sync/api_config.dart';
import 'package:daily_anchor/core/sync/device_id.dart';
import 'package:daily_anchor/core/sync/events_api.dart';
import 'package:daily_anchor/core/theme.dart';
import 'package:daily_anchor/features/progress/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/events.dart';
import '../../support/fake_events_api.dart';
import '../../support/in_memory_event_repository.dart';

final _now = DateTime(2026, 10, 28, 12);

Widget _app({
  String baseUrl = '',
  InMemoryEventRepository? events,
  FakeEventsApi? api,
  double textScale = 1.0,
}) => ProviderScope(
  overrides: [
    apiBaseUrlProvider.overrideWithValue(baseUrl),
    eventRepositoryProvider.overrideWithValue(
      events ?? InMemoryEventRepository(),
    ),
    eventsApiProvider.overrideWithValue(api ?? FakeEventsApi()),
    deviceIdProvider.overrideWith((ref) async => 'device-1'),
    clockProvider.overrideWithValue(() => _now),
  ],
  child: MaterialApp(
    theme: buildTheme(highContrast: false),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const ProgressScreen(),
  ),
);

void main() {
  testWidgets('shows a loading message while the week is being read', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your week'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('without a server it shows this phone and says so', (
    tester,
  ) async {
    final events = InMemoryEventRepository()
      ..events.addAll([
        routineEvent(routineId: 'a', at: DateTime(2026, 10, 28, 8)),
        routineEvent(routineId: 'b', at: DateTime(2026, 10, 27, 8)),
        recallEvent(at: DateTime(2026, 10, 28, 9)),
      ]);
    await tester.pumpWidget(_app(events: events));
    await tester.pumpAndSettle();

    expect(find.text('Active on 2 of the last 7 days'), findsOneWidget);
    expect(
      find.textContaining('Showing what is saved on this phone'),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Word exercises: 1'), findsOneWidget);
    expect(find.text('Routines done: 1'), findsNWidgets(2));
  });

  testWidgets('shows a friendly message when nothing has happened yet', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Active on 0 of the last 7 days'), findsOneWidget);
    expect(
      find.textContaining('Nothing recorded yet this week'),
      findsOneWidget,
    );
    expect(find.textContaining('Routines done'), findsNothing);
  });

  testWidgets('with a server it uploads what is waiting and shows its totals', (
    tester,
  ) async {
    final events = InMemoryEventRepository()..events.add(routineEvent());
    final api = FakeEventsApi()
      ..progressDays = const [
        ServerDay(date: '2026-10-27', routinesCompleted: 3, recallAttempts: 0),
        ServerDay(date: '2026-10-28', routinesCompleted: 1, recallAttempts: 2),
      ];
    await tester.pumpWidget(
      _app(baseUrl: 'http://api.test', events: events, api: api),
    );
    await tester.pumpAndSettle();

    expect(find.text('Totals checked with the server.'), findsOneWidget);
    expect(find.text('Active on 2 of the last 2 days'), findsOneWidget);
    expect(find.text('Routines done: 3'), findsOneWidget);
    expect(find.text('Word exercises: 2'), findsOneWidget);
    expect(api.stored, hasLength(1));
  });

  testWidgets('falls back to this phone when the server cannot be reached', (
    tester,
  ) async {
    final events = InMemoryEventRepository()
      ..events.add(routineEvent(at: DateTime(2026, 10, 28, 8)));
    final api = FakeEventsApi()..fail = true;
    await tester.pumpWidget(
      _app(baseUrl: 'http://api.test', events: events, api: api),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Showing what is saved on this phone'),
      findsOneWidget,
    );
    expect(find.text('Active on 1 of the last 7 days'), findsOneWidget);
    expect(find.text('Your progress could not be loaded.'), findsNothing);

    // The retry timer would otherwise still be pending.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows an error with a retry when nothing can be read', (
    tester,
  ) async {
    final events = InMemoryEventRepository(failLoad: true);
    await tester.pumpWidget(_app(events: events));
    await tester.pumpAndSettle();

    expect(find.text('Your progress could not be loaded.'), findsOneWidget);

    events.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Active on 0 of the last 7 days'), findsOneWidget);
  });

  testWidgets('every day carries words as well as an icon', (tester) async {
    final events = InMemoryEventRepository()
      ..events.add(routineEvent(at: DateTime(2026, 10, 28, 8)));
    await tester.pumpWidget(_app(events: events));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // The other days show an empty marker and still say their numbers in text.
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
    expect(find.text('Routines done: 0'), findsWidgets);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final events = InMemoryEventRepository()
      ..events.add(routineEvent(at: DateTime(2026, 10, 28, 8)));

    await tester.pumpWidget(_app(events: events, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Active on 1 of the last 7 days'), findsOneWidget);

    // Scroll to the oldest day to make sure every row lays out.
    await tester.scrollUntilVisible(find.text('Thu 22 Oct'), 300);
    expect(tester.takeException(), isNull);
  });
}
