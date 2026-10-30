import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ids.dart';

/// An anonymous random id created on first launch. It is not tied to a person
/// and is only used to group a phone's events on the server.
class DeviceIdRepository {
  DeviceIdRepository([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'device.id';

  final SharedPreferencesAsync _prefs;

  Future<String> getOrCreate() async {
    final existing = await _prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = newUuid();
    await _prefs.setString(_key, created);
    return created;
  }
}

final deviceIdProvider = FutureProvider<String>(
  (ref) => DeviceIdRepository().getOrCreate(),
);
