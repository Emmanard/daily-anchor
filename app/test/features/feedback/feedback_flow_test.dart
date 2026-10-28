import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

Widget _app(InMemoryEventRepository events, {double textScale = 1.0}) =>
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(textScale: textScale, welcomeSeen: true),
        ),
        eventRepositoryProvider.overrideWithValue(events),
        routineRepositoryProvider.overrideWithValue(
          InMemoryRoutineRepository(),
        ),
      ],
      child: const DailyAnchorApp(),
    );

Future<void> _openFeedback(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Write an idea'), 200);
  await tester.ensureVisible(find.text('Write an idea'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Write an idea'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sending an idea saves it as an event and thanks the user', (
    tester,
  ) async {
    final events = InMemoryEventRepository();
    await tester.pumpWidget(_app(events));
    await _openFeedback(tester);

    await tester.enterText(find.byType(TextField), '  Bigger buttons please ');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Thank you. Your idea was saved.'), findsOneWidget);
    expect(find.text('Share your ideas'), findsNWidgets(1));
    final saved = events.events.single;
    expect(saved.type, EventType.feedbackSubmitted);
    expect(saved.payload, {'message': 'Bigger buttons please'});
  });

  testWidgets('an empty idea is rejected', (tester) async {
    final events = InMemoryEventRepository();
    await tester.pumpWidget(_app(events));
    await _openFeedback(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Please write a few words first.'), findsOneWidget);
    expect(events.events, isEmpty);
  });

  testWidgets('a failed save keeps the form open with a message', (
    tester,
  ) async {
    final events = InMemoryEventRepository(failAppend: true);
    await tester.pumpWidget(_app(events));
    await _openFeedback(tester);

    await tester.enterText(find.byType(TextField), 'More word lists');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('That did not save. Please try again.'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(events.events, isEmpty);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemoryEventRepository(), textScale: 2.0));
    await _openFeedback(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Your idea'), findsOneWidget);
  });
}
