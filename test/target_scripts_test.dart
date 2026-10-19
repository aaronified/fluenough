// A card's spelling in a language's other scripts (`target_scripts`, #623):
// Hindustani's `target` is Devanagari and `target_scripts` holds its
// Perso-Arabic spelling. One reading and one IPA serve both.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';

const _header = '''
schema: 1
id: test-deck
name: Test deck
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari, scripts: [devanagari, perso_arabic] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
''';

String _deck(String card, {String header = _header}) =>
    '${header}cards:\n$card';

const _book = '''
  - id: hi-0004
    target: "किताब"
    target_scripts: { perso_arabic: "کتاب" }
    reading: "kitāb"
    ipa: "kɪtaːb"
    native: "book"
''';

Matcher _fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  group('target_scripts (#623)', () {
    test('a card keeps its second spelling beside one reading and IPA', () {
      final deck = DeckParser.parse(_deck(_book), source: 'test.yaml');
      final card = deck.cards.single;
      expect(card.target, 'किताब');
      expect(card.targetScripts, {'perso_arabic': 'کتاب'});
      expect(card.reading, 'kitāb');
      expect(card.ipa, 'kɪtaːb');
      expect(card.targetIn('perso_arabic', firstScript: 'devanagari'), 'کتاب');
      expect(card.targetIn('devanagari', firstScript: 'devanagari'), 'किताब');
      expect(card.targetIn('shahmukhi', firstScript: 'devanagari'), isNull);
      expect(deck.language.script, 'devanagari');
      expect(deck.language.allScripts, ['devanagari', 'perso_arabic']);
    });

    test('a card without it has none, and a language names its one script', () {
      final deck = DeckParser.parse(
        _deck(
          '  - id: es-0001\n    target: "casa"\n    native: "house"\n',
          header: _header
              .replaceAll('hi', 'es')
              .replaceAll('Hindustani', 'Spanish')
              .replaceAll('devanagari', 'latin')
              .replaceAll(', scripts: [latin, perso_arabic]', ''),
        ),
        source: 'test.yaml',
      );
      expect(deck.cards.single.targetScripts, isEmpty);
      expect(deck.language.allScripts, ['latin']);
    });

    test('a core card carries it into the merged card', () {
      final core = DeckParser.parseCore('''
schema: 1
id: "hi-test"
part: "core"
kind: "vocab"
language: { code: "hi", iso639_3: "hin", name: "Hindustani", script: "devanagari", scripts: ["devanagari", "perso_arabic"] }
license: "CC-BY-SA-4.0"
cards:
  - id: "hi-0004"
    target: "किताब"
    target_scripts: { perso_arabic: "کتاب" }
    reading: "kitāb"
''', source: 'hi-test.yaml');
      final layer = DeckParser.parseLayer('''
schema: 1
id: "hi-en-test"
kind: "layer"
core: "hi-test"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Test"
license: "CC-BY-SA-4.0"
cards:
  "hi-0004": { native: "book" }
''', source: 'hi-en-test.yaml');
      final card = mergeLayer(core, layer, source: 'l.yaml').cards.single;
      expect(card.targetScripts, {'perso_arabic': 'کتاب'});
    });

    test('it is refused when malformed', () {
      Object parse(String card) =>
          DeckParser.parse(_deck(card), source: 'test.yaml');
      String withField(String field) =>
          '  - id: hi-0004\n    target: "किताब"\n    $field\n    reading: "kitāb"\n    native: "book"\n';
      expect(
        () => parse(withField('target_scripts: "کتاب"')),
        _fails('target_scripts'),
      );
      expect(
        () => parse(withField('target_scripts: {}')),
        _fails('must not be empty'),
      );
      expect(
        () => parse(withField('target_scripts: { "Perso-Arabic": "کتاب" }')),
        _fails('not a script id'),
      );
      expect(
        () => parse(withField('target_scripts: { perso_arabic: "किताब" }')),
        _fails('same as the card\'s target'),
      );
      expect(
        () => parse(withField('target_scripts: { perso_arabic: "" }')),
        _fails('perso_arabic'),
      );
    });

    test('a language block lists its scripts with its own first', () {
      Object parse(String scripts) => DeckParser.parse(
        _deck(
          _book,
          header: _header.replaceFirst('[devanagari, perso_arabic]', scripts),
        ),
        source: 'test.yaml',
      );
      expect(
        () => parse('[perso_arabic, devanagari]'),
        _fails('starts with the block\'s script'),
      );
      expect(
        () => parse('[devanagari, devanagari]'),
        _fails('lists a script twice'),
      );
    });
  });
}
