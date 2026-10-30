import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/events/app_event.dart';
import '../../core/events/event_repository.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_controller.dart';
import 'recall_round.dart';

enum _Phase { intro, memorize, choose, result }

class RecallScreen extends ConsumerStatefulWidget {
  const RecallScreen({super.key, this.random});

  /// Only set by tests, to make the chosen words predictable.
  final Random? random;

  @override
  ConsumerState<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends ConsumerState<RecallScreen> {
  static const _memorizeSeconds = 15;

  late final Random _random = widget.random ?? Random();
  late RecallRound _round;
  final Set<String> _selected = {};

  _Phase _phase = _Phase.intro;
  Timer? _timer;
  int _secondsLeft = _memorizeSeconds;
  DateTime? _choosingStartedAt;
  bool _submitted = false;
  int _correct = 0;
  int _durationMs = 0;
  bool _saveFailed = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _round = RecallRound.generate(_random);
      _selected.clear();
      _submitted = false;
      _saveFailed = false;
      _secondsLeft = _memorizeSeconds;
      _phase = _Phase.memorize;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _choosingStartedAt = ref.read(clockProvider)();
          _phase = _Phase.choose;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitted || _selected.length != RecallRound.targetCount) return;
    _submitted = true;

    final now = ref.read(clockProvider)();
    final correct = scoreRecall(_round.targets, _selected);
    final durationMs = now.difference(_choosingStartedAt!).inMilliseconds;

    var saved = true;
    try {
      await ref
          .read(eventRepositoryProvider)
          .append(
            AppEvent(
              id: newUuid(),
              type: EventType.recallCompleted,
              payload: {'correctCount': correct, 'durationMs': durationMs},
              occurredAt: now.toUtc(),
            ),
          );
    } catch (_) {
      saved = false;
    }

    if (!mounted) return;
    if (saved) {
      unawaited(ref.read(syncControllerProvider.notifier).requestSync());
    }
    setState(() {
      _correct = correct;
      _durationMs = durationMs;
      _saveFailed = !saved;
      _phase = _Phase.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Word recall')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.memorize => _memorize(context),
          _Phase.choose => _choose(context),
          _Phase.result => _result(context),
        },
      ),
    );
  }

  List<Widget> _intro(BuildContext context) {
    return [
      Text(
        'You will see ${RecallRound.targetCount} words for '
        '$_memorizeSeconds seconds. Then pick them out of a list of '
        '${RecallRound.choiceCount}.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 24),
      _PrimaryButton(label: 'Start', onPressed: _start),
    ];
  }

  List<Widget> _memorize(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Text('Remember these words', style: textTheme.titleLarge),
      const SizedBox(height: 16),
      for (final word in _round.targets)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(word, style: textTheme.headlineMedium),
        ),
      const SizedBox(height: 16),
      Text('Time left: $_secondsLeft seconds', style: textTheme.bodyLarge),
    ];
  }

  List<Widget> _choose(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final full = _selected.length >= RecallRound.targetCount;
    return [
      Text(
        'Choose the ${RecallRound.targetCount} words you saw',
        style: textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        '${_selected.length} of ${RecallRound.targetCount} chosen',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: 8),
      for (final word in _round.choices)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(word, style: textTheme.titleMedium),
          value: _selected.contains(word),
          // Once five are chosen, only already-chosen words can be changed.
          onChanged: (_selected.contains(word) || !full)
              ? (checked) => setState(() {
                  checked! ? _selected.add(word) : _selected.remove(word);
                })
              : null,
        ),
      const SizedBox(height: 16),
      _PrimaryButton(
        label: 'Check my answers',
        onPressed: full ? _submit : null,
      ),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final seconds = (_durationMs / 1000).round();
    return [
      Text(
        'You picked $_correct of ${RecallRound.targetCount} words correctly.',
        style: textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text('It took you $seconds seconds.', style: textTheme.bodyLarge),
      if (_saveFailed) ...[
        const SizedBox(height: 8),
        Text(
          'This result could not be saved on this device.',
          style: textTheme.bodyLarge,
        ),
      ],
      const SizedBox(height: 24),
      _PrimaryButton(
        label: 'Back to Today',
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: 12),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: _start,
        child: const Text('Try again'),
      ),
    ];
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
