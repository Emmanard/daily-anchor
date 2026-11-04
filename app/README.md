# Daily Anchor: Flutter app

The Flutter app for Daily Anchor, a learning project built while moving from React Native to Flutter. It is not a medical product.

The project overview, status, architecture, decision log and known limitations are in the [main README](../README.md). This page only covers working inside this folder.

## Run it

Needs Flutter (stable, 3.47 when this was written), plus an Android emulator or the iOS simulator.

```bash
flutter pub get
flutter run
```

With no API address the app keeps everything on the phone and the status line says "Saved on this phone. Sync is off." To connect it to a local API, pass its address when building. An Android emulator reaches your computer at `10.0.2.2`; the iOS simulator uses `localhost`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000    # iOS simulator
```

Starting the API is described in [api/README.md](../api/README.md).

## Checks

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The tests cover pure Dart logic, a real SQLite database (including upgrades), widget flows with their error and empty states, the upload queue and sync, and accessibility guidelines on every screen in both themes.

## Where things are

```text
lib/
  main.dart, app.dart     start-up, theme and text scale, first-run switch
  core/                   theme, clock, ids, SQLite, event model, sync (device id, API client, queue, status)
  features/
    splash/  welcome/  today/  recall/  progress/  feedback/  settings/
test/                     mirrors lib/, plus accessibility_test.dart and test/support/ fakes
```

## Build an APK

```bash
flutter build apk --release                                          # sync off
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

The release build is signed with the debug key, which is fine for a demo but not for distribution.
