import 'package:daily_anchor/core/events/event_repository.dart';
import 'package:daily_anchor/core/sync/api_config.dart';
import 'package:daily_anchor/core/sync/device_id.dart';
import 'package:daily_anchor/core/sync/events_api.dart';
import 'package:daily_anchor/core/sync/sync_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/events.dart';
import '../../support/fake_events_api.dart';
import '../../support/in_memory_event_repository.dart';

class _Fixture {
  _Fixture({String baseUrl = 'http://api.test'})
    : repository = InMemoryEventRepository(),
      api = FakeEventsApi() {
    container = ProviderContainer(
      overrides: [
        apiBaseUrlProvider.overrideWithValue(baseUrl),
        eventRepositoryProvider.overrideWithValue(repository),
        eventsApiProvider.overrideWithValue(api),
        deviceIdProvider.overrideWith((ref) async => 'device-1'),
      ],
    );
  }

  final InMemoryEventRepository repository;
  final FakeEventsApi api;
  late final ProviderContainer container;

  SyncState get state => container.read(syncControllerProvider);
  SyncController get controller =>
      container.read(syncControllerProvider.notifier);

  /// Builds the controller and lets its first run finish.
  Future<void> start(WidgetTester tester) async {
    container.read(syncControllerProvider);
    await tester.pump();
  }
}

void main() {
  testWidgets('is off, and uploads nothing, when no server is configured', (
    tester,
  ) async {
    final f = _Fixture(baseUrl: '');
    f.repository.events.addAll([routineEvent(), routineEvent()]);

    await f.start(tester);

    expect(f.state.status, SyncStatus.off);
    expect(f.state.pending, 2);
    expect(f.api.uploadCount, 0);
    f.container.dispose();
  });

  testWidgets('is synced when nothing is waiting', (tester) async {
    final f = _Fixture();

    await f.start(tester);

    expect(f.state.status, SyncStatus.synced);
    expect(f.state.pending, 0);
    expect(f.api.uploadCount, 0);
    f.container.dispose();
  });

  testWidgets('uploads what is waiting when it starts', (tester) async {
    final f = _Fixture();
    f.repository.events.addAll([routineEvent(), recallEvent()]);

    await f.start(tester);

    expect(f.state.status, SyncStatus.synced);
    expect(f.state.pending, 0);
    expect(f.api.stored, hasLength(2));
    f.container.dispose();
  });

  testWidgets('shows waiting while offline and keeps the events', (
    tester,
  ) async {
    final f = _Fixture();
    f.api.fail = true;
    f.repository.events.addAll([routineEvent(), routineEvent()]);

    await f.start(tester);

    expect(f.state.status, SyncStatus.waiting);
    expect(f.state.pending, 2);
    expect(f.api.stored, isEmpty);
    f.container.dispose();
  });

  testWidgets(
    'retries by itself and uploads each event once when back online',
    (tester) async {
      final f = _Fixture();
      f.api.fail = true;
      f.repository.events.addAll([routineEvent(), routineEvent()]);
      await f.start(tester);

      f.api.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(f.state.status, SyncStatus.synced);
      expect(f.state.pending, 0);
      expect(f.api.stored, hasLength(2));
      expect(f.api.uploadCount, 1);
      f.container.dispose();
    },
  );

  testWidgets('backs off 5, 10, 20 seconds and so on, up to 5 minutes', (
    tester,
  ) async {
    final f = _Fixture();
    f.api.fail = true;
    f.repository.events.add(routineEvent());
    await f.start(tester);
    expect(f.api.attempts, 1);

    for (final delay in [5, 10, 20, 40, 80, 160, 300, 300]) {
      final before = f.api.attempts;

      await tester.pump(Duration(seconds: delay - 1));
      expect(
        f.api.attempts,
        before,
        reason: 'tried too early before ${delay}s',
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(f.api.attempts, before + 1, reason: 'did not retry at ${delay}s');
      expect(f.state.status, SyncStatus.waiting);
    }
    f.container.dispose();
  });

  testWidgets('a new action is uploaded straight away', (tester) async {
    final f = _Fixture();
    await f.start(tester);
    expect(f.state.status, SyncStatus.synced);

    f.repository.events.add(routineEvent());
    await f.controller.requestSync();

    expect(f.state.status, SyncStatus.synced);
    expect(f.api.stored, hasLength(1));
    f.container.dispose();
  });

  testWidgets('asking twice at once runs one upload and then re-checks', (
    tester,
  ) async {
    final f = _Fixture();
    f.repository.events.add(routineEvent());
    f.container.read(syncControllerProvider);

    final first = f.controller.requestSync();
    final second = f.controller.requestSync();
    await Future.wait([first, second]);
    await tester.pump();

    expect(f.api.uploadCount, 1);
    expect(f.state.status, SyncStatus.synced);
    f.container.dispose();
  });

  testWidgets('a lost reply never stores an event twice', (tester) async {
    final f = _Fixture();
    f.api.loseReply = true;
    f.repository.events.addAll([
      routineEvent(),
      routineEvent(),
      routineEvent(),
    ]);
    await f.start(tester);

    expect(f.state.status, SyncStatus.waiting);
    expect(f.api.stored, hasLength(3));

    f.api.loseReply = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(f.state.status, SyncStatus.synced);
    expect(f.api.stored, hasLength(3));
    expect(f.api.uploads, hasLength(2));
    f.container.dispose();
  });

  testWidgets('stops retrying once it has been disposed', (tester) async {
    final f = _Fixture();
    f.api.fail = true;
    f.repository.events.add(routineEvent());
    await f.start(tester);

    f.container.dispose();
    f.api.fail = false;
    await tester.pump(const Duration(minutes: 10));

    expect(f.api.uploadCount, 0);
  });
}
