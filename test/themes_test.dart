import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/themes.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';

void main() {
  group('parseThemes', () {
    test('reads the themes in order', () {
      final themes = parseThemes('''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: " Market " }
''');
      expect(themes.map((t) => (t.id, t.name)), [
        ('first-words', 'First words'),
        ('market', 'Market'),
      ]);
    });

    test('refuses what is not a well-formed themes file', () {
      for (final (text, why) in <(String, String)>[
        ('schema: 1\nkind: vocab\nthemes: []\n', 'kind: themes'),
        ('schema: 1\nkind: themes\nthemes: []\n', 'non-empty'),
        (
          'schema: 1\nkind: themes\nthemes:\n  - { id: Market, name: M }\n',
          'lowercase',
        ),
        (
          'schema: 1\nkind: themes\nthemes:\n  - { id: market }\n',
          'needs a name',
        ),
        (
          'schema: 1\nkind: themes\nthemes:\n'
              '  - { id: market, name: M }\n  - { id: market, name: N }\n',
          'twice',
        ),
      ]) {
        expect(
          () => parseThemes(text),
          throwsA(
            isA<DeckParseException>().having(
              (e) => e.message,
              'message',
              contains(why),
            ),
          ),
          reason: why,
        );
      }
    });
  });

  group('DeckParser and themes', () {
    const deck = '''
schema: 1
id: hi-en-market
name: Market
theme: market
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: hi-en-market-0001
    target: "कितने का है?"
    native: "how much is it?"
    pos: phrase
  - id: hi-en-market-0002
    target: "महँगा"
    native: "expensive"
''';

    test('a deck names its theme', () {
      expect(
        DeckParser.parse(deck, source: 'hi-en-market.yaml').theme,
        'market',
      );
      expect(
        DeckParser.parse(
          deck.replaceFirst('theme: market\n', ''),
          source: 'x',
        ).theme,
        isNull,
      );
    });

    test('a malformed theme is refused', () {
      expect(
        () => DeckParser.parse(
          deck.replaceFirst('theme: market', 'theme: Market!'),
          source: 'x',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('the themes file is not a deck', () {
      expect(
        () => DeckParser.parse(
          'schema: 1\nkind: themes\nthemes: []\n',
          source: 'themes.yaml',
        ),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('themes file'),
          ),
        ),
      );
    });

    test('a phrase is not typed unless it says so', () {
      final cards = DeckParser.parse(deck, source: 'x').cards;
      final phrase = cards.first;
      final word = cards.last;
      expect(phrase.modesIn(ttsAvailable: true), {
        DrillMode.recognition,
        DrillMode.listening,
      });
      expect(word.modesIn(ttsAvailable: true), contains(DrillMode.production));
      const declared = Card(
        id: 'x',
        deckId: 'd',
        target: 'a b',
        native: 'c',
        pos: 'phrase',
        modes: {DrillMode.production},
      );
      expect(declared.modesIn(ttsAvailable: true), {DrillMode.production});
    });
  });
}
