// A card's examples (#511): the sentence, its reading and IPA and an
// optional per-item source in the core; the translation in each layer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';

final homeCore = File('$appendix/zz-home.yaml').readAsStringSync();
final homeLayer = File('$appendix/en/zz-en-home.yaml').readAsStringSync();

const _house = '''
    pos: "noun"
    examples:
      - target: "ఇల్లు పెద్దది."
        reading: "illu peddadi."
        ipa: "illu peddadi"
        source: "https://tatoeba.org/en/sentences/show/1"
      - { target: "ఇల్లు చిన్నది.", reading: "illu cinnadi." }
''';

/// The core with two examples on zz-9001, the first one sourced.
String coreWith(String examples) =>
    homeCore.replaceFirst('    pos: "noun"\n', examples);

String layerWith(String examples) => homeLayer.replaceFirst(
  '    wiktionary: true\n',
  '    wiktionary: true\n$examples',
);

const _translations =
    '    examples:\n'
    '      "ఇల్లు పెద్దది.": "The house is big."\n'
    '      "ఇల్లు చిన్నది.": "The house is small."\n';

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  group('a core example', () {
    test('keeps its reading, IPA and source', () {
      final core = DeckParser.parseCore(coreWith(_house), source: 'zz.yaml');
      final house = core.cards.first as CoreWritten;
      expect(house.examples.map((e) => e.target), [
        'ఇల్లు పెద్దది.',
        'ఇల్లు చిన్నది.',
      ]);
      expect(house.examples.first.ipa, 'illu peddadi');
      expect(
        house.examples.first.source,
        'https://tatoeba.org/en/sentences/show/1',
      );
      expect(house.examples.last.source, isNull);
    });

    test('an empty source is refused', () {
      expect(
        () => DeckParser.parseCore(
          coreWith(
            _house.replaceFirst(RegExp(r'source: "[^"]*"'), 'source: ""'),
          ),
          source: 'zz.yaml',
        ),
        fails('source'),
      );
    });

    test('merged with the layer, it keeps the core\'s source', () {
      final deck = mergeLayer(
        DeckParser.parseCore(coreWith(_house), source: 'zz.yaml'),
        DeckParser.parseLayer(layerWith(_translations), source: 'en.yaml'),
        source: 'layer.yaml',
      );
      final house = deck.cards.firstWhere((c) => c.id == 'zz-9001');
      expect(house.examples.map((e) => (e.native, e.reading, e.source)), [
        (
          'The house is big.',
          'illu peddadi.',
          'https://tatoeba.org/en/sentences/show/1',
        ),
        ('The house is small.', 'illu cinnadi.', null),
      ]);
      expect(house.examples.first.ipa, 'illu peddadi');
    });

    test('a layer gives no source: it is a fact about the sentence', () {
      expect(
        () => DeckParser.parseLayer(
          layerWith(
            '    examples:\n'
            '      "ఇల్లు పెద్దది.": { native: "Big.", source: "x" }\n',
          ),
          source: 'en.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  test('a single-file example may name its source', () {
    final deck = DeckParser.parse('''
schema: 1
id: "zz-en-probe"
name: "Probe"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-0001"
    target: "కలం"
    reading: "kalam"
    native: "pen"
    examples:
      - { target: "నా కలం.", native: "my pen", source: "Tatoeba #2" }
      - { target: "కలం ఇక్కడ.", native: "The pen is here." }
''', source: 'zz-en-probe.yaml');
    expect(deck.cards.single.examples.map((e) => e.source), [
      'Tatoeba #2',
      null,
    ]);
  });
}
