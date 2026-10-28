import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _textScaleKey = 'settings.textScale';
  static const _highContrastKey = 'settings.highContrast';
  static const _reduceMotionKey = 'settings.reduceMotion';
  static const _welcomeSeenKey = 'settings.welcomeSeen';

  final SharedPreferencesAsync _prefs;

  Future<AppSettings> load() async {
    final textScale = await _prefs.getDouble(_textScaleKey);
    final highContrast = await _prefs.getBool(_highContrastKey);
    final reduceMotion = await _prefs.getBool(_reduceMotionKey);
    final welcomeSeen = await _prefs.getBool(_welcomeSeenKey);
    return AppSettings(
      // Clamp so a stale or hand-edited value can never break the layout.
      textScale: (textScale ?? AppSettings.minTextScale).clamp(
        AppSettings.minTextScale,
        AppSettings.maxTextScale,
      ),
      highContrast: highContrast ?? false,
      reduceMotion: reduceMotion ?? false,
      welcomeSeen: welcomeSeen ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setDouble(_textScaleKey, settings.textScale);
    await _prefs.setBool(_highContrastKey, settings.highContrast);
    await _prefs.setBool(_reduceMotionKey, settings.reduceMotion);
    await _prefs.setBool(_welcomeSeenKey, settings.welcomeSeen);
  }
}
