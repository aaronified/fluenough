// Words, rules and sentences (#416, #417, #418, parts of #413): the unlock
// gate, lessons without the quota, and the counts Progress, a unit and the
// end of a lesson show.

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/progress/recent_answers.dart';
import 'package:fluenough/core/progress/unlocks.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _start = DateTime(2026, 9, 1, 9);

/// A word taught in a vocab deck.
Card _word(String id) =>
    Card(id: id, deckId: 'xx-words', target: id, native: id, pos: 'noun');

/// A sentence naming [words] by their cards and [rules].
Card _sentence(
  String id, {
  List<String> words = const <String>[],
  List<String> rules = const <String>[],
  bool phrasebook = false,
}) => Card(
  id: id,
  deckId: 'xx-sentences',
  target: 'one two three',
  native: id,
  pos: 'phrase',
  phrasebook: phrasebook,
  bases: <CardBase>[for (final w in words) CardBase(word: w, ref: w)],
  rules: rules,
);

/// A cell of a rules table: [word] in [rule].
Card _cell(String id, String word, {String rule = 'xx-rule-in'}) => Card(
  id: id,
  deckId: 'xx-rules',
  target: '$word-in',
  native: 'in $word',
  rule: RuleCell(ruleId: rule, word: word, wordTarget: word, slot: 'in'),
);

/// Answers [id] with [grades] in turn, one a minute, from [from].
void _answer(
  MemoryProgress progress,
  String id,
  List<int> grades, {
  DateTime? from,
}) {
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-words',
      cardId: id,
      mode: DrillMode.recognition,
      grade: grade,
      now: (from ?? _start).add(Duration(minutes: i)),
    );
  }
}

const List<int> _nineOfTen = <int>[4, 4, 4, 1, 4, 4, 4, 4, 4, 4];
const List<int> _sevenOfTen = <int>[4, 1, 4, 1, 4, 4, 1, 4, 4, 4];

void main() {
  group('the unlock gate', () {
    final cards = <Card>[
      _word('xx-0001'),
      _word('xx-0002'),
      _cell('xx-r-1', 'xx-0001'),
      _cell('xx-r-2', 'xx-0002'),
      _sentence(
        'xx-s-1',
        words: <String>['xx-0001', 'xx-0002'],
        rules: <String>['xx-rule-in'],
      ),
      _sentence('xx-p-1', words: <String>['xx-0002'], phrasebook: true),
    ];

    test('a sentence opens only once its last word and its rule are known; '
        'the phrasebook is never held back', () {
      final progress = MemoryProgress();
      Unlocks gate() => Unlocks(log: progress.log, cards: cards);
      final sentence = cards[4];
      final chunk = cards[5];

      expect(gate().isClosed(sentence), isTrue);
      expect(gate().isClosed(chunk), isFalse, reason: 'a chunk never waits');
      expect(
        gate().waitingFor(sentence).map((n) => n.id),
        unorderedEquals(<String>['xx-0001', 'xx-0002', 'xx-rule-in']),
      );

      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0002', _nineOfTen);
      _answer(progress, 'xx-r-1', _sevenOfTen);
      expect(gate().waitingFor(sentence).map((n) => n.id), <String>[
        'xx-rule-in',
      ], reason: 'the rule is answered right on 7 of its last 10: not known');
      expect(gate().isClosed(sentence), isTrue);

      _answer(
        progress,
        'xx-r-1',
        _nineOfTen,
        from: _start.add(const Duration(days: 1)),
      );
      expect(gate().isClosed(sentence), isFalse);
      expect(gate().isOpen(sentence), isTrue);
    });

    test(
      'a word is known on 9 of its last 10 answers; old misses fall out',
      () {
        final progress = MemoryProgress();
        _answer(progress, 'xx-0001', <int>[1, 1, 1, ..._nineOfTen]);
        _answer(progress, 'xx-0002', _sevenOfTen);
        final answers = RecentAnswers(progress.log);
        expect(answers.of('xx-0001').level, MasteryLevel.known);
        expect(answers.rightOf('xx-0001'), 9);
        expect(answers.of('xx-0002').level, MasteryLevel.learning);
        expect(answers.rightOf('xx-0002'), 7);
      },
    );

    test('a rule that the learner\'s course does not teach is not waited '
        'for, and a word it does not have is not either', () {
      final lonely = _sentence(
        'xx-s-2',
        words: <String>['xx-9999'],
        rules: <String>['xx-rule-missing'],
      );
      final gate = Unlocks(log: MemoryProgress().log, cards: cards);
      expect(gate.needsOf(lonely), isEmpty);
      expect(gate.isClosed(lonely), isFalse);
    });

    test('a rule\'s table grows as words are learned: a cell is taught only '
        'for a word that is known', () {
      final progress = MemoryProgress();
      Unlocks gate() => Unlocks(log: progress.log, cards: cards);
      expect(gate().isCellOpen(cards[2]), isFalse);
      expect(gate().isCellOpen(cards[3]), isFalse);
      _answer(progress, 'xx-0001', _nineOfTen);
      expect(gate().isCellOpen(cards[2]), isTrue);
      expect(gate().isCellOpen(cards[3]), isFalse);
      expect(gate().isOpen(_word('xx-0003')), isTrue);
    });
  });

  group('the counts', () {
    final cards = <KindedCard>[
      (card: _word('xx-0001'), kind: DeckKind.vocab),
      (card: _word('xx-0002'), kind: DeckKind.vocab),
      (card: _word('xx-0003'), kind: DeckKind.vocab),
      (card: _cell('xx-r-1', 'xx-0001'), kind: DeckKind.rules),
      (
        card: _sentence(
          'xx-s-1',
          words: <String>['xx-0001'],
          rules: <String>['xx-rule-in'],
        ),
        kind: DeckKind.vocab,
      ),
      (
        card: _sentence('xx-s-2', words: <String>['xx-0003']),
        kind: DeckKind.vocab,
      ),
    ];

    UnlockCounts count(MemoryProgress progress) => Unlocks(
      log: progress.log,
      cards: <Card>[for (final e in cards) e.card],
    ).counts(cards);

    test('words, rules and sentences are counted against what is taught so '
        'far, words by their base word', () {
      final progress = MemoryProgress();
      expect(count(progress), noUnlockCounts);

      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0002', _sevenOfTen);
      _answer(progress, 'xx-r-1', _nineOfTen);
      // Two words taught, one of them known; the rule is known; the
      // sentences of the deck the learner began count, one of them open.
      progress.record(
        deckId: 'xx-sentences',
        cardId: 'xx-s-1',
        mode: DrillMode.recognition,
        grade: 4,
        now: _start.add(const Duration(days: 2)),
      );
      final counts = count(progress);
      expect(counts.wordsKnown, 1);
      expect(counts.wordsTaught, 2);
      expect(counts.rulesKnown, 1);
      expect(counts.rulesTaught, 1);
      expect(counts.sentencesTotal, 2);
      expect(counts.sentencesOpen, 1, reason: 'xx-s-2 waits for xx-0003');
    });

    test('two forms of one word are one word', () {
      const form = Card(
        id: 'xx-0004',
        deckId: 'xx-words',
        target: 'forms',
        native: 'forms',
        pos: 'noun',
        bases: <CardBase>[CardBase(word: 'forms', ref: 'xx-0001')],
      );
      final all = <KindedCard>[
        (card: _word('xx-0001'), kind: DeckKind.vocab),
        (card: form, kind: DeckKind.vocab),
      ];
      final progress = MemoryProgress();
      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0004', _nineOfTen);
      final counts = Unlocks(
        log: progress.log,
        cards: <Card>[for (final e in all) e.card],
      ).counts(all);
      expect(counts.wordsTaught, 1);
      expect(counts.wordsKnown, 1);
    });
  });
}
