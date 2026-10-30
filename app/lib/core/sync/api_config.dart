import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the API lives, set at build time with
/// `--dart-define=API_BASE_URL=http://host:port`. Empty means sync is off and
/// the app keeps everything on the phone.
final apiBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('API_BASE_URL'),
);
