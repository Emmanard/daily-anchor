# Daily Anchor

A learning project built while moving from React Native to Flutter. Not a medical product.

Daily Anchor is a small routine and word-recall companion for adults over 50. The app keeps working with no network, and a Node.js API is being added to receive its events. It makes no diagnostic, therapeutic or health-improvement claims, uses no real personal data, and is not production work.

I built it on my own initiative while applying for the Flutter + Node.js role at memodio, to show how quickly I can move from React Native to Flutter. Nobody asked for it as an assessment. It does not copy any memodio feature, exercise, wording or branding.

## Status

| Part | State |
|---|---|
| Flutter app: splash, welcome cards, routines (add, edit, delete, complete, undo), word exercise, ideas form, settings | Built, tested on Android and iOS simulators |
| Accessibility: text size up to 200%, high-contrast theme, reduce-motion, tap-target checks | Built. Contrast checks and a screen-reader pass still to do |
| Node.js API (Express, TypeScript, Zod, Prisma, Postgres) | Next |
| Offline queue and idempotent sync, progress screen | Next, after the API |
| CI, release APK, demo recording | Planned |

## What it demonstrates

- A Flutter app designed for a 50+ audience: large tap targets, plain language, state shown with an icon and text rather than color alone, readable at 200% text size.
- Offline-first by design: every action is stored locally as an event in SQLite and nothing needs a connection.
- Accessibility basics checked in tests: text scale, tap-target guideline, no overflow, semantic labels on interactive controls.
- Tests across layers: pure Dart logic, a real SQLite database (including schema upgrades), and widget flows with error and empty states.
- A written decision log and the questions I would take to a medical and product team (below).

Planned, not yet built: a Node.js API with validation and idempotent event upload, and CI.

## Run it

Prerequisites: Flutter (stable, 3.47 at the time of writing), Android Studio for the Android emulator, Xcode for the iOS simulator.

```
cd app
flutter pub get
flutter run            # pick a connected emulator or simulator
```

Checks:

```
cd app
dart format .
flutter analyze
flutter test
```

Configuration planned for the API step, names only (no values are stored in the repository): `DATABASE_URL`, `PORT` for the API and `API_BASE_URL`, passed to the app with `--dart-define`.

## Architecture

```
app/lib
  main.dart, app.dart     start-up, theme and text scale, first-run switch
  core/                   theme, clock, ids, SQLite setup, event model and repository
  features/
    splash/               branded splash shown at launch
    welcome/              "Before you start" popup and four intro cards
    feedback/             "Share your ideas" form
    today/                routines list, empty state with ideas, complete and undo, add / edit / delete
    recall/               word exercise: round generation, scoring, flow
    settings/             text size, high contrast, reduce motion (persisted)
```

- State: Riverpod `Notifier` and `AsyncNotifier`. Repositories sit behind small interfaces so tests can use in-memory fakes.
- Storage: `shared_preferences` for settings, `sqflite` for events and routines.
- Event log: completing a routine, undoing it, finishing a word exercise and sending an idea each append one event. What the screen shows is derived from those events.

Planned sync, in outline:

```
user action -> local event (synced = false)
            -> sync service sends unsynced events in batches
            -> POST /events (idempotent by event id)
            -> accepted and duplicate ids are marked synced; failures stay queued and retry
```

Event ids are generated on the device, so a retried upload can never be stored twice.

## React Native to Flutter

Rows are only things I actually ran into.

| React Native | Flutter / Dart | What I noticed |
|---|---|---|
| Component, props | Widget, constructor named parameters | `required` and null safety replace prop-type checks; everything is a widget |
| Zustand, React Query | Riverpod `Notifier`, `AsyncNotifier` | `AsyncValue` carries loading and error, so screens handle all three states in one place |
| `FlatList` | `ListView`, `ListView.separated` | Items are built lazily, which matters in tests (below) |
| StyleSheet, flexbox | `Row`, `Column`, `Padding`, `Expanded`, `ThemeData` | Layout is widgets and constraints, not style props. Text at 200% overflowed a `Row` until the text was wrapped in `Expanded` |
| `AsyncStorage` | `shared_preferences`, `sqflite` | Key-value for settings, SQLite for structured data. `sqflite` has no date type, so times are stored as integers |
| Jest + RTL | `flutter_test` (`testWidgets`) | `pumpAndSettle` replaces waiting; items below the fold are not built, so tests need `scrollUntilVisible` |
| `accessibilityLabel` | `Semantics`, `semanticsLabel`, `MergeSemantics` | There are matchers for accessibility guidelines, such as `meetsGuideline(androidTapTargetGuideline)` |
| `allowFontScaling` | `MediaQuery.textScaler` | The in-app text size multiplies the operating system setting |
| React Navigation | `Navigator.push` with `MaterialPageRoute` | Enough for this app; I did not add a router package |
| `package.json` | `pubspec.yaml` | `flutter pub add` |
| Expo dev, EAS Build | `flutter run` with hot reload, `flutter build apk` | There is no Expo Go. Each platform is its own build. App icon and splash screen come from generator packages rather than a config file |

What surprised me and what did not map:

- One codebase still means two apps. A change reaches Android and iOS only when each one is rebuilt or hot reloaded.
- The first Android build failed with "No space left on device" while Gradle unpacked the NDK. Native toolchain size is a real cost that React Native with Expo hides.
- Layout bugs show up as visible overflow errors in debug builds. That was useful, because it caught problems at large text sizes early.
- A widget test caught a crash I had not seen: with reduce motion on, asking `PageController.animateToPage` for a zero duration fails an assertion, so reduced motion has to jump to the page instead.
- The iOS simulator caches launch screens, so a new splash can look unchanged until the simulator is restarted.

## Decision log

| Decision | Alternatives | Why | Would revisit |
|---|---|---|---|
| Mobile only, no web build | Flutter web | The brief is a mobile app, and `sqflite` does not run on web | If a web version were wanted |
| Riverpod without code generation | Built-in state, Bloc, Riverpod with generators | Closest to Zustand and React Query habits, and fewer moving parts | Add generators as the app grows |
| `SharedPreferencesAsync` for settings | Legacy `SharedPreferences` | The package recommends the newer API for new code | n/a |
| Events are the source of truth; "done" is derived from the latest event per routine | A separate state table updated alongside events | One insert is atomic and it is the same record that will sync | Compact old events |
| Event ids are random UUIDs made on the device | Server-assigned ids, the `uuid` package | Makes retried uploads safe, and avoids a dependency for 10 lines of code | Use the package if more id types appear |
| Times stored as epoch milliseconds, sent as ISO 8601 UTC | Text timestamps | Reliable ordering and range queries in SQLite | n/a |
| Routines live only on the device; the server will receive events only | Sync routine definitions too | Keeps the API small and the sync story simple | Sync routines if multi-device matters |
| Deleting a routine removes its row and name; completion events stay | Hide it with an "archived" flag (my first version) | Events hold only an id, so nothing needs the old row, and a delete should remove the user's text | n/a |
| In-app text size multiplies the system text size, range 100% to 200% | Replace the system setting | Respects an existing operating system preference | Cap the combined value |
| The exercise is called a "word exercise", not a "test", and shows a plain count | A score or grade | No assessment or diagnostic implication | Agree wording with clinical staff |
| The disclaimer is a popup the user must accept; the welcome is four intro cards; routines start empty with tappable examples | A disclaimer line on the welcome screen, pre-filled routines | A clear acknowledgement before use, and the user chooses what matters to them | Wording reviewed with clinical staff |
| Ideas from users are stored as a `feedback_submitted` event and will upload with the other events | A separate feedback endpoint | Reuses the same offline queue and idempotent upload; the form asks users not to enter personal or health details | A moderated channel if this were real |
| High contrast is green on black, checked by tests for contrast ratio | Yellow on black (my first version) | Easier on the eye while still above 7:1 for text and outlines | Test with low-vision users |
| Elapsed time for the exercise counts from when the choices appear | Include the memorising time | It measures answering, not the fixed 15 seconds | n/a |
| Icon and splash generator packages are regular dependencies | `dev_dependencies`, the usual convention | Author preference. They only run at build time | Move to `dev_dependencies` |
| No authentication, no rate limiting, anonymous device id (planned) | Accounts | A deliberate simplification for a demo | Required before real use |

Assumptions on underspecified parts: the word list and the routine suggestions are my own, the exercise length (5 words, 15 seconds) is a guess, and none of the copy has been reviewed for reading level.

## Questions I would ask the medical and product team

- What reading level and tone have been validated for this audience?
- What are the rules for storing and syncing health-adjacent data, and where may it be processed?
- Which accessibility conformance level is required?
- Which wording is allowed for exercises and results, and which is not?
- What does review and release look like for a regulated product, and how do engineering changes get clinical sign-off?
- How should the app behave when a result looks unusual: show nothing, or point to a person?

## Future ideas

These are ideas only. None is built.

- Anchor moments: attach a routine to a time of day (morning, afternoon, evening) and group the Today screen by it.
- Voice input for adding a routine, for people who find typing hard.
- A plain-language rewrite of the app's own copy to a target reading level.
- A short weekly summary in everyday words.
- Optional gentle reminders at a chosen time.
- Any AI feature would need guardrails: no health claims, review by clinical staff, no health data sent to a third-party model, and a non-AI fallback.

## Known limitations

- No authentication, rate limiting or per-user data; an anonymous device id is planned.
- The server and sync are not built yet.
- iOS runs in the simulator only (no paid Apple developer account, so no installable build).
- English only. German would come first if localization were added.
- "Today" is fixed when the screen loads and does not roll over at midnight until the app is reopened.
- Accessibility was checked with automated tests and manual large-text checks. A full screen-reader pass is still to do.
- Learning-project scope throughout.
