import 'package:daily_anchor/features/settings/app_settings.dart';
import 'package:daily_anchor/features/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('returns defaults when nothing is stored', () async {
    final settings = await SettingsRepository().load();

    expect(settings.textScale, 1.0);
    expect(settings.highContrast, isFalse);
    expect(settings.reduceMotion, isFalse);
    expect(settings.welcomeSeen, isFalse);
  });

  test('saved settings survive a new repository instance', () async {
    await SettingsRepository().save(
      const AppSettings(
        textScale: 1.5,
        highContrast: true,
        reduceMotion: true,
        welcomeSeen: true,
      ),
    );

    final loaded = await SettingsRepository().load();

    expect(loaded.textScale, 1.5);
    expect(loaded.highContrast, isTrue);
    expect(loaded.reduceMotion, isTrue);
    expect(loaded.welcomeSeen, isTrue);
  });

  test('clamps an out-of-range stored text scale', () async {
    await SharedPreferencesAsync().setDouble('settings.textScale', 5.0);

    final loaded = await SettingsRepository().load();

    expect(loaded.textScale, AppSettings.maxTextScale);
  });
}
