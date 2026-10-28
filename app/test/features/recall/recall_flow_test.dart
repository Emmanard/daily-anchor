import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/core/clock.dart';
import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/features/recall/word_bank.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:daily_anchor/features/today/today_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_event_repository.dart';
import '../../support/in_memory_routine_repository.dart';

class _Harness {
  _Harness({bool failAppend = false})
    : repository = InMemoryEventRepository(failAppend: failAppend);

  final InMemoryEventRepository repository;
  DateTime now = DateTime(2026, 10, 28, 9);

  Widget app() => ProviderScope(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        const AppSettings(welcomeSeen: true),
      ),
      eventRepositoryProvider.overrideWithValue(repository),
      routineRepositoryProvider.overrideWithValue(InMemoryRoutineRepository()),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const DailyAnchorApp(),
  );
}

/// Words from the bank that are currently on screen.
List<String> _wordsOnScreen() =>
    recallWords.where((w) => find.text(w).evaluate().isNotEmpty).toList();

Future<void> _openExerciseAndStart(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Start exercise'), 200);
  await tester.ensureVisible(find.text('Start exercise'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start exercise'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start'));
  await tester.pump();
}

void main() {
  // Flow tests use a tall surface so all ten choices are on screen at once.
  testWidgets('full flow: memorize, choose, result, and the event is saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await _openExerciseAndStart(tester);

    final targets = _wordsOnScreen();
    expect(targets, hasLength(5));
    expect(find.text('Time left: 15 seconds'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(find.text('Choose the 5 words you saw'), findsOneWidget);
    expect(_wordsOnScreen(), hasLength(10));

    for (final word in targets) {
      await tester.tap(find.text(word));
      await tester.pump();
    }
    expect(find.text('5 of 5 chosen'), findsOneWidget);

    harness.now = harness.now.add(const Duration(seconds: 12));
    await tester.tap(find.text('Check my answers'));
    await tester.pumpAndSettle();

    expect(find.text('You picked 5 of 5 words correctly.'), findsOneWidget);
    expect(find.text('It took you 12 seconds.'), findsOneWidget);

    final saved = harness.repository.events.single;
    expect(saved.type, EventType.recallCompleted);
    expect(saved.payload, {'correctCount': 5, 'durationMs': 12000});
  });

  testWidgets('wrong picks are scored and a sixth word cannot be chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await _openExerciseAndStart(tester);
    final targets = _wordsOnScreen();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    final others = _wordsOnScreen().where((w) => !targets.contains(w)).toList();
    final picks = [...targets.take(2), ...others.take(3)];
    for (final word in picks) {
      await tester.tap(find.text(word));
      await tester.pump();
    }

    // The button is the only thing that can submit, and a sixth tile is off.
    final extra = others.last;
    await tester.tap(find.text(extra));
    await tester.pump();
    expect(find.text('5 of 5 chosen'), findsOneWidget);

    await tester.tap(find.text('Check my answers'));
    await tester.pumpAndSettle();

    expect(find.text('You picked 2 of 5 words correctly.'), findsOneWidget);
    expect(harness.repository.events.single.payload['correctCount'], 2);
  });

  testWidgets('the result is still shown when saving fails', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = _Harness(failAppend: true);

    await tester.pumpWidget(harness.app());
    await _openExerciseAndStart(tester);
    final targets = _wordsOnScreen();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    for (final word in targets) {
      await tester.tap(find.text(word));
      await tester.pump();
    }
    await tester.tap(find.text('Check my answers'));
    await tester.pumpAndSettle();

    expect(find.text('You picked 5 of 5 words correctly.'), findsOneWidget);
    expect(
      find.text('This result could not be saved on this device.'),
      findsOneWidget,
    );
    expect(harness.repository.events, isEmpty);
  });

  testWidgets('leaving during the countdown cancels the timer cleanly', (
    tester,
  ) async {
    final harness = _Harness();

    await tester.pumpWidget(harness.app());
    await _openExerciseAndStart(tester);
    await tester.pump(const Duration(seconds: 3));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));

    expect(tester.takeException(), isNull);
    expect(find.text('Start exercise'), findsOneWidget);
  });

  testWidgets('is usable at 200% text with no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = _Harness();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(textScale: 2.0, welcomeSeen: true),
          ),
          eventRepositoryProvider.overrideWithValue(harness.repository),
          routineRepositoryProvider.overrideWithValue(
            InMemoryRoutineRepository(),
          ),
          clockProvider.overrideWithValue(() => harness.now),
        ],
        child: const DailyAnchorApp(),
      ),
    );
    await _openExerciseAndStart(tester);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Choose the 5 words you saw'), findsOneWidget);
  });
}
