import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/data/romanisation_parser.dart';

const romanisation = '''
schema: 1
kind: romanisation
id: hi-romanisation
language: hi
scheme: "Popular: lowercase, no length or retroflex marks, spelled as said."
equivalents:
  - ["i", "ee", "ii"]
  - ["v", "w"]
''';

const grammar = '''
schema: 1
id: hi-en-grammar-probe
name: Probe
kind: grammar
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: "Probe"
  slot_name: "person"
  slots: ["मैं", "तुम"]
  prompt: "{lemma} — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      reading: "jana"
      gloss: "to go"
      forms: { "मैं": ["जाता हूँ", "जाती हूँ"], "तुम": null }
      readings: { "मैं": ["jata hun", "jati hun"] }
''';

void main() {
  test('a romanisation file gives its scheme and equivalent spellings', () {
    final file = parseRomanisation(
      romanisation,
      source: 'hi-romanisation.yaml',
    );
    expect(file.language, 'hi');
    expect(file.scheme, startsWith('Popular'));
    expect(file.equivalents, [
      ['i', 'ee', 'ii'],
      ['v', 'w'],
    ]);
  });

  test('a malformed romanisation file is refused', () {
    for (final (text, why) in <(String, String)>[
      (romanisation.replaceFirst('["v", "w"]', '["v"]'), 'two or more'),
      (romanisation.replaceFirst('["v", "w"]', '["v", "Ī"]'), 'lowercase'),
      (romanisation.replaceFirst('["v", "w"]', '["v", "ee"]'), 'two groups'),
      (romanisation.replaceFirst('id: hi-romanisation', 'id: hi'), 'has id'),
    ]) {
      expect(
        () => parseRomanisation(text, source: 'hi-romanisation.yaml'),
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

  test('the catalog reads it, and not as a broken deck', () {
    final catalog = DeckCatalog.parseAll(<String, String>{
      'decks/hi/hi-romanisation.yaml': romanisation,
    });
    expect(catalog.broken, isEmpty);
    expect(catalog.romanisations['hi']!.equivalents, hasLength(2));
  });

  test('a grammar row romanises its lemma and each form, and a cell card '
      'carries its reading', () {
    final deck = DeckParser.parse(grammar, source: 'hi-en-grammar-probe.yaml');
    final entry = deck.pattern!.entries.single;
    expect(entry.reading, 'jana');
    expect(entry.readings, <String, List<String>>{
      'मैं': ['jata hun', 'jati hun'],
    });
    final card = expandPattern(deck).single;
    expect(card.target, 'जाता हूँ');
    expect(card.reading, 'jata hun');
  });

  test(
    'a reading for a slot with no form, or a form with none, is refused',
    () {
      for (final (readings, why) in <(String, String)>[
        ('{ "मैं": "jata hun", "तुम": "jate ho" }', 'has no form'),
        ('{ "हम": "x" }', 'not a slot'),
        ('{}', 'no reading'),
      ]) {
        expect(
          () => DeckParser.parse(
            grammar.replaceFirst(
              '{ "मैं": ["jata hun", "jati hun"] }',
              readings,
            ),
            source: 'hi-en-grammar-probe.yaml',
          ),
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
    },
  );
}
