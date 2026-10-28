import 'dart:math';

import 'package:daily_anchor/features/recall/recall_round.dart';
import 'package:daily_anchor/features/recall/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the word bank has no duplicates and enough words', () {
    expect(recallWords.toSet(), hasLength(recallWords.length));
    expect(recallWords.length, greaterThanOrEqualTo(RecallRound.choiceCount));
  });

  test('a round has 5 targets inside 10 distinct choices', () {
    final round = RecallRound.generate(Random(1));

    expect(round.targets, hasLength(5));
    expect(round.choices, hasLength(10));
    expect(round.choices.toSet(), hasLength(10));
    expect(round.choices.toSet().containsAll(round.targets), isTrue);
    expect(recallWords.toSet().containsAll(round.choices), isTrue);
  });

  test('the same seed gives the same round', () {
    final a = RecallRound.generate(Random(7));
    final b = RecallRound.generate(Random(7));

    expect(a.targets, b.targets);
    expect(a.choices, b.choices);
  });

  test('different seeds give different rounds', () {
    final a = RecallRound.generate(Random(1));
    final b = RecallRound.generate(Random(2));

    expect(a.targets, isNot(b.targets));
  });

  group('scoreRecall', () {
    const targets = ['a', 'b', 'c', 'd', 'e'];

    test('counts every correct pick', () {
      expect(scoreRecall(targets, ['a', 'b', 'c', 'd', 'e']), 5);
    });

    test('ignores words that were not targets', () {
      expect(scoreRecall(targets, ['a', 'b', 'x', 'y', 'z']), 2);
    });

    test('is zero when nothing matches or nothing is picked', () {
      expect(scoreRecall(targets, ['x', 'y']), 0);
      expect(scoreRecall(targets, const []), 0);
    });

    test('does not count a repeated pick twice', () {
      expect(scoreRecall(targets, ['a', 'a', 'a']), 1);
    });
  });
}
