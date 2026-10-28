import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import '../today/routines_provider.dart';

const _suggestions = [
  (title: 'Morning water', iconKey: 'water'),
  (title: 'Short walk', iconKey: 'walk'),
  (title: 'Call someone', iconKey: 'call'),
  (title: 'Read for ten minutes', iconKey: 'task'),
];

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final Set<String> _selected = {};
  bool _saving = false;
  bool _failed = false;

  Future<void> _getStarted() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });

    final routines = ref.read(routinesProvider.notifier);
    for (final suggestion in _suggestions) {
      if (!_selected.contains(suggestion.title)) continue;
      final saved = await routines.add(
        suggestion.title,
        iconKey: suggestion.iconKey,
      );
      if (!saved) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _failed = true;
        });
        return;
      }
    }
    await ref.read(settingsProvider.notifier).markWelcomeSeen();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Routines that already exist are not offered again.
    final existing = {
      for (final routine in ref.watch(routinesProvider).value ?? const [])
        routine.title,
    };
    final offered = [
      for (final suggestion in _suggestions)
        if (!existing.contains(suggestion.title)) suggestion,
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Welcome to Daily Anchor',
                style: textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A simple place for the small things you want to do each day.',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MergeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExcludeSemantics(child: Icon(Icons.info_outline)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Daily Anchor is a learning project. It is not a '
                          'medical product and does not give health advice.',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (offered.isNotEmpty) ...[
              Text(
                'Pick a few to start, or add your own later.',
                style: textTheme.titleMedium,
              ),
              for (final suggestion in offered)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(suggestion.title, style: textTheme.titleMedium),
                  value: _selected.contains(suggestion.title),
                  onChanged: _saving
                      ? null
                      : (checked) => setState(() {
                          checked!
                              ? _selected.add(suggestion.title)
                              : _selected.remove(suggestion.title);
                        }),
                ),
            ] else
              Text(
                'You can add your own routines on the next screen.',
                style: textTheme.titleMedium,
              ),
            if (_failed) ...[
              const SizedBox(height: 8),
              Text(
                'That did not save. Please try again.',
                style: textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _saving ? null : _getStarted,
              child: const Text('Get started'),
            ),
          ],
        ),
      ),
    );
  }
}
