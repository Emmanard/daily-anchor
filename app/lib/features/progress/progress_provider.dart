import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/events/event_repository.dart';
import '../../core/sync/api_config.dart';
import '../../core/sync/device_id.dart';
import '../../core/sync/events_api.dart';
import '../../core/sync/sync_controller.dart';
import 'day_progress.dart';

class ProgressView {
  const ProgressView({required this.days, required this.fromServer});

  /// Oldest first.
  final List<DayProgress> days;

  /// False when the server could not be reached and the totals come from this
  /// phone alone.
  final bool fromServer;

  int get activeDays => days.where((day) => day.active).length;

  bool get isEmpty => days.every(
    (day) => day.routinesCompleted == 0 && day.recallAttempts == 0,
  );
}

class ProgressNotifier extends AsyncNotifier<ProgressView> {
  static const days = 7;

  @override
  Future<ProgressView> build() async {
    final now = ref.read(clockProvider)();

    if (ref.read(apiBaseUrlProvider).isNotEmpty) {
      try {
        // Send anything still waiting, so the server's totals are current.
        await ref.read(syncControllerProvider.notifier).requestSync();
        final deviceId = await ref.read(deviceIdProvider.future);
        final serverDays = await ref
            .read(eventsApiProvider)
            .progress(
              deviceId,
              days: days,
              utcOffsetMinutes: now.timeZoneOffset.inMinutes,
            );
        return ProgressView(
          days: [for (final day in serverDays) _fromServer(day)],
          fromServer: true,
        );
      } on ApiException {
        // Offline or the server is down: show this phone's own record.
      }
    }

    final events = await ref
        .read(eventRepositoryProvider)
        .occurredSince(DateTime(now.year, now.month, now.day - (days - 1)));
    return ProgressView(
      days: buildLocalProgress(events, now, days),
      fromServer: false,
    );
  }

  DayProgress _fromServer(ServerDay day) {
    final parts = day.date.split('-').map(int.parse).toList();
    return DayProgress(
      date: DateTime(parts[0], parts[1], parts[2]),
      routinesCompleted: day.routinesCompleted,
      recallAttempts: day.recallAttempts,
    );
  }
}

final progressProvider =
    AsyncNotifierProvider.autoDispose<ProgressNotifier, ProgressView>(
      ProgressNotifier.new,
    );
