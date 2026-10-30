import 'package:daily_anchor/app.dart';
import 'package:daily_anchor/core/clock.dart';
import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:daily_anchor/core/sync/api_config.dart';
import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_provider.dart';
import 'package:daily_anchor/features/today/routines_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/events.dart';
import 'support/in_memory_event_repository.dart';
import 'support/in_memory_routine_repository.dart';

/// Pumps the real app in the standard or the high-contrast theme.
Future<void> _pumpApp(
  WidgetTester tester, {
  required bool highContrast,
  bool welcomeSeen = true,
  bool withRoutines = true,
  bool showSplash = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final events = InMemoryEventRepository()
    ..events.add(routineEvent(at: DateTime(2026, 10, 28, 8)));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(highContrast: highContrast, welcomeSeen: welcomeSeen),
        ),
        eventRepositoryProvider.overrideWithValue(events),
        routineRepositoryProvider.overrideWithValue(
          InMemoryRoutineRepository(
            routines: withRoutines ? starterRoutines : [],
          ),
        ),
        apiBaseUrlProvider.overrideWithValue(''),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 28, 12)),
      ],
      child: DailyAnchorApp(showSplash: showSplash),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tap targets large enough on both platforms, every tappable thing labelled,
/// and text with enough contrast.
Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the checks themselves', () {
    testWidgets('catch faint text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Faint text',
                style: TextStyle(color: Color(0xFFDDDDDD)),
              ),
            ),
          ),
        ),
      );

      await expectLater(tester, doesNotMeetGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('catch a tap target that is too small', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: GestureDetector(
                  onTap: () {},
                  child: Semantics(
                    label: 'Tiny',
                    button: true,
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        tester,
        doesNotMeetGuideline(androidTapTargetGuideline),
      );
      handle.dispose();
    });

    testWidgets('catch a tappable thing with no label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: GestureDetector(
                  onTap: () {},
                  child: Semantics(
                    button: true,
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        tester,
        doesNotMeetGuideline(labeledTapTargetGuideline),
      );
      handle.dispose();
    });
  });

  for (final highContrast in [false, true]) {
    final theme = highContrast ? 'high contrast' : 'standard';

    group('accessibility guidelines, $theme theme', () {
      testWidgets('splash screen', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast, showSplash: true);
        await tester.pump();

        await _meetsGuidelines(tester);
        // Let the splash finish so no timer is left behind.
        await tester.pump(const Duration(seconds: 2));
        handle.dispose();
      });

      testWidgets('first-run popup', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast, welcomeSeen: false);

        expect(find.text('Before you start'), findsOneWidget);
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('welcome cards', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast, welcomeSeen: false);
        await tester.tap(find.text('I understand'));
        await tester.pumpAndSettle();

        await _meetsGuidelines(tester);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Today with routines', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);

        await _meetsGuidelines(tester);
        await _scrollTo(tester, find.text('Write an idea'));
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Today with no routines', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast, withRoutines: false);

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Add routine form', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _scrollTo(tester, find.text('Add a routine'));
        await tester.tap(find.text('Add a routine'));
        await tester.pumpAndSettle();

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('routine menu and delete dialog', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _tapTooltip(tester, 'More options for Morning water');
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Progress', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _tapTooltip(tester, 'Progress');

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Settings', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _tapTooltip(tester, 'Settings');

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('Share your ideas', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _scrollTo(tester, find.text('Write an idea'));
        await tester.tap(find.text('Write an idea'));
        await tester.pumpAndSettle();

        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('word exercise, every step', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, highContrast: highContrast);
        await _scrollTo(tester, find.text('Start exercise'));
        await tester.tap(find.text('Start exercise'));
        await tester.pumpAndSettle();

        await _meetsGuidelines(tester);
        await tester.tap(find.text('Start'));
        await tester.pump();
        await _meetsGuidelines(tester);

        await tester.pump(const Duration(seconds: 15));
        await tester.pump();
        await _meetsGuidelines(tester);
        handle.dispose();
      });
    });
  }
}
