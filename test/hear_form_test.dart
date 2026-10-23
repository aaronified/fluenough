// What Hear asks, a form or a meaning, is a property of the card's own data
// (#522, step 7): a letter or a digit by its `pos`, a word marked
// `hears: form`, or a generated number; never the deck it sits in.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

Card card(String id, {String? pos, String? hears}) => Card(
  id: id,
  deckId: 'te-script-vowels',
  target: 'అ',
  native: 'a',
  pos: pos,
  hears: hears,
);

String deckWith(String cards) => '''
schema: 1
id: te-en-probe
name: Probe
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
$cards''';

void main() {
  group('what Hear asks of a card', () {
    final number = NumberCard(
      number: 2,
      spellings: const <String>['do'],
      rulesId: 'hi',
      deckId: 'hi-en-numbers-big',
    );

    test('a letter, a digit, a marked word or a number is heard as its form, '
        'a word as its meaning, whatever its deck', () {
      final state = AppState.test();
      addTearDown(state.dispose);
      expect(state.hearsForm(card('te-1', pos: 'letter')), isTrue);
      expect(state.hearsForm(card('te-2', pos: 'digit')), isTrue);
      expect(state.hearsForm(card('te-3', pos: 'noun', hears: 'form')), isTrue);
      expect(state.hearsForm(number), isTrue);
      expect(state.hearsForm(card('te-4', pos: 'noun')), isFalse);
      expect(state.hearsForm(card('te-5')), isFalse);
    });
  });

  group('the skill map follows the card', () {
    test('a right Hear answer on a heard form implies Write, on a word '
        'Recognition', () {
      const map = SkillMap(formHeardCards: <String>{'te-1'});
      expect(map.impliedBy(DrillMode.listening, 'any', cardId: 'te-1'), {
        DrillMode.production: SkillMap.implied,
      });
      expect(map.impliedBy(DrillMode.listening, 'any', cardId: 'te-2'), {
        DrillMode.recognition: SkillMap.implied,
      });
    });

    test('the app lists the cards that hear a form, by their data', () async {
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/te/te-en-probe.yaml': deckWith('''
  - { id: te-1, target: "అ", native: "a", pos: letter }
  - { id: te-2, target: "అల", native: "wave", pos: noun, hears: form }
  - { id: te-3, target: "ఇల్లు", native: "house", pos: noun }
'''),
        }),
      );
      addTearDown(state.dispose);
      await state.load();
      final skills = state.progress.skills;
      Set<DrillMode> implied(String id) => skills
          .impliedBy(DrillMode.listening, 'te-en-probe', cardId: id)
          .keys
          .toSet();
      expect(implied('te-1'), {DrillMode.production});
      expect(implied('te-2'), {DrillMode.production});
      expect(implied('te-3'), {DrillMode.recognition});
    });
  });

  group('the parser reads hears', () {
    Deck parse(String cards) =>
        DeckParser.parse(deckWith(cards), source: 'probe.yaml');

    test('hears: form is kept and the card hears its form', () {
      final c = parse(
        '  - { id: te-1, target: "అల", native: "wave", '
        'pos: noun, hears: form }\n',
      ).cards.single;
      expect(c.hears, 'form');
      expect(c.hearsForm, isTrue);
    });

    test('any other value is refused', () {
      expect(
        () => parse(
          '  - { id: te-1, target: "అ", native: "a", hears: meaning }\n',
        ),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('hears must be "form"'),
          ),
        ),
      );
    });
  });
}
