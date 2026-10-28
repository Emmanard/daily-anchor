import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final percent = (settings.textScale * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Text size: $percent%', style: _sectionStyle(context)),
          // Room for the always-visible value bubble above the thumb.
          const SizedBox(height: 40),
          Slider(
            value: settings.textScale,
            min: AppSettings.minTextScale,
            max: AppSettings.maxTextScale,
            divisions: 4,
            label: '$percent%',
            semanticFormatterCallback: (value) =>
                'Text size ${(value * 100).round()} percent',
            onChanged: notifier.setTextScale,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('100%'), Text('200%')],
            ),
          ),
          const SizedBox(height: 16),
          const Text('This is how your text will look.'),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High contrast'),
            subtitle: const Text('Stronger colors and thicker outlines.'),
            value: settings.highContrast,
            onChanged: notifier.setHighContrast,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Turn off animations.'),
            value: settings.reduceMotion,
            onChanged: notifier.setReduceMotion,
          ),
        ],
      ),
    );
  }

  TextStyle? _sectionStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;
}
