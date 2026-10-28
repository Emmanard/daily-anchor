import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

/// Loaded in main() before the first frame and supplied as an override, so the
/// theme and text scale are correct from the first build.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> setTextScale(double value) =>
      _update(state.copyWith(textScale: value));

  Future<void> setHighContrast(bool value) =>
      _update(state.copyWith(highContrast: value));

  Future<void> setReduceMotion(bool value) =>
      _update(state.copyWith(reduceMotion: value));

  Future<void> markWelcomeSeen() => _update(state.copyWith(welcomeSeen: true));

  Future<void> _update(AppSettings next) async {
    state = next;
    try {
      await ref.read(settingsRepositoryProvider).save(next);
    } catch (_) {
      // The setting still applies for this session; it just will not persist.
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
