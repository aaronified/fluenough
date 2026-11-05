// Split out of deck_format_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: card data, refs, grammar patterns, paths.

import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_format_shared.dart';

// From card_data_test.dart.
/// zz-9001, ఇల్లు (illu), with every kind of card data.
const _data = '''
    pos: "noun"
    bases: "self"
    register: "neutral"
    frequency: { rank: 120, source: "te.wikipedia.org, 2026-10" }
    synonyms:
      - { id: "abode", word: "నివాసం", reading: "nivāsaṃ", ipa: "niʋaːsam", source: "Wiktionary" }
    antonyms:
      - { id: "out", ref: "zz-9004" }
    collocations:
      - { id: "go", word: "వెళ్ళు", reading: "veḷḷu" }
    confusables:
      - { id: "stem", word: "ఇంటి", reading: "iṇṭi", ipa: "iɳʈi", kind: "form", source: "Wiktionary" }
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

// From card_refs_test.dart.
/// A deck of [cards] in Spanish, taught from [native].
String refVocab(
  String id,
  String cards, {
  String native = 'en',
  String? theme,
}) {
  final name = native == 'en' ? 'eng, name: English' : 'ben, name: Bengali';
  return '''
schema: 1
id: $id
name: Probe
${theme == null ? '' : 'theme: $theme\n'}language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: $native, iso639_3: $name }
license: CC0-1.0
cards:
$cards''';
}

const String written = '''
  - id: es-0001
    target: "perro"
    native: "dog"
    alt_target: ["can"]
    notes: "Also a hot dog."
    tags: ["animals"]
  - id: es-0002
    target: "gato"
    native: "cat"
''';

// From pattern_expander_test.dart.
/// Spanish's deck [name], its core and its English layer merged: the deck
/// the app teaches an English speaker, as the single file it once was.
Deck spanish(String name) => mergeLayer(
  DeckParser.parseCore(
    File('decks/es/es-$name.yaml').readAsStringSync(),
    source: 'es-$name.yaml',
  ),
  DeckParser.parseLayer(
    File('decks/es/en/es-en-$name.yaml').readAsStringSync(),
    source: 'es-en-$name.yaml',
  ),
  source: 'es-en-$name.yaml',
);

// From course_path_test.dart.
String pathFile(String units) => '''
schema: 1
kind: path
id: hi-path
language: hi
units:
$units''';

/// [text]'s path as learners from English are taught it, where every deck
/// it names exists in English.
CoursePath fromEnglish(String text) =>
    parseLanguagePath(text).forNative('en', exists: (_) => true);

CoursePath fromEnglishPath(LanguagePath language) =>
    language.forNative('en', exists: (_) => true);

Matcher refusing(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('card data', () {
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
      expect(house.synonyms.single.ipa, 'niʋaːsam');
      // Every item may take ipa and source (owner, 2026-10-15, #506).
      expect(house.confusables.single.kind, 'form');
      expect(house.confusables.single.ipa, 'iɳʈi');
      expect(house.confusables.single.source, 'Wiktionary');
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

    test('a core card says which warning its teach card shows (#691)', () {
      Card withWarning(String? value) => merged(
        value == null
            ? '    pos: "noun"\n'
            : '    pos: "noun"\n    warning: "$value"\n',
        '',
      );
      expect(withWarning('stem').warning, 'stem');
      expect(withWarning('senses').warning, 'senses');
      expect(withWarning('none').warning, 'none');
      expect(withWarning(null).warning, isNull);
    });

    test('a core card lists the offensive words it is not alike (#808)', () {
      final card = DeckParser.parseCore(
        coreWith(
          '    pos: "noun"\n'
          '    not_sounds_like: ["zz-0002"]\n'
          '    not_looks_like: ["zz-0002", "zz-0003"]\n',
        ),
        source: 'zz.yaml',
      ).cards.whereType<CoreWritten>().first;
      expect(card.notSoundsLike, ['zz-0002']);
      expect(card.notLooksLike, ['zz-0002', 'zz-0003']);
      expect(
        () => parseProbe(probeCard('    not_sounds_like: ["zz-0002"]\n')),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('an empty warning, or one on a card of a single file, is refused', () {
      expect(
        () => DeckParser.parseCore(
          coreWith('    pos: "noun"\n    warning: ""\n'),
          source: 'zz.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
      // The key belongs to the core's language side, not to a single-file
      // deck's card.
      expect(
        () => parseProbe(probeCard('    warning: "none"\n')),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('refs', () {
    group('refs (ADR-0018)', () {
      test('the catalog lists the written card in the ref\'s place, with '
          'what the ref gives', () {
        final catalog = DeckCatalog.parseAll({
          'decks/es/es-en-a.yaml': refVocab('es-en-a', written),
          'decks/es/es-en-b.yaml': refVocab(
            'es-en-b',
            '  - ref: es-0001\n    notes: "Barks."\n'
                '  - id: es-0003\n    target: "pez"\n    native: "fish"\n'
                '  - ref: es-0002\n'
                '  - id: es-0004\n    target: "pato"\n    native: "duck"\n',
            theme: 'pets',
          ),
        });
        final b = catalog.byId('es-en-b')!.deck;
        expect(b.theme, 'pets', reason: 'resolving keeps the deck as it was');
        expect(b.refs, isEmpty);
        expect(b.cards.map((c) => c.id), [
          'es-0001',
          'es-0003',
          'es-0002',
          'es-0004',
        ], reason: 'each ref in its own place, between written cards');
        final dog = b.cards[0];
        expect(dog.deckId, 'es-en-b');
        expect(dog.target, 'perro');
        expect(dog.altTarget, ['can'], reason: 'the card\'s own');
        expect(dog.native, 'dog', reason: 'the same native, inherited');
        expect(dog.tags, ['animals']);
        expect(dog.notes.single.text, 'Barks.', reason: 'given by the ref');
      });
    });
  });

  group('grammar patterns', () {
    final bundled = spanish('grammar-present-ar');

    test('a pattern without a prompt asks the lemma, its meaning and the '
        'slot; one that gives a prompt is asked as written', () {
      String deck(String prompt) =>
          '''
schema: 1
id: es-en-grammar-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: [yo]
$prompt  entries:
    - lemma: soler
      gloss: to tend to
      forms: { yo: suelo }
''';
      expect(
        expandPattern(DeckParser.parse(deck(''), source: 'probe'))
            .single
            .native,
        'soler (to tend to) \u2014 yo',
      );
      expect(
        expandPattern(
          DeckParser.parse(
            deck('  prompt: "{slot}: {lemma}"\n'),
            source: 'probe',
          ),
        ).single.native,
        'yo: soler',
      );
    });

    test('cell ids follow the documented scheme and are stable; a null form '
        'is skipped, its slot keeping its index', () {
      final first = [for (final c in expandPattern(bundled)) c.id];
      final again = [for (final c in expandPattern(bundled)) c.id];
      expect(again, first);
      expect(first.toSet(), hasLength(first.length), reason: 'unique');
      for (final id in first) {
        expect(id, matches(RegExp(r'^es-grammar-present-ar-[a-z]+-[0-5]$')));
      }

      final deck = DeckParser.parse('''
schema: 1
id: es-en-grammar-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: [yo, tú, él]
  prompt: "{slot} of {lemma}, {gloss}"
  entries:
    - lemma: soler
      gloss: to tend to
      forms: { yo: suelo, tú: null, él: suele }
''', source: 'probe');
      final cards = expandPattern(deck);
      expect(cards.map((c) => c.id), [
        'es-grammar-probe-soler-0',
        'es-grammar-probe-soler-2',
      ]);
      expect(cards.last.native, 'él of soler, to tend to');
    });
  });

  group('paths', () {
    test('reads the units in order; a unit may end in "*", and a unit of '
        '"*" alone is the last', () {
      final language = parseLanguagePath(
        pathFile(
          '  - [hi-first-words, hi-grammar-sentences]\n'
          '  - [hi-questions]\n',
        ),
      );
      expect(language.id, 'hi-path');
      expect(language.language, 'hi');
      expect(language.plan.map((u) => u.decks), [
        ['hi-first-words', 'hi-grammar-sentences'],
        ['hi-questions'],
      ]);

      final path = fromEnglish(
        pathFile(
          '  - [hi-script-vowels]\n'
          '  - [hi-market, hi-grammar-nouns, "*"]\n'
          '  - [hi-home, "*"]\n'
          '  - ["*"]\n',
        ),
      );
      expect(path.units, [
        ['hi-en-script-vowels'],
        ['hi-en-market', 'hi-en-grammar-nouns'],
        ['hi-en-home'],
        <String>[],
      ]);
      expect(path.open, {1, 2, 3});
      expect(path.deckIds, contains('hi-en-home'));
      expect(path.deckIds, isNot(contains('*')));

      for (final (units, why) in <(String, String)>[
        ('  - ["*", hi-market]\n', 'can only end a unit'),
        ('  - [hi-market, "*", "*"]\n', 'can only end a unit'),
        ('  - ["*"]\n  - [hi-market]\n', 'alone can only be the last'),
      ]) {
        expect(
          () => parseLanguagePath(pathFile(units)),
          refusing(why),
          reason: units,
        );
      }
    });

    test('a path may give its own words per level, which are the B1 total; '
        'without them the units\' sizes are', () {
      const units =
          '  - decks: [hi-first-words]\n    words: 40\n    milestone: A1\n'
          '  - decks: [hi-market]\n    words: 30\n    milestone: A2\n'
          '  - decks: [hi-home]\n    words: 20\n    milestone: B1\n';
      expect(parseLanguagePath(pathFile(units)).plannedWords, 90);
      final own = parseLanguagePath(
        '${pathFile(units)}levels: { A1: 120, A2: 60, B1: 80 }\n',
      );
      expect(own.levels, {
        Milestone.a1: 120,
        Milestone.a2: 60,
        Milestone.b1: 80,
      });
      expect(own.plannedWords, 260);
      expect(fromEnglishPath(own).plannedWords, 260);

      for (final (levels, why) in <(String, String)>[
        ('levels: { A1: 120, A2: 60 }', 'levels needs B1'),
        ('levels: { A1: 120, A2: 60, B1: 80, C1: 5 }', 'unknown level "C1"'),
        ('levels: { A1: 0, A2: 60, B1: 80 }', 'levels.A1 must be a whole'),
        ('levels: { A1: "9", A2: 60, B1: 80 }', 'levels.A1 must be a whole'),
        ('levels: [120, 60, 80]', 'levels must be a mapping'),
      ]) {
        expect(
          () => parseLanguagePath('${pathFile(units)}$levels\n'),
          refusing(why),
          reason: levels,
        );
      }
    });

    test('a planned theme unit may plan no new roots: words 0', () {
      String theme(int words) => pathFile(
        '  - planned: { id: hi-colours, theme: colours, words: $words }\n'
        '    listening_passages:\n'
        '      - { id: heard, text: { en: "Heard" } }\n'
        '    reading_passages:\n'
        '      - { id: read, text: { en: "Read" } }\n',
      );
      expect(parseLanguagePath(theme(0)).plan.single.words, 0);
      expect(() => parseLanguagePath(theme(-1)), refusing('0 or more'));
    });

    group('one path, every native language', () {
      final language = parseLanguagePath(
        pathFile(
          '  - [hi-first-words, hi-grammar-sentences, "*"]\n'
          '  - [hi-sound-differences]\n'
          '  - [hi-market, "*"]\n'
          '  - ["*"]\n',
        ),
      );
      // English teaches every unit; Bengali has two decks so far.
      const bengali = <String>{'hi-bn-first-words', 'hi-bn-market'};
      final fromBengali = language.forNative('bn', exists: bengali.contains);

      test('a written unit with no deck in the native language is coming, '
          'and out of units and open', () {
        expect(fromBengali.open, {0, 1, 2});
        expect(fromBengali.plan.map((u) => u.isComing), [
          false,
          true,
          false,
          false,
        ]);
        expect(fromBengali.plan[1].decks, isEmpty);
        // Placing an added deck does not take the coming unit for "*" alone.
        final placed = fromBengali.placing(<({String id, String? theme})>[
          (id: 'hi-bn-my-words', theme: null),
        ], (_) => null);
        expect(placed.units.last, ['hi-bn-my-words']);
      });
    });
  });
}
