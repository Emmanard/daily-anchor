import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/sync/events_api.dart';

/// A stand-in server that keeps a set of event ids, like the real one's
/// primary key, so tests can check that nothing is stored twice.
class FakeEventsApi implements EventsApi {
  /// The ids of each upload request, in order.
  final List<List<String>> uploads = [];

  /// Ids the "server" holds.
  final Set<String> stored = {};
  String? lastDeviceId;

  /// The server cannot be reached.
  bool fail = false;

  /// The server stores the events but the reply never arrives.
  bool loseReply = false;

  /// Ids the server refuses as invalid.
  Set<String> rejectIds = {};

  /// Ids the server forgets to mention in its reply.
  Set<String> omitIds = {};

  List<ServerDay> progressDays = [];
  bool failProgress = false;

  /// Every upload attempt, including ones that failed.
  int attempts = 0;

  int get uploadCount => uploads.length;

  @override
  Future<UploadResult> upload(String deviceId, List<AppEvent> events) async {
    attempts += 1;
    if (fail) throw const ApiException('could not reach the server');
    lastDeviceId = deviceId;
    uploads.add([for (final event in events) event.id]);

    final acknowledged = <String>{};
    final rejected = <String>{};
    for (final event in events) {
      if (rejectIds.contains(event.id)) {
        rejected.add(event.id);
        continue;
      }
      stored.add(event.id);
      if (!omitIds.contains(event.id)) acknowledged.add(event.id);
    }
    if (loseReply) throw const ApiException('request timed out');
    return UploadResult(acknowledged: acknowledged, rejected: rejected);
  }

  @override
  Future<List<ServerDay>> progress(
    String deviceId, {
    required int days,
    required int utcOffsetMinutes,
  }) async {
    if (failProgress || fail) throw const ApiException('could not reach');
    return progressDays;
  }
}
