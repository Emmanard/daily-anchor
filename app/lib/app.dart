import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/settings/settings_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/today/today_screen.dart';
import 'features/welcome/welcome_screen.dart';

class DailyAnchorApp extends ConsumerWidget {
  /// [showSplash] is only turned on by main(); tests start on the real screen.
  const DailyAnchorApp({super.key, this.showSplash = false});

  final bool showSplash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Daily Anchor',
      theme: buildTheme(highContrast: settings.highContrast),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // The in-app size multiplies the system size, so an operating system
        // text setting is still respected.
        final systemScale = media.textScaler.scale(1);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(systemScale * settings.textScale),
            disableAnimations: media.disableAnimations || settings.reduceMotion,
          ),
          child: child!,
        );
      },
      home: _Root(showSplash: showSplash),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root({required this.showSplash});

  final bool showSplash;

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  static const _splashDuration = Duration(milliseconds: 1500);

  late bool _splashDone = !widget.showSplash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!_splashDone) {
      _timer = Timer(_splashDuration, _finishSplash);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finishSplash() {
    _timer?.cancel();
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishSplash,
        child: const SplashScreen(),
      );
    }
    final welcomeSeen = ref.watch(
      settingsProvider.select((s) => s.welcomeSeen),
    );
    return welcomeSeen ? const TodayScreen() : const WelcomeScreen();
  }
}
