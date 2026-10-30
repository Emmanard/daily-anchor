import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/event_repository.dart';
import 'api_config.dart';
import 'device_id.dart';
import 'events_api.dart';
import 'sync_service.dart';

enum SyncStatus {
  /// No server is configured; everything stays on the phone.
  off,
  synced,
  syncing,
  waiting,
}

class SyncState {
  const SyncState({required this.status, this.pending = 0});

  final SyncStatus status;

  /// Events saved on the phone that the server has not confirmed yet.
  final int pending;
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    events: ref.watch(eventRepositoryProvider),
    api: ref.watch(eventsApiProvider),
    deviceId: () => ref.read(deviceIdProvider.future),
  ),
);

/// Keeps the upload going without ever blocking the person using the app.
/// Uploads are started when the app opens, when it returns to the foreground,
/// after each action, and by a retry timer that backs off while the server
/// cannot be reached.
class SyncController extends Notifier<SyncState> {
  static const _firstRetry = Duration(seconds: 5);
  static const _longestRetry = Duration(minutes: 5);

  Timer? _retryTimer;
  Future<void>? _current;
  bool _again = false;
  bool _disposed = false;
  int _failures = 0;

  bool get _configured => ref.read(apiBaseUrlProvider).isNotEmpty;

  @override
  SyncState build() {
    ref.onDispose(() {
      _disposed = true;
      _retryTimer?.cancel();
    });
    // Start after the first frame's work, so the app never waits for it.
    Future.microtask(requestSync);
    return SyncState(status: _configured ? SyncStatus.syncing : SyncStatus.off);
  }

  /// Starts an upload, or joins the one already running. The returned future
  /// completes when the run is over.
  Future<void> requestSync() {
    final running = _current;
    if (running != null) {
      _again = true;
      return running;
    }
    return _current = _loop().whenComplete(() => _current = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _runOnce();
    } while (_again && !_disposed);
  }

  Future<void> _runOnce() async {
    if (_disposed) return;
    _retryTimer?.cancel();

    final events = ref.read(eventRepositoryProvider);
    var pending = await events.unsyncedCount();
    if (_disposed) return;

    if (!_configured) {
      state = SyncState(status: SyncStatus.off, pending: pending);
      return;
    }
    if (pending == 0) {
      _failures = 0;
      state = const SyncState(status: SyncStatus.synced);
      return;
    }

    state = SyncState(status: SyncStatus.syncing, pending: pending);
    final emptied = await ref.read(syncServiceProvider).drain();
    if (_disposed) return;

    pending = await events.unsyncedCount();
    if (_disposed) return;
    if (emptied) {
      _failures = 0;
      state = SyncState(status: SyncStatus.synced, pending: pending);
    } else {
      _failures += 1;
      state = SyncState(status: SyncStatus.waiting, pending: pending);
      _retryTimer = Timer(_retryDelay(), requestSync);
    }
  }

  /// 5 s, 10 s, 20 s and so on, up to 5 minutes.
  Duration _retryDelay() {
    final seconds = _firstRetry.inSeconds * pow(2, _failures - 1).toInt();
    return Duration(seconds: min(seconds, _longestRetry.inSeconds));
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
