import 'package:daily_anchor/core/sync/device_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('creates a random UUID on first use', () async {
    final id = await DeviceIdRepository().getOrCreate();

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('keeps the same id after the app restarts', () async {
    final first = await DeviceIdRepository().getOrCreate();
    final second = await DeviceIdRepository().getOrCreate();

    expect(second, first);
  });

  test('a different install gets a different id', () async {
    final first = await DeviceIdRepository().getOrCreate();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final other = await DeviceIdRepository().getOrCreate();

    expect(other, isNot(first));
  });
}
