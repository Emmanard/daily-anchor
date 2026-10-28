import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/settings/settings_provider.dart';
import 'features/today/today_screen.dart';
import 'features/welcome/welcome_screen.dart';

class DailyAnchorApp extends ConsumerWidget {
  const DailyAnchorApp({super.key});

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
      home: settings.welcomeSeen ? const TodayScreen() : const WelcomeScreen(),
    );
  }
}
