import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../events/app_event.dart';
import 'api_config.dart';

/// The server could not be reached or did not accept the request. Retrying
/// later is the right response.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

class UploadResult {
  const UploadResult({required this.acknowledged, required this.rejected});

  /// Ids the server stored now or had already stored.
  final Set<String> acknowledged;

  /// Ids the server refused as invalid. Sending them again cannot help.
  final Set<String> rejected;
}

class ServerDay {
  const ServerDay({
    required this.date,
    required this.routinesCompleted,
    required this.recallAttempts,
  });

  /// The device's local day as YYYY-MM-DD.
  final String date;
  final int routinesCompleted;
  final int recallAttempts;
}

abstract class EventsApi {
  Future<UploadResult> upload(String deviceId, List<AppEvent> events);

  Future<List<ServerDay>> progress(
    String deviceId, {
    required int days,
    required int utcOffsetMinutes,
  });
}

class HttpEventsApi implements EventsApi {
  HttpEventsApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<UploadResult> upload(String deviceId, List<AppEvent> events) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$_baseUrl/events'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'deviceId': deviceId,
          'events': [for (final event in events) event.toJson()],
        }),
      ),
    );
    final body = _decode(response);

    final acknowledged = <String>{
      ..._stringList(body['accepted']),
      ..._stringList(body['duplicates']),
    };
    final rejected = <String>{};
    final rejectedEntries = body['rejected'];
    if (rejectedEntries is List) {
      for (final entry in rejectedEntries) {
        // The server reports the position in the batch we sent.
        final index = entry is Map ? entry['index'] : null;
        if (index is int && index >= 0 && index < events.length) {
          rejected.add(events[index].id);
        }
      }
    }
    return UploadResult(acknowledged: acknowledged, rejected: rejected);
  }

  @override
  Future<List<ServerDay>> progress(
    String deviceId, {
    required int days,
    required int utcOffsetMinutes,
  }) async {
    final uri = Uri.parse('$_baseUrl/progress').replace(
      queryParameters: {
        'deviceId': deviceId,
        'days': '$days',
        'utcOffsetMinutes': '$utcOffsetMinutes',
      },
    );
    final body = _decode(await _send(() => _client.get(uri)));

    final list = body['days'];
    if (list is! List) throw const ApiException('unexpected progress reply');
    return [
      for (final entry in list)
        if (entry is Map)
          ServerDay(
            date: entry['date'] as String,
            routinesCompleted: entry['routinesCompleted'] as int,
            recallAttempts: entry['recallAttempts'] as int,
          ),
    ];
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException('server replied ${response.statusCode}');
      }
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('request timed out');
    } catch (_) {
      // No connection, DNS failure, reset connection and similar.
      throw const ApiException('could not reach the server');
    }
  }

  Map<String, Object?> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {
      // Falls through to the error below.
    }
    throw const ApiException('unexpected reply');
  }

  List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  void close() => _client.close();
}

final eventsApiProvider = Provider<EventsApi>((ref) {
  final api = HttpEventsApi(baseUrl: ref.watch(apiBaseUrlProvider));
  ref.onDispose(api.close);
  return api;
});
