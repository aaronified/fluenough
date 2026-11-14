// A script deck's character data (#1226): the deck's `character_scheme` and a
// card's `character` block, read from a single-file deck and from a core and
// its layer. The made-up language zz has two kinds of reading and two level
// schemes; no real language or script is named by the code under test.

import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/character.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';

const String _scheme = '''
character_scheme:
  readings:
    first: { name: { en: "First reading", es: "Primera lectura" }, script: "telugu" }
    second: { name: { en: "Second reading" }, script: "latin" }
  levels:
    grade: { name: { en: "School grade" }, values: [1, 2, 3] }
    exam: { name: { en: "Exam" }, values: ["E2", "E1"] }
''';

const String _threeCards = '''
  - id: "zz-9801"
    target: "క"
    pos: "letter"
    character:
      readings:
        - { kind: "first", text: "కా", reading: "kaa" }
        - { kind: "first", text: "కి" }
        - { kind: "second", text: "ka" }
      level: { grade: 1, exam: "E2" }
      strokes: 4
      radical: "క"
  - id: "zz-9802"
    target: "ఖ"
    pos: "letter"
    character:
      readings:
        - { kind: "second", text: "kha" }
  - id: "zz-9803"
    target: "గ"
    pos: "letter"
''';

const String _language =
    'language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }';

/// A single-file deck's cards also have their meaning; a core's do not.
String _single(String cards, {String scheme = _scheme}) =>
    '''
schema: 1
id: "zz-en-glyphs"
name: "Glyphs"
$_language
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
$scheme
cards:
${cards.replaceAll('    pos: "letter"\n', '    native: "n"\n    pos: "letter"\n')}''';

String _core(String cards, {String scheme = _scheme}) =>
    '''
schema: 1
id: "zz-glyphs"
part: "core"
kind: "vocab"
$_language
license: "CC0-1.0"
$scheme
cards:
$cards''';

const String _layer = '''
schema: 1
id: "zz-en-glyphs"
kind: "layer"
core: "zz-glyphs"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Glyphs"
license: "CC0-1.0"
cards:
  "zz-9801": { native: "ka" }
  "zz-9802": { native: "kha" }
  "zz-9803": { native: "ga" }
''';

Deck _parseSingle(String text) =>
    DeckParser.parse(text, source: 'zz-en-glyphs.yaml');

Matcher _refusing(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

String _withCharacter(String block) => _single('''
  - id: "zz-9801"
    target: "క"
    pos: "letter"
    character:
$block''');

void main() {
  group('character data', () {
    test('a single-file card keeps its readings by kind, levels, strokes and '
        'radical', () {
      final deck = _parseSingle(_single(_threeCards));
      final character = deck.cards.first.character!;
      expect(character.readings.map((r) => (r.kind, r.text, r.reading)), [
        ('first', 'కా', 'kaa'),
        ('first', 'కి', null),
        ('second', 'ka', null),
      ]);
      expect(character.readingsOf('first').map((r) => r.text), ['కా', 'కి']);
      expect(character.readingsOf('second').single.text, 'ka');
      expect(character.readingsOf('none'), isEmpty);
      expect(character.levels, {'grade': '1', 'exam': 'E2'});
      expect(character.strokes, 4);
      expect(character.radical, 'క');
    });

    test('a card may give only some of it, or none', () {
      final cards = _parseSingle(_single(_threeCards)).cards;
      final partial = cards[1].character!;
      expect(partial.readings.single.kind, 'second');
      expect(partial.levels, isEmpty);
      expect(partial.strokes, isNull);
      expect(partial.radical, isNull);
      expect(cards[2].character, isNull);
    });

    test('the deck names its reading kinds and level schemes', () {
      final scheme = _parseSingle(_single(_threeCards)).characterScheme!;
      expect(scheme.readings.map((k) => (k.id, k.script)), [
        ('first', 'telugu'),
        ('second', 'latin'),
      ]);
      expect(scheme.readingKind('first')!.nameIn('es'), 'Primera lectura');
      expect(scheme.readingKind('second')!.nameIn('es'), 'Second reading');
      expect(scheme.readingKind('third'), isNull);
      expect(scheme.levelScheme('grade')!.values, ['1', '2', '3']);
      expect(scheme.levelScheme('exam')!.values, ['E2', 'E1']);
      expect(scheme.levelScheme('exam')!.nameIn('en'), 'Exam');
      expect(scheme.levelScheme('none'), isNull);
    });

    test('a deck without them loads as before', () {
      const plain = '''
  - id: "zz-9803"
    target: "గ"
    pos: "letter"
''';
      final deck = _parseSingle(_single(plain, scheme: ''));
      expect(deck.characterScheme, isNull);
      expect(deck.cards.single.character, isNull);
    });

    test('a core and its layer merge into a deck that has them', () {
      final deck = mergeLayer(
        DeckParser.parseCore(_core(_threeCards), source: 'zz-glyphs.yaml'),
        DeckParser.parseLayer(_layer, source: 'zz-en-glyphs.yaml'),
        source: 'zz-en-glyphs.yaml',
      );
      expect(deck.characterScheme!.readings, hasLength(2));
      expect(deck.cards.first.native, 'ka');
      expect(deck.cards.first.character!.strokes, 4);
      expect(deck.cards.first.character!.readingsOf('first'), hasLength(2));
      expect(deck.cards[2].character, isNull);
      // A deck's cards without their refs, as the drills see it.
      expect(deck.withCards(deck.cards).characterScheme, isNotNull);
    });

    test('a card taken by ref into another deck keeps its character', () {
      final written = _parseSingle(_single(_threeCards)).cards.first;
      final taken = const CardRef(
        id: 'zz-9801',
        position: 0,
        native: 'ka',
      ).resolve(written, deckId: 'zz-bn-glyphs', sameNative: false)!;
      expect(taken.character, same(written.character));
    });

    test('a layer may not carry a character block', () {
      final bad = _layer.replaceFirst(
        '"zz-9801": { native: "ka" }',
        '"zz-9801": { native: "ka", character: { strokes: 4 } }',
      );
      expect(
        () => DeckParser.parseLayer(bad, source: 'zz-en-glyphs.yaml'),
        _refusing('belongs to the word'),
      );
    });

    test('a block with an unknown field, a bad stroke count or a radical of '
        'two characters is refused, naming the field', () {
      expect(
        () => _parseSingle(_withCharacter('      colour: "red"\n')),
        _refusing('unknown field'),
      );
      expect(
        () => _parseSingle(_withCharacter('      strokes: -3\n')),
        _refusing('character.strokes must be a whole number from 1'),
      );
      expect(
        () => _parseSingle(_withCharacter('      strokes: "four"\n')),
        _refusing('character.strokes must be a whole number from 1'),
      );
      expect(
        () => _parseSingle(_withCharacter('      radical: "కగ"\n')),
        _refusing('character.radical must be one character'),
      );
    });

    test(
      'a reading without its text or kind, and an empty level, are refused',
      () {
        expect(
          () => _parseSingle(
            _withCharacter('      readings:\n        - { kind: "first" }\n'),
          ),
          _refusing('missing required field "text"'),
        );
        expect(
          () => _parseSingle(
            _withCharacter('      readings:\n        - { text: "కా" }\n'),
          ),
          _refusing('missing required field "kind"'),
        );
        expect(
          () => _parseSingle(_withCharacter('      level: {}\n')),
          _refusing('character.level must not be empty'),
        );
        expect(
          () => _parseSingle(_withCharacter('      readings: []\n')),
          _refusing('character.readings must not be empty'),
        );
      },
    );

    test('a scheme with no English name, an unknown field, or nothing in it is '
        'refused', () {
      const noEnglish = '''
character_scheme:
  readings:
    first: { name: { es: "Primera" }, script: "latin" }
''';
      const unknown = '''
character_scheme:
  colours: {}
''';
      const empty = '''
character_scheme: {}
''';
      expect(
        () => _parseSingle(_single(_threeCards, scheme: noEnglish)),
        _refusing('character_scheme.readings.first.name needs en'),
      );
      expect(
        () => _parseSingle(_single(_threeCards, scheme: unknown)),
        _refusing('unknown field'),
      );
      expect(
        () => _parseSingle(_single(_threeCards, scheme: empty)),
        _refusing('character_scheme names no readings and no levels'),
      );
    });

    test('a reading kind needs its script', () {
      const noScript = '''
character_scheme:
  readings:
    first: { name: { en: "First" } }
''';
      expect(
        () => _parseSingle(_single(_threeCards, scheme: noScript)),
        _refusing('missing required field "script"'),
      );
    });

    test(
      'CardCharacter has no readings, levels, strokes or radical by default',
      () {
        const empty = CardCharacter();
        expect(empty.readings, isEmpty);
        expect(empty.levels, isEmpty);
        expect(empty.strokes, isNull);
        expect(empty.radical, isNull);
        expect(const CharacterScheme().readingKind('x'), isNull);
      },
    );
  });
}
