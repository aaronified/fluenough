// Card data (DECK-FORMAT.md, Card data): `bases: self`, synonyms and
// antonyms (#513), confusables (#514), frequency and facts naming cards
// (#516), register, forms, collocations and senses (#517). The core holds
// the language's side; each layer the learner's text, by id.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/facts_parser.dart';
import 'package:fluenough/core/models/card.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';

final homeCore = File('$appendix/zz-home.yaml').readAsStringSync();
final homeLayer = File('$appendix/en/zz-en-home.yaml').readAsStringSync();

/// zz-9001, ఇల్లు (illu), with every kind of card data.
const _data = '''
    pos: "noun"
    bases: "self"
    register: "neutral"
    frequency: { rank: 120, source: "te.wikipedia.org, 2026-10" }
    synonyms:
      - { id: "abode", word: "నివాసం", reading: "nivāsaṃ", source: "Wiktionary" }
    antonyms:
      - { id: "out", ref: "zz-9004" }
    collocations:
      - { id: "go", word: "వెళ్ళు", reading: "veḷḷu" }
    confusables:
      - { id: "stem", word: "ఇంటి", reading: "iṇṭi", kind: "form" }
    forms:
      - { id: "pl", kind: "plural", word: "ఇళ్ళు", reading: "iḷḷu" }
    senses:
      - id: "house"
        pos: "noun"
        examples:
          - { target: "ఇల్లు పెద్దది.", reading: "illu peddadi." }
      - { id: "home" }
''';

const _texts = '''
    synonyms: { "abode": "dwelling" }
    collocations: { "go": { native: "to go", note: "Home-ward." } }
    confusables: { "stem": { why: "ఇంటి (iṇṭi) is the stem before an ending." } }
    forms: { "pl": "More than one house." }
    senses:
      "house": { native: "house", examples: { "ఇల్లు పెద్దది.": "The house is big." } }
''';

String coreWith(String data) =>
    homeCore.replaceFirst('    pos: "noun"\n', data);

String layerWith(String texts) => homeLayer.replaceFirst(
  '    wiktionary: true\n',
  '    wiktionary: true\n$texts',
);

Card merged(String data, String texts) => mergeLayer(
  DeckParser.parseCore(coreWith(data), source: 'zz.yaml'),
  DeckParser.parseLayer(layerWith(texts), source: 'en.yaml'),
  source: 'layer.yaml',
).cards.firstWhere((c) => c.id == 'zz-9001');

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  test('a core card keeps its data, and the layer gives its text', () {
    final house = merged(_data, _texts);
    expect(house.ownRoot, isTrue);
    expect(house.bases, isEmpty);
    expect(house.register, 'neutral');
    expect(house.frequency?.rank, 120);
    expect(house.frequency?.source, 'te.wikipedia.org, 2026-10');
    expect(
      house.synonyms.map((i) => (i.id, i.word, i.reading, i.source, i.text)),
      [('abode', 'నివాసం', 'nivāsaṃ', 'Wiktionary', 'dwelling')],
    );
    expect(house.antonyms.single.ref, 'zz-9004');
    expect(house.antonyms.single.text, isNull);
    expect(house.collocations.map((i) => (i.text, i.note)), [
      ('to go', 'Home-ward.'),
    ]);
    expect(house.confusables.single.kind, 'form');
    expect(
      house.confusables.single.text,
      'ఇంటి (iṇṭi) is the stem before an ending.',
    );
    expect(house.forms.map((i) => (i.kind, i.word, i.text)), [
      ('plural', 'ఇళ్ళు', 'More than one house.'),
    ]);
    // A sense the layer gives no meaning is not shown.
    expect(house.senses.map((s) => (s.id, s.native, s.pos)), [
      ('house', 'house', 'noun'),
    ]);
    expect(house.senses.single.examples.single.native, 'The house is big.');
    expect(house.native, 'home; house');
  });

  test('without the layer\'s text, items keep no text', () {
    final house = merged(_data, '');
    expect(house.synonyms.single.text, isNull);
    expect(house.confusables.single.text, isNull);
    expect(house.senses, isEmpty);
  });

  test('a layer names only the core card\'s items and senses', () {
    expect(
      () => merged(_data, '    antonyms: { "in": "inside" }\n'),
      fails('cards.zz-9001.antonyms.in: the core card has no antonyms item'),
    );
    expect(
      () => merged(_data, '    senses: { "x": { native: "x" } }\n'),
      fails('cards.zz-9001.senses.x: the core card has no sense "x"'),
    );
  });

  test('a confusable\'s text is { why }', () {
    expect(
      () => DeckParser.parseLayer(
        layerWith('    confusables: { "stem": "The stem." }\n'),
        source: 'en.yaml',
      ),
      throwsA(isA<DeckParseException>()),
    );
  });

  test('an item gives word or ref, and its id once', () {
    expect(
      () => DeckParser.parseCore(
        coreWith(
          '    pos: "noun"\n'
          '    synonyms: [{ id: "a", word: "x", ref: "zz-9004" }]\n',
        ),
        source: 'zz.yaml',
      ),
      fails('synonyms[0] gives word or ref, one of them'),
    );
    expect(
      () => DeckParser.parseCore(
        coreWith(
          '    pos: "noun"\n'
          '    forms: [{ id: "a", kind: "plural", word: "x", reading: "x" },\n'
          '            { id: "a", kind: "plural", word: "y", reading: "y" }]\n',
        ),
        source: 'zz.yaml',
      ),
      fails('forms[1].id "a" is used twice'),
    );
  });

  test('a frequency\'s rank is a whole number from 1', () {
    expect(
      () => DeckParser.parseCore(
        coreWith('    pos: "noun"\n    frequency: { rank: 0, source: "x" }\n'),
        source: 'zz.yaml',
      ),
      fails('frequency.rank must be a whole number from 1'),
    );
  });

  test('a single-file card takes bases: self, register and frequency', () {
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
    bases: "self"
    register: "neutral"
    frequency: { rank: 3, source: "x" }
''', source: 'zz-en-probe.yaml');
    final pen = deck.cards.single;
    expect(
      (pen.ownRoot, pen.register, pen.frequency?.rank),
      (true, 'neutral', 3),
    );
  });

  test('a fact names its cards', () {
    final facts = parseFacts('''
schema: 1
id: "zz-facts"
kind: "facts"
language: { code: "zz", name: "Testlang" }
facts:
  - id: "zz-fact-001"
    text: { en: "A fact." }
    cards: ["zz-9001", "zz-9004"]
  - id: "zz-fact-002"
    text: { en: "Another." }
''', source: 'zz-facts.yaml');
    expect(facts.facts.map((f) => f.cards), [
      ['zz-9001', 'zz-9004'],
      isEmpty,
    ]);
  });
}
