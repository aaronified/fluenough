import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/placement/verify_sampler.dart';

/// Runs [sampler] against a learner: [knows] says whether a question from a
/// deck is answered right.
VerifySampler run(
  int decks,
  bool Function(int deck) knows, {
  int seed = 1,
}) {
  final s = VerifySampler(decks, seed: seed);
  var guard = 0;
  while (!s.isFinished) {
    s.answer(knows(s.deck!));
    if (++guard > 100) fail('the run does not end');
  }
  return s;
}

void main() {
  for (final decks in <int>[1, 2, 8, 20, 21, 60, 170]) {
    test('a learner who knows everything is verified in $decks decks, '
        'within 25 questions', () {
      final s = run(decks, (_) => true);
      expect(s.verified, isTrue);
      expect(s.landing, decks);
      expect(s.asked, lessThanOrEqualTo(25));
    });
  }

  test('the last deck is asked first, twice at least', () {
    final s = VerifySampler(60);
    expect(s.deck, 59);
    s.answer(true);
    expect(s.deck, 59);
  });

  test('a language with no decks verifies nothing', () {
    final s = VerifySampler(0);
    expect(s.isFinished, isTrue);
    expect(s.verified, isFalse);
  });

  for (final decks in <int>[8, 60, 170]) {
    test('a learner who knows nothing is placed at the start in $decks '
        'decks, after two questions on the last and two on the first', () {
      final s = run(decks, (_) => false);
      expect(s.verified, isFalse);
      expect(s.landing, 0);
      expect(s.flawDeck, 0);
      expect(s.asked, 4);
    });
  }

  test('a learner who knows the first half is not verified and lands '
      'near the middle', () {
    final s = run(100, (d) => d < 50);
    expect(s.verified, isFalse);
    expect(s.flawDeck, isNotNull);
    expect(s.flawDeck, greaterThanOrEqualTo(50));
    expect(s.landing, s.flawDeck);
    expect(s.asked, lessThanOrEqualTo(25));
  });

  test('a learner who knows the last deck but not the one before it is '
      'not verified, with the flaw found', () {
    final s = run(30, (d) => d != 28 && d != 27 || d == 29);
    expect(s.verified, isFalse);
    expect(s.flawDeck, 28);
  });

  test('a learner who knows only the last deck is sampled forward from the '
      'first when the last deck was missed', () {
    final s = run(100, (d) => d < 40 && d != 99);
    expect(s.verified, isFalse);
    expect(s.landing, greaterThanOrEqualTo(40));
    expect(s.flawDeck, greaterThanOrEqualTo(40));
    expect(s.asked, lessThanOrEqualTo(25));
  });

  test('one slip is forgiven; two misses in one deck are a flaw', () {
    var slipped = false;
    final forgiven = run(60, (d) {
      if (d == 30 && !slipped) {
        slipped = true;
        return false;
      }
      return true;
    });
    // The deck may not be sampled; if it was, it was asked again and passed.
    expect(forgiven.verified, isTrue);

    final flawed = VerifySampler(60);
    flawed.answer(true);
    flawed.answer(true);
    final deck = flawed.deck!;
    flawed.answer(false);
    expect(flawed.deck, deck, reason: 'a miss asks the deck again');
    flawed.answer(false);
    expect(flawed.isFinished, isTrue);
    expect(flawed.verified, isFalse);
    expect(flawed.flawDeck, deck);
  });

  test('a flaky learner is never verified past three misses, and a run '
      'never exceeds 25 questions', () {
    for (var seed = 0; seed < 50; seed++) {
      final r = Random(seed);
      final s = run(90, (_) => r.nextDouble() < 0.6, seed: seed);
      expect(s.asked, lessThanOrEqualTo(25), reason: 'seed $seed');
      if (s.verified) expect(s.flawDeck, isNull);
    }
  });

  test('the same seed asks the same decks', () {
    List<int> decksOf(int seed) {
      final s = VerifySampler(120, seed: seed);
      final seen = <int>[];
      while (!s.isFinished) {
        seen.add(s.deck!);
        s.answer(true);
      }
      return seen;
    }

    expect(decksOf(3), decksOf(3));
  });

  test('a short path is sampled in every deck', () {
    final s = VerifySampler(10);
    final seen = <int>{};
    while (!s.isFinished) {
      seen.add(s.deck!);
      s.answer(true);
    }
    expect(seen, <int>{for (var i = 0; i < 10; i++) i});
  });

  test('a longer path is sampled in some decks only', () {
    final s = VerifySampler(170);
    final seen = <int>{};
    while (!s.isFinished) {
      seen.add(s.deck!);
      s.answer(true);
    }
    expect(seen.length, lessThan(25));
    expect(seen, containsAll(<int>[169, 0]));
  });
}
