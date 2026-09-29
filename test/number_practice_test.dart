import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/number_rules_parser.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/number_rules.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/numbers/number_speller.dart';

NumberRules bundled(String code) => parseNumberRules(
  File('decks/$code/$code-numbers.yaml').readAsStringSync(),
  source: '$code-numbers.yaml',
);

void main() {
  final hi = bundled('hi');
  const all = <DrillMode>{
    DrillMode.recognition,
    DrillMode.production,
    DrillMode.listening,
  };

  test('ten different numbers the rules can spell, the skills in turn', () {
    final items = numberPractice(
      hi,
      deckId: 'hi-en-numbers-big',
      modes: all,
      random: Random(54),
    );
    expect(items, hasLength(10));
    final numbers = [for (final i in items) (i.card as NumberCard).number];
    expect(numbers.toSet(), hasLength(10));
    for (final item in items) {
      final card = item.card as NumberCard;
      final spellings = spellNumber(hi, card.number);
      expect(spellings, isNotEmpty, reason: '${card.number}');
      expect(card.target, spellings.first);
      expect(card.altTarget, spellings.sublist(1));
      expect(card.native, '${card.number}');
      expect(card.deckId, 'hi-en-numbers-big');
      expect(card.id, 'hi-numbers-${card.number}');
      expect(item.isNew, isTrue);
    }
    expect(
      [for (final i in items.take(4)) i.mode],
      <DrillMode>[
        DrillMode.recognition,
        DrillMode.production,
        DrillMode.listening,
        DrillMode.recognition,
      ],
    );
  });

  test('only the skills asked for, and none from grammar alone', () {
    final typed = numberPractice(
      hi,
      deckId: 'hi-en-numbers-big',
      modes: const <DrillMode>{DrillMode.production, DrillMode.grammar},
      random: Random(1),
    );
    expect(typed.map((i) => i.mode).toSet(), {DrillMode.production});
    expect(
      numberPractice(
        hi,
        deckId: 'hi-en-numbers-big',
        modes: const <DrillMode>{DrillMode.grammar},
        random: Random(1),
      ),
      isEmpty,
    );
  });

  test('heard, a number is answered in digits; shown, in words', () {
    final card = NumberCard(
      number: 2020,
      spellings: spellNumber(hi, 2020),
      rulesId: hi.id,
      deckId: 'hi-en-numbers-big',
    );
    expect(card.acceptedAnswers(DrillMode.listening), <String>['2020']);
    expect(card.acceptedAnswers(DrillMode.production), <String>[
      'दो हज़ार बीस',
      'दो हजार बीस',
    ]);
    expect(card.acceptedAnswers(DrillMode.recognition), <String>['2020']);
    expect(card.promptFor(DrillMode.production), '2020');
    expect(card.promptFor(DrillMode.recognition), 'दो हज़ार बीस');
  });
}
