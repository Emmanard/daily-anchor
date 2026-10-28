import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of the current time; tests override it to control elapsed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
