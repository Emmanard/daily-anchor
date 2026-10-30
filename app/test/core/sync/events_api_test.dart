import 'dart:async';
import 'dart:convert';

import 'package:daily_anchor/core/events/app_event.dart';
import 'package:daily_anchor/core/sync/events_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/events.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

HttpEventsApi _api(
  Future<http.Response> Function(http.Request request) handler, {
  String baseUrl = 'http://api.test',
  Duration timeout = const Duration(seconds: 5),
}) => HttpEventsApi(
  baseUrl: baseUrl,
  client: MockClient(handler),
  timeout: timeout,
);

void main() {
  group('upload', () {
    test(
      'posts the device id and events in the shape the server expects',
      () async {
        late http.Request seen;
        final api = _api((request) async {
          seen = request;
          return _json({
            'accepted': ['a'],
            'duplicates': [],
            'rejected': [],
          });
        });
        final event = AppEvent(
          id: 'a',
          type: EventType.recallCompleted,
          payload: {'correctCount': 4, 'durationMs': 9000},
          occurredAt: DateTime.utc(2026, 10, 28, 9, 30),
        );

        await api.upload('device-1', [event]);

        expect(seen.method, 'POST');
        expect(seen.url.toString(), 'http://api.test/events');
        expect(seen.headers['content-type'], contains('application/json'));
        expect(jsonDecode(seen.body), {
          'deviceId': 'device-1',
          'events': [
            {
              'id': 'a',
              'type': 'recall_completed',
              'payload': {'correctCount': 4, 'durationMs': 9000},
              'occurredAt': '2026-10-28T09:30:00.000Z',
            },
          ],
        });
      },
    );

    test('counts accepted and duplicate ids as delivered', () async {
      final api = _api(
        (_) async => _json({
          'accepted': ['a'],
          'duplicates': ['b'],
          'rejected': [],
        }),
      );

      final result = await api.upload('d', [routineEvent(), routineEvent()]);

      expect(result.acknowledged, {'a', 'b'});
      expect(result.rejected, isEmpty);
    });

    test('maps a rejected position back to the event id', () async {
      final first = routineEvent();
      final second = routineEvent();
      final api = _api(
        (_) async => _json({
          'accepted': [first.id],
          'duplicates': [],
          'rejected': [
            {'index': 1, 'id': second.id, 'reason': 'type: invalid_value'},
          ],
        }),
      );

      final result = await api.upload('d', [first, second]);

      expect(result.acknowledged, {first.id});
      expect(result.rejected, {second.id});
    });

    test('ignores a rejected position that is out of range', () async {
      final api = _api(
        (_) async => _json({
          'accepted': [],
          'duplicates': [],
          'rejected': [
            {'index': 9, 'id': null, 'reason': 'x'},
          ],
        }),
      );

      final result = await api.upload('d', [routineEvent()]);

      expect(result.rejected, isEmpty);
    });

    test('a trailing slash in the base address does no harm', () async {
      late Uri seen;
      final api = _api((request) async {
        seen = request.url;
        return _json({'accepted': [], 'duplicates': [], 'rejected': []});
      }, baseUrl: 'http://api.test///');

      await api.upload('d', [routineEvent()]);

      expect(seen.toString(), 'http://api.test/events');
    });

    test('a non-200 reply is an error to retry later', () async {
      final api = _api((_) async => _json({'error': 'x'}, 500));

      expect(
        () => api.upload('d', [routineEvent()]),
        throwsA(isA<ApiException>()),
      );
    });

    test('a reply that is not JSON is an error', () async {
      final api = _api((_) async => http.Response('<html>', 200));

      expect(
        () => api.upload('d', [routineEvent()]),
        throwsA(isA<ApiException>()),
      );
    });

    test('no connection is an error', () async {
      final api = _api((_) async => throw http.ClientException('offline'));

      expect(
        () => api.upload('d', [routineEvent()]),
        throwsA(isA<ApiException>()),
      );
    });

    test('a server that never answers times out', () async {
      final api = _api(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        () => api.upload('d', [routineEvent()]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });

  group('progress', () {
    test(
      'asks for the device, the number of days and the UTC offset',
      () async {
        late Uri seen;
        final api = _api((request) async {
          seen = request.url;
          return _json({'deviceId': 'd', 'days': []});
        });

        await api.progress('device-1', days: 7, utcOffsetMinutes: 60);

        expect(seen.path, '/progress');
        expect(seen.queryParameters, {
          'deviceId': 'device-1',
          'days': '7',
          'utcOffsetMinutes': '60',
        });
      },
    );

    test('reads one entry per day', () async {
      final api = _api(
        (_) async => _json({
          'deviceId': 'd',
          'days': [
            {'date': '2026-10-27', 'routinesCompleted': 2, 'recallAttempts': 1},
            {'date': '2026-10-28', 'routinesCompleted': 0, 'recallAttempts': 0},
          ],
        }),
      );

      final days = await api.progress('d', days: 2, utcOffsetMinutes: 0);

      expect(days.map((d) => d.date), ['2026-10-27', '2026-10-28']);
      expect(days.first.routinesCompleted, 2);
      expect(days.first.recallAttempts, 1);
    });

    test('an unexpected reply is an error', () async {
      final api = _api((_) async => _json({'nope': true}));

      expect(
        () => api.progress('d', days: 7, utcOffsetMinutes: 0),
        throwsA(isA<ApiException>()),
      );
    });

    test('no connection is an error', () async {
      final api = _api((_) async => throw http.ClientException('offline'));

      expect(
        () => api.progress('d', days: 7, utcOffsetMinutes: 0),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
