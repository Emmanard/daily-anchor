# Daily Anchor

A learning project built while moving from React Native to Flutter. Not a medical product.

Daily Anchor is a small routine and word-recall companion for adults over 50. The app keeps working with no network, and sends its events to a Node.js API whenever a connection is available. It makes no diagnostic, therapeutic or health-improvement claims, uses no real personal data, and is not production work.

I built it on my own initiative while applying for the Flutter + Node.js role at memodio, to show how quickly I can move from React Native to Flutter. Nobody asked for it as an assessment. It does not copy any memodio feature, exercise, wording or branding.

## Status

| Part | State |
|---|---|
| Flutter app: splash, welcome cards, routines (add, edit, delete, complete, undo), word exercise, ideas form, progress, settings | Built, run on Android and iOS simulators |
| Offline queue and idempotent sync, with a status line (All saved, Waiting to sync, Syncing, Sync is off) | Built. Checked end to end on the Android emulator against the local API |
| Node.js API (Express, TypeScript, Zod, Prisma, PostgreSQL): `GET /health`, `POST /events`, `GET /progress` | Built and tested against a real PostgreSQL |
| Accessibility: text size up to 200%, high-contrast theme, reduce-motion, automated guideline checks on every screen | Built. A manual screen-reader pass (TalkBack, VoiceOver) is still to do |
| Continuous integration (GitHub Actions) | Written; it has not run on GitHub yet |
| Hosted API | Not done. The release APK is built with sync off unless an API address is given |

## What it demonstrates

- A Flutter app designed for a 50+ audience: large tap targets, plain language, state shown with an icon and text rather than color alone, readable at 200% text size.
- Offline-first with idempotent sync: every action is stored on the phone first as an event, then uploaded in batches with retries and backoff. Each event has an id made on the device, and the server stores an id only once, so a retry or a lost reply never duplicates anything.
- A Node.js API with strict input validation, per-event rejection, a batch limit, and tests against a real PostgreSQL.
- Accessibility checked by tests on every screen in both themes (tap-target size, labelled controls, text contrast, 200% text), plus checks that those tests really fail on bad examples.
- Tests across layers (pure Dart logic, a real SQLite database including upgrades, widget flows with error and empty states, HTTP and database tests for the API), CI, and a written decision log with the questions I would take to a medical and product team.

## Run it

Prerequisites: Flutter (stable, 3.47 at the time of writing), Android Studio for the Android emulator, Xcode for the iOS simulator.

```
cd app
flutter pub get
flutter run            # pick a connected emulator or simulator; sync is off
```

To connect the app to a local API, pass its address when building. An Android emulator reaches your computer at `10.0.2.2`; the iOS simulator uses `localhost`:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000    # iOS simulator
```

Plain HTTP is allowed only for those two local addresses (see the Android network security config and the iOS local-networking setting). A real deployment must use HTTPS.

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
| `API_BASE_URL` | Flutter app | Passed with `--dart-define`. Empty means sync is off |

```
cd api
npm install                      # also see: npm run generate
docker compose up -d             # local PostgreSQL (export POSTGRES_PASSWORD first)
npm run migrate:deploy           # create the tables (DATABASE_URL set)
npm run dev                      # start the API on PORT (default 3000)
```

Tests:

```
cd api
npm run typecheck
npm test                         # with TEST_DATABASE_URL set, the database tests run too
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
    sync/                 device id, API client, upload service, status controller
  features/
    splash/               branded splash shown at launch
    welcome/              "Before you start" popup and four intro cards
    feedback/             "Share your ideas" form
    today/                routines list, empty state with ideas, complete and undo, add / edit / delete
    recall/               word exercise: round generation, scoring, flow
    progress/             seven-day view: server totals, or this phone's own when offline
    settings/             text size, high contrast, reduce motion (persisted)
```

- State: Riverpod `Notifier` and `AsyncNotifier`. Repositories sit behind small interfaces so tests can use in-memory fakes.
- Storage: `shared_preferences` for settings and the anonymous device id, `sqflite` for events and routines.
- Event log: completing a routine, undoing it, finishing a word exercise and sending an idea each append one event. What the screen shows is derived from those events.

Sync:

```
user action -> local event (synced = false)
            -> sync controller starts an upload: at launch, on return to the app,
               after every action, and on a retry timer (5 s, 10 s, 20 s ... up to 5 min)
            -> sync service sends waiting events in batches of up to 100
            -> POST /events (the database primary key makes it idempotent)
            -> accepted and already-stored ids are marked synced; failures stay queued
```

Event ids are generated on the device, so a retried upload can never be stored twice. A reply that is lost on the way back is harmless: the retry is answered "already stored" and the events are then marked synced. Sync never blocks the screen. The status line only says what is true: "All saved", "Waiting to sync (3 items)", "Syncing", or "Saved on this phone. Sync is off".

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
| `fetch`, axios | the `http` package | Network failures arrive as exceptions of several kinds, so the client turns all of them into one error the sync code can retry on |
| `AppState` listener, NetInfo | `WidgetsBindingObserver`, no connectivity package | Returning to the app triggers an upload; a retry timer covers the rest, so I did not add a connectivity library |
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
| Routines live only on the device; the server receives events only | Sync routine definitions too | Keeps the API small and the sync story simple | Sync routines if multi-device matters |
| Deleting a routine removes its row and name; completion events stay | Hide it with an "archived" flag (my first version) | Events hold only an id, so nothing needs the old row, and a delete should remove the user's text | n/a |
| In-app text size multiplies the system text size, range 100% to 200% | Replace the system setting | Respects an existing operating system preference | Cap the combined value |
| The exercise is called a "word exercise", not a "test", and shows a plain count | A score or grade | No assessment or diagnostic implication | Agree wording with clinical staff |
| The disclaimer is a popup the user must accept; the welcome is four intro cards; routines start empty with tappable examples | A disclaimer line on the welcome screen, pre-filled routines | A clear acknowledgement before use, and the user chooses what matters to them | Wording reviewed with clinical staff |
| Ideas from users are stored as a `feedback_submitted` event and uploaded with the other events | A separate feedback endpoint | Reuses the same offline queue and idempotent upload; the form asks users not to enter personal or health details | A moderated channel if this were real |
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
| Sync uses the `http` package and no connectivity package; it starts at launch, on return to the app, after each action and on a retry timer | A connectivity package that reacts to network changes | Fewer dependencies, and the timer works on every platform | Add the package if battery or latency matter |
| Retries back off 5 s, 10 s, 20 s up to 5 minutes and reset after a success | A fixed interval | Gentle on a server that is down and on the battery | Add random jitter if many devices share a server |
| An event the server refuses is removed from the queue | Keep retrying; keep it flagged | Sending it again would be refused again and would block everything behind it. The cost is that the event is lost | Keep a "rejected" flag and show it |
| If the server's reply leaves an event unmentioned, the upload stops and retries later | Resend immediately | Avoids a tight loop against a misbehaving server | n/a |
| The Progress screen shows the server's totals when it can be reached, and this phone's own record (clearly labelled) when it cannot | An error screen when offline | The app stays useful offline, which is the point of the design | A single source of truth once routines also sync |
| The anonymous device id is a random UUID kept in `shared_preferences`; reinstalling gives a new one | A hardware id, an account | Nothing identifies a person | Accounts if multi-device history is wanted |
| Plain HTTP is allowed only for `10.0.2.2` and `localhost` | Allow all cleartext | Local development works, and every real address needs HTTPS | n/a |
| The release APK is signed with the debug key and is built with sync off | A release keystore, a hosted API | A demo build; there is nothing to publish | A keystore and a hosted API before any real distribution |
| Accessibility is checked by tests on every screen in both themes, and the checks are proven to fail on bad examples | Manual checks only | Regressions show up in CI, and a passing check means something | Add a screen-reader pass on real devices |
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

- No authentication, rate limiting or per-user data. Anyone who knows a device id could read its progress. That is acceptable for a demo and not for real use.
- The API is not hosted. The APK is built with sync off unless it is given an API address, so it shows "Sync is off" on a phone that cannot reach a server.
- An event the server refuses is dropped from the upload queue, and the person is not told.
- Routines are not synced; only events are.
- iOS runs in the simulator only (no paid Apple developer account, so no installable build).
- English only. German would come first if localization were added.
- "Today" is fixed when the screen loads and does not roll over at midnight until the app is reopened.
- Accessibility is checked by automated tests and manual large-text checks. A screen-reader pass on real devices is still to do.
- The CI workflow has been written and its commands run locally, but it has not run on GitHub yet.
- Learning-project scope throughout.
