# Daily Anchor

A learning project built while moving from React Native to Flutter. Not a medical product.

Daily Anchor is a small routine and word-recall companion for adults over 50. The app keeps working with no network, and a Node.js API is being added to receive its events. It makes no diagnostic, therapeutic or health-improvement claims, uses no real personal data, and is not production work.

I built it on my own initiative while applying for the Flutter + Node.js role at memodio, to show how quickly I can move from React Native to Flutter. Nobody asked for it as an assessment. It does not copy any memodio feature, exercise, wording or branding.

## Status

| Part | State |
|---|---|
| Flutter app: splash, welcome cards, routines (add, edit, delete, complete, undo), word exercise, ideas form, settings | Built, tested on Android and iOS simulators |
| Accessibility: text size up to 200%, high-contrast theme, reduce-motion, tap-target checks | Built. Contrast checks and a screen-reader pass still to do |
| Node.js API (Express, TypeScript, Zod, Prisma, Postgres): `GET /health`, `POST /events`, `GET /progress` | Written. Checked with type checks and database-free tests; the tests against a real PostgreSQL are still to be run |
| Offline queue and idempotent sync, progress screen | Next, after the API |
| CI, release APK, demo recording | Planned |

## What it demonstrates

- A Flutter app designed for a 50+ audience: large tap targets, plain language, state shown with an icon and text rather than color alone, readable at 200% text size.
- Offline-first by design: every action is stored locally as an event in SQLite and nothing needs a connection.
- Accessibility basics checked in tests: text scale, tap-target guideline, no overflow, semantic labels on interactive controls.
- Tests across layers: pure Dart logic, a real SQLite database (including schema upgrades), and widget flows with error and empty states.
- A written decision log and the questions I would take to a medical and product team (below).

Written but not yet connected to the app: a Node.js API with validation and idempotent event upload. Planned: the app-side sync, the Progress screen and CI.

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

### API

Prerequisites: Node 22 (22.18 or newer) and Docker for the local database.

Environment variables, names only (no values are stored in the repository). The API reads them from the process environment and never from a file:

| Variable | Used by | Purpose |
|---|---|---|
| `POSTGRES_PASSWORD` | `docker compose` | Password for the local PostgreSQL container |
| `DATABASE_URL` | API, `prisma migrate` | Connection string for the development database |
| `TEST_DATABASE_URL` | API tests | Connection string for a separate, disposable test database |
| `PORT` | API | Optional, defaults to 3000 |
| `API_BASE_URL` | Flutter app | Passed with `--dart-define` once sync is connected |

```
cd api
npm install                      # also see: npm run generate
docker compose up -d             # local PostgreSQL (export POSTGRES_PASSWORD first)
npm run migrate:deploy           # create the tables (DATABASE_URL set)
npm run dev                      # start the API
```

Tests:

```
cd api
npm run typecheck
npm test                         # most tests need no database
```

The tests in `test/prisma-store.test.ts` need a real PostgreSQL database with the migrations applied, and they delete all events. They run only when `TEST_DATABASE_URL` is set, and they never touch `DATABASE_URL`.

Endpoints:

| Request | Result |
|---|---|
| `GET /health` | `{ "status": "ok" }` |
| `POST /events` with `{ "deviceId": uuid, "events": [...] }` | `{ "accepted": [ids], "duplicates": [ids], "rejected": [{ "index", "id", "reason" }] }`. At most 100 events per request. A bad event is rejected on its own, and an id that is already stored is reported as a duplicate and never stored twice |
| `GET /progress?deviceId=...&days=7&utcOffsetMinutes=0` | One entry per day with `routinesCompleted` and `recallAttempts`, oldest first |

## Architecture

```
api/
  src/                    Express app, validation (Zod), progress calculation, storage
  prisma/                 database schema and migration
  test/                   unit, HTTP and database tests

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
| API storage sits behind an `EventStore` interface, with a Prisma and PostgreSQL implementation | Calling Prisma directly from the routes | Most behavior can be tested without a database, the same way the app uses in-memory fakes | n/a |
| The database primary key decides what is new (`createManyAndReturn` with `skipDuplicates`) | Check for existing ids first, then insert | One statement, no race between two requests that send the same id at once | Measure at larger batch sizes |
| A bad event is reported in `rejected` with its position (`index`) and a reason that never repeats what was sent; its `id` is `null` when none was sent | Fail the whole batch | The rest of the batch is still stored, and free text such as feedback is never echoed back or logged | n/a |
| A batch above 100 events is refused with 413 and nothing is stored | Store the first 100 | A client that ignores the limit finds out immediately | n/a |
| Events may be up to 24 hours in the future; later ones are rejected | No check | Tolerates clock drift but stops obviously wrong timestamps | Tighten once real devices are observed |
| Progress counts a routine as done on a day when its latest event that day is a completion, and uses the device's UTC offset for the day boundary | Count raw completions, or use UTC days | Matches what the app shows, and a late-evening action lands on the right local day | Handle daylight saving by sending the offset per event |
| Prisma 7.10 with the driver adapter, TypeScript 6.0, tsx to run the server | Prisma 8 (release candidate), TypeScript 7 (released the day I wrote this) | Stable versions with documented setup | Move to Prisma 8 once it is stable |
| Local PostgreSQL 17 in Docker | PostgreSQL 18, SQLite | 17 is widely offered by hosting providers; a real PostgreSQL is what the API runs on | n/a |
| No authentication, no rate limiting, anonymous device id | Accounts | A deliberate simplification for a demo | Required before real use |

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
- The app does not upload anything yet: sync and the Progress screen are still to be built. The API has been type-checked and tested without a database, and its tests against PostgreSQL have not been run yet.
- iOS runs in the simulator only (no paid Apple developer account, so no installable build).
- English only. German would come first if localization were added.
- "Today" is fixed when the screen loads and does not roll over at midnight until the app is reopened.
- Accessibility was checked with automated tests and manual large-text checks. A full screen-reader pass is still to do.
- Learning-project scope throughout.
