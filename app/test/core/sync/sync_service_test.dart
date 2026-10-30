import 'package:daily_anchor/core/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/events.dart';
import '../../support/fake_events_api.dart';
import '../../support/in_memory_event_repository.dart';

void main() {
  late InMemoryEventRepository repository;
  late FakeEventsApi api;
  late SyncService service;

  setUp(() {
    repository = InMemoryEventRepository();
    api = FakeEventsApi();
    service = SyncService(
      events: repository,
      api: api,
      deviceId: () async => 'device-1',
    );
  });

  test('uploads waiting events and marks them synced', () async {
    repository.events.addAll([routineEvent(), recallEvent()]);

    final emptied = await service.drain();

    expect(emptied, isTrue);
    expect(api.uploadCount, 1);
    expect(api.lastDeviceId, 'device-1');
    expect(await repository.unsyncedCount(), 0);
    expect(api.stored, hasLength(2));
  });

  test('does nothing when there is nothing to upload', () async {
    expect(await service.drain(), isTrue);
    expect(api.uploadCount, 0);
  });

  test('leaves events waiting when the server cannot be reached', () async {
    repository.events.addAll([routineEvent(), routineEvent()]);
    api.fail = true;

    final emptied = await service.drain();

    expect(emptied, isFalse);
    expect(await repository.unsyncedCount(), 2);
    expect(api.stored, isEmpty);
  });

  test('a retry after a failure uploads each event exactly once', () async {
    repository.events.addAll([routineEvent(), routineEvent()]);
    api.fail = true;
    await service.drain();
    api.fail = false;

    await service.drain();
    await service.drain();

    expect(api.stored, hasLength(2));
    expect(api.uploadCount, 1);
    expect(await repository.unsyncedCount(), 0);
  });

  test(
    'a lost reply is safe: the retry is answered as already stored',
    () async {
      final events = [routineEvent(), routineEvent()];
      repository.events.addAll(events);
      api.loseReply = true;

      final first = await service.drain();
      api.loseReply = false;
      final second = await service.drain();

      expect(first, isFalse);
      expect(second, isTrue);
      // The same two ids were sent twice, and the server holds each only once.
      expect(api.uploads, hasLength(2));
      expect(api.uploads[0], api.uploads[1]);
      expect(api.stored, hasLength(2));
      expect(await repository.unsyncedCount(), 0);
    },
  );

  test('sends large queues in batches of 100', () async {
    repository.events.addAll(List.generate(250, (_) => routineEvent()));

    final emptied = await service.drain();

    expect(emptied, isTrue);
    expect(api.uploads.map((batch) => batch.length), [100, 100, 50]);
    expect(api.stored, hasLength(250));
    expect(await repository.unsyncedCount(), 0);
  });

  test('sends the oldest events first', () async {
    final newer = routineEvent(at: DateTime.utc(2026, 10, 28, 12));
    final older = routineEvent(at: DateTime.utc(2026, 10, 28, 8));
    repository.events.addAll([newer, older]);

    await service.drain();

    expect(api.uploads.single, [older.id, newer.id]);
  });

  test(
    'drops events the server refuses so they do not block the queue',
    () async {
      final good = routineEvent();
      final bad = routineEvent();
      repository.events.addAll([good, bad]);
      api.rejectIds = {bad.id};

      final emptied = await service.drain();

      expect(emptied, isTrue);
      expect(await repository.unsyncedCount(), 0);
      expect(api.stored, {good.id});
    },
  );

  test(
    'stops, and does not loop, if the server leaves an event unmentioned',
    () async {
      final mentioned = routineEvent();
      final forgotten = routineEvent();
      repository.events.addAll([mentioned, forgotten]);
      api.omitIds = {forgotten.id};

      final emptied = await service.drain();

      expect(emptied, isFalse);
      expect(api.uploadCount, 1);
      expect(await repository.unsyncedCount(), 1);
    },
  );

  test('does not send events that are already synced', () async {
    repository.events.add(routineEvent(synced: true));

    expect(await service.drain(), isTrue);
    expect(api.uploadCount, 0);
  });
}
