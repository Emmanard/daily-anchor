import 'dart:math';

import 'word_bank.dart';

class RecallRound {
  RecallRound({required this.targets, required this.choices});

  static const targetCount = 5;
  static const choiceCount = 10;

  /// The words shown to be remembered.
  final List<String> targets;

  /// The targets mixed with distractors, in display order.
  final List<String> choices;

  factory RecallRound.generate(Random random) {
    final words = List.of(recallWords)..shuffle(random);
    final targets = words.take(targetCount).toList();
    final choices = words.take(choiceCount).toList()..shuffle(random);
    return RecallRound(targets: targets, choices: choices);
  }
}

/// Number of selected words that were among the targets.
int scoreRecall(Iterable<String> targets, Iterable<String> selected) =>
    selected.toSet().intersection(targets.toSet()).length;
