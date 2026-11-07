// The placed layer of Progress's mastery (owner, 2026-11-07): a pair is
// PLACED when placement credited it and the learner has not answered it
// since, counted apart from earned pairs (never known, never taught), so the
// star's outline stays earned-only and placed words do not hold back new
// lessons. Placed credit the learner answered becomes earned; withdrawn
// credit is not placed.

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/core/progress/unlocks.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _start = DateTime(2026, 9, 1, 9);

/// Placement credit for [card] in [mode]: grade 5, no time, no answer.
ReviewEvent _credit(
  MemoryProgress progress,
  String card, {
  DrillMode mode = DrillMode.recognition,
  Duration after = Duration.zero,
  Ask? asked,
}) => progress.record(
  deckId: 'xx-words',
  cardId: card,
  mode: mode,
  grade: 5,
  now: _start.add(after),
  asked: asked,
);

/// A real answer: it takes time.
ReviewEvent _answer(
  MemoryProgress progress,
  String card,
  int grade,
  Duration after, {
  DrillMode mode = DrillMode.recognition,
}) => progress.record(
  deckId: 'xx-words',
  cardId: card,
  mode: mode,
  grade: grade,
  now: _start.add(after),
  elapsed: const Duration(seconds: 4),
);

SkillScore _read(MemoryProgress p, {int total = 10, DateTime? asOf}) =>
    masteryAt(
      p.log,
      p.scriptLog,
      totals: <MasterySkill, int>{MasterySkill.read: total},
      scriptCards: const <String>{},
      asOf: asOf,
    )[MasterySkill.read];

Card _word(String id) =>
    Card(id: id, deckId: 'xx-words', target: id, native: id, pos: 'noun');

void main() {
  group('what placed means', () {
    test('only the first review with the shape of placement credit', () {
      final p = MemoryProgress();
      expect(_credit(p, 'a').isPlaced, isTrue);
      expect(_credit(p, 'b', asked: Ask.own).isPlaced, isTrue);
      // A real answer: grade, time or an answer given.
      expect(_answer(p, 'c', 5, Duration.zero).isPlaced, isFalse);
      expect(
        p
            .record(
              deckId: 'xx-words',
              cardId: 'd',
              mode: DrillMode.recognition,
              grade: 5,
              now: _start,
              answerGiven: 'x',
            )
            .isPlaced,
        isFalse,
      );
      expect(
        p
            .record(
              deckId: 'xx-words',
              cardId: 'e',
              mode: DrillMode.recognition,
              grade: 4,
              now: _start,
            )
            .isPlaced,
        isFalse,
      );
      // Credit written over an existing state is not a pair's first review.
      _answer(p, 'f', 4, Duration.zero);
      expect(_credit(p, 'f', after: const Duration(days: 1)).isPlaced, isFalse);
    });
  });

  group('the star', () {
    test('a placed pair is placed: not known, not taught, outline earned '
        'only, and the total holds it', () {
      final p = MemoryProgress();
      _credit(p, 'a');
      _credit(p, 'b');
      final star = _read(p, total: 1);
      expect(star.placed, 2);
      expect(star.taught, 0);
      expect(star.known, 0);
      expect(star.outline, isNull, reason: 'nothing earned: the centre');
      expect(star.fill, 0);
      expect(star.total, 2, reason: 'never below taught plus placed');
      expect(star.placedFill, 1.0);
    });

    test('placed, then a pass: the pair is earned from that answer on', () {
      final p = MemoryProgress();
      _credit(p, 'a');
      _answer(p, 'a', 4, const Duration(days: 1));
      final star = _read(p);
      expect(star.placed, 0, reason: 'answered since');
      expect(star.taught, 1);
      expect(star.known, 1, reason: 'a right answer at 85% recall or better');
      expect(star.placedFill, star.fill);
    });

    test('placed, then a fail: the lapsed pair is taught and not known, and '
        'drops out of the placed layer', () {
      final p = MemoryProgress();
      _credit(p, 'a');
      _credit(p, 'b');
      _answer(p, 'a', 1, const Duration(days: 1));
      final star = _read(p);
      expect(star.placed, 1, reason: 'only b is still placed');
      expect(star.taught, 1);
      expect(star.known, 0);
      expect(star.outline, 0.0);
    });

    test('withdrawn credit is not placed: the log leaves it out', () {
      final p = MemoryProgress();
      final credit = _credit(p, 'a');
      _credit(p, 'b');
      p.withdrawCredit(
        PlacementWithdrawal(
          at: _start.add(const Duration(hours: 1)),
          language: 'xx',
          creditAt: momentOf(credit.at),
          modes: <DrillMode>[DrillMode.recognition],
          script: null,
          deckIds: <String>['xx-words'],
        ),
      );
      expect(_read(p).placed, 0, reason: 'both were written in that second');
      expect(p.log, isEmpty);
    });

    test('set in stone or reviewed as usual makes no difference: placement '
        'is reflected either way', () {
      // The credit's own ask mode is recorded or not; both are placed.
      final p = MemoryProgress();
      _credit(p, 'a');
      _credit(p, 'b', asked: Ask.own);
      expect(_read(p).placed, 2);
    });

    test('the series is as of the day asked: placed from its day on', () {
      final p = MemoryProgress();
      _credit(p, 'a', after: const Duration(days: 2));
      expect(_read(p, asOf: _start).placed, 0);
      expect(_read(p, asOf: _start.add(const Duration(days: 3))).placed, 1);
    });

    test('a sum over languages adds the placed pairs', () {
      final p = MemoryProgress();
      _credit(p, 'a');
      final one = masteryAt(
        p.log,
        p.scriptLog,
        totals: const <MasterySkill, int>{MasterySkill.read: 5},
        scriptCards: const <String>{},
      );
      final sum = sumMastery(<Mastery>[one, one]);
      expect(sum[MasterySkill.read].placed, 2);
      expect(sum[MasterySkill.read].total, 10);
    });
  });

  group('words counted on Progress', () {
    test('a word placed and not answered is placed, not taught', () {
      final p = MemoryProgress();
      _credit(p, 'a');
      _credit(p, 'a', mode: DrillMode.listening);
      _credit(p, 'b');
      _answer(p, 'c', 4, Duration.zero);
      final counts = wordCounts(p.log);
      expect(counts.placed, 2);
      expect(counts.taught, 1);
      expect(counts.mastered, 0);
    });

    test('a word answered in one skill and placed in another is taught, its '
        'placed pair left out of its standing', () {
      final p = MemoryProgress();
      _answer(p, 'a', 4, Duration.zero);
      _answer(p, 'a', 4, const Duration(days: 1));
      _credit(p, 'a', mode: DrillMode.listening);
      final counts = wordCounts(p.log);
      expect(counts.taught, 1);
      expect(counts.placed, 0);
      expect(
        counts.mastered,
        1,
        reason:
            'the placed hearing is not held '
            'against a word known by reading',
      );
    });
  });

  group('lessons', () {
    final cards = <KindedCard>[
      for (final id in <String>['xx-1', 'xx-2', 'xx-3'])
        (card: _word(id), kind: DeckKind.vocab),
    ];

    Unlocks unlocks(MemoryProgress p) =>
        Unlocks(log: p.log, cards: <Card>[for (final e in cards) e.card]);

    test('placed words do not count as in progress, so they do not throttle '
        'new lessons', () {
      final p = MemoryProgress();
      _credit(p, 'xx-1');
      _credit(p, 'xx-2');
      expect(unlocks(p).inProgress(cards), 0);
      expect(unlocks(p).answers.isPlacedOnly('xx-1'), isTrue);
      expect(unlocks(p).answers.isPlacedOnly('xx-3'), isFalse);
    });

    test('a placed word the learner answered and missed is in progress', () {
      final p = MemoryProgress();
      _credit(p, 'xx-1');
      _answer(p, 'xx-1', 1, const Duration(days: 1));
      expect(unlocks(p).inProgress(cards), 1);
      expect(unlocks(p).answers.isPlacedOnly('xx-1'), isFalse);
    });

    test('the counts show placed words apart from the taught ones', () {
      final p = MemoryProgress();
      _credit(p, 'xx-1');
      _credit(p, 'xx-2');
      _answer(p, 'xx-3', 4, Duration.zero);
      final c = unlocks(p).counts(cards);
      expect(c.wordsPlaced, 2);
      expect(c.wordsTaught, 1);
      expect(c.wordsKnown, 0);
      // Placed words are not known: nothing that waits for them opens.
      expect(unlocks(p).isWordKnown('xx-1'), isFalse);
      expect(sumUnlockCounts(<UnlockCounts>[c, c]).wordsPlaced, 4);
    });
  });
}
