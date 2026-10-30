import '../events/event_repository.dart';
import 'events_api.dart';

/// Uploads the events waiting on the phone, in batches.
class SyncService {
  SyncService({
    required this._events,
    required this._api,
    required this._deviceId,
    this.batchSize = 100,
  });

  final EventRepository _events;
  final EventsApi _api;
  final Future<String> Function() _deviceId;
  final int batchSize;

  /// Uploads until nothing is waiting. Returns true if the queue is empty, and
  /// false if something failed and should be tried again later. Events stay
  /// queued until the server has confirmed them.
  Future<bool> drain() async {
    final deviceId = await _deviceId();
    while (true) {
      final batch = await _events.unsynced(limit: batchSize);
      if (batch.isEmpty) return true;

      final UploadResult result;
      try {
        result = await _api.upload(deviceId, batch);
      } on ApiException {
        return false;
      }

      // An id the server already had counts as delivered, which is what makes a
      // retry after a lost reply safe. Rejected ids are dropped from the queue
      // because sending them again would be refused again.
      final done = {...result.acknowledged, ...result.rejected};
      await _events.markSynced(done);

      // If the server did not account for every event, stop instead of
      // sending the same batch again immediately.
      if (!batch.every((event) => done.contains(event.id))) return false;
    }
  }
}
