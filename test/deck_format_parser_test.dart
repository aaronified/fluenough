// Split out of deck_format_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the parser, cores, layers and rules.

import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_format_shared.dart';

/// The 1-based line of the [occurrence]th line of [yaml] containing [needle].
int lineOf(String yaml, String needle, {int occurrence = 1}) {
  final lines = yaml.split('\n');
  var seen = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(needle) && ++seen == occurrence) return i + 1;
  }
  throw StateError('"$needle" does not occur $occurrence times');
}

/// A [DeckParseException] at [line] whose message contains all of [mentions]
/// and none of [omits]. A null [line] means no position at all.
Matcher throwsParseError({
  required int? line,
  List<String> mentions = const [],
  List<String> omits = const [],
}) {
  var matcher = isA<DeckParseException>().having((e) => e.line, 'line', line);
  if (line == null) {
    matcher = matcher.having((e) => e.column, 'column', isNull);
  }
  for (final text in mentions) {
    matcher = matcher.having((e) => e.message, 'message', contains(text));
  }
  for (final text in omits) {
    matcher = matcher.having(
      (e) => e.message,
      'message',
      isNot(contains(text)),
    );
  }
  return throwsA(matcher);
}

/// A valid grammar deck, with a defective verb to show null forms.
const grammar = '''
schema: 1
id: test-grammar
name: Test grammar
kind: grammar
language: {code: es, iso639_3: spa, name: Spanish, script: latin}
native: {code: en, iso639_3: eng, name: English}
license: CC0-1.0
pattern:
  name: Present tense
  slot_name: person
  slots: [yo, tú, él]
  prompt: "{lemma} ({gloss}) — {slot}"
  notes: Regular -ar endings.
  entries:
    - lemma: hablar
      gloss: to speak
      forms:
        yo: hablo
        tú: hablas
        él: habla
    - lemma: llover
      gloss: to rain
      forms:
        yo: null
        tú: ~
        él: llueve
''';

DeckCore coreOf(String text, {String source = 'zz-core.yaml'}) =>
    DeckParser.parseCore(text, source: source);

DeckLayer layerOf(String text, {String source = 'zz-en-layer.yaml'}) =>
    DeckParser.parseLayer(text, source: source);

/// The core and layer texts merged, as the catalog merges them.
Deck merge(String core, String layer) =>
    mergeLayer(coreOf(core), layerOf(layer), source: 'layer.yaml');

/// Fails with a [DeckParseException] whose message contains [why].
Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

/// Every file under [root], keyed as the catalog keys bundled decks:
/// `decks/zz/en/zz-en-home.yaml`.
Map<String, String> tree(String root) => <String, String>{
  for (final file in Directory(root).parent.listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(Directory(root).parent.path.length + 1)}':
          file.readAsStringSync(),
};

final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');
final marketCore = read('$features/zz-market.yaml');
final marketLayer = read('$features/en/zz-en-market.yaml');
final marketBengali = read('$features/bn/zz-bn-market.yaml');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the parser', () {
    group('a valid vocab deck', () {
      test('maps every field', () {
        final deck = parse('''
schema: 1
id: test-full
name: Full deck
kind: vocab
description: Every field, once.
language: {code: ar, iso639_3: arb, name: Arabic, script: arabic, tts: ar-EG, rtl: true}
native:
  code: en
  iso639_3: eng
  name: English
license: CC-BY-SA-4.0
authors:
  - name: Ada
    url: https://example.org/ada
  - name: Grace
source: https://example.org/words
tags: [beginner, core]
cards:
  - id: test-full-0001
    target: بيت
    native: house
    reading: bayt
    alt_target: [منزل]
    alt_native: [home, dwelling]
    pos: noun
    gender: m
    tags: [home]
    notes: Also a line of verse.
    audio: audio/bayt.ogg
    examples:
      - target: هذا بيت.
        native: This is a house.
    modes: [recognition, listening]
''');

        expect(deck.id, 'test-full');
        expect(deck.name, 'Full deck');
        expect(deck.kind, DeckKind.vocab);
        expect(deck.description, 'Every field, once.');
        expect(deck.license, 'CC-BY-SA-4.0');
        expect(deck.source, 'https://example.org/words');
        expect(deck.tags, ['beginner', 'core']);
        expect(deck.pattern, isNull);

        expect(deck.authors.map((a) => a.name), ['Ada', 'Grace']);
        expect(deck.authors.map((a) => a.url), [
          'https://example.org/ada',
          null,
        ]);

        expect(deck.language.code, 'ar');
        expect(deck.language.name, 'Arabic');
        expect(deck.language.script, 'arabic');
        expect(deck.language.tts, 'ar-EG');
        expect(deck.language.rtl, isTrue);
        expect(deck.native.code, 'en');
        expect(deck.native.name, 'English');

        final card = deck.cards.single;
        expect(card.id, 'test-full-0001');
        expect(card.deckId, 'test-full');
        expect(card.target, 'بيت');
        expect(card.native, 'house');
        expect(card.reading, 'bayt');
        expect(card.altTarget, ['منزل']);
        expect(card.altNative, ['home', 'dwelling']);
        expect(card.pos, 'noun');
        expect(card.gender, 'm');
        expect(card.tags, ['home']);
        expect(card.notes.single.text, 'Also a line of verse.');
        expect(card.audio, 'audio/bayt.ogg');
        expect(card.examples.single.target, 'هذا بيت.');
        expect(card.examples.single.native, 'This is a house.');
        expect(card.modes, {DrillMode.recognition, DrillMode.listening});
      });
    });

    group('malformed YAML', () {
      test('errors start with the source, line and column, at the line the '
          'YAML parser stopped at', () {
        final yaml = vocab().replaceFirst(
          '    native: the house',
          '   native: the house',
        );
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'native: the house'),
            mentions: ['not valid YAML'],
          ),
        );

        {
          final yaml = vocab().replaceFirst(
            'native: the house',
            'native: false',
          );
          try {
            DeckParser.parse(yaml, source: 'es-en-core-100.yaml');
            fail('expected a DeckParseException');
          } on DeckParseException catch (e) {
            expect(e.source, 'es-en-core-100.yaml');
            expect(e.line, lineOf(yaml, 'native: false'));
            expect(e.column, 13);
            expect(
              e.toString(),
              'es-en-core-100.yaml:${e.line}:13: ${e.message}',
            );
          }
        }
      });
    });

    group('a missing required field', () {
      test('a missing field is refused, at the top level or on a card', () {
        final yaml = vocab().replaceFirst('license: CC0-1.0\n', '');
        expect(
          () => parse(yaml),
          throwsParseError(line: 1, mentions: ['missing', '"license"']),
        );

        {
          final yaml = vocab().replaceFirst('    native: the house\n', '');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'id: test-0001'),
              mentions: ['cards[0]', 'missing', '"native"'],
            ),
          );
        }
      });
    });

    group('an unknown field', () {
      test('an unknown field is refused, on a card or at the top level', () {
        final yaml = vocab(cards: '$oneCard    colour: red\n');
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'colour'),
            mentions: ['cards[0]', 'unknown field', '"colour"'],
          ),
        );

        {
          // `level` is a deck kind field now (deck_kinds.dart): read, never
          // refused. Any other key is still unknown.
          final yaml = vocab(extra: 'difficulty: beginner\n');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'difficulty'),
              mentions: ['unknown field', '"difficulty"'],
            ),
          );
        }
      });
    });

    group('the YAML traps', () {
      test('a bare false or 007 is refused, saying to quote it; a bare no, or '
          'a quoted one, is text', () {
        final yaml = vocab().replaceFirst('native: the house', 'native: false');
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'native: false'),
            mentions: [
              'cards[0].native',
              'boolean false',
              'YAML reads a bare true or false as a boolean',
              'Quote it: "false"',
            ],
          ),
        );

        final card = parse(vocab(cards: '$oneCard    reading: no\n'))
            .cards
            .single;
        expect(card.reading, 'no');

        {
          final yaml = vocab().replaceFirst('target: la casa', 'target: 007');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'target: 007'),
              mentions: ['cards[0].target', 'number', 'Quote it: "007"'],
            ),
          );
        }

        {
          final card = parse(
            vocab()
                .replaceFirst('target: la casa', 'target: "007"')
                .replaceFirst('native: the house', 'native: "no"'),
          ).cards.single;
          expect(card.target, '007');
          expect(card.native, 'no');
        }
      });

      // tools/validate_decks.py reads plain scalars by YAML 1.2's core schema
      // (its DeckResolver). A deck CI accepts must parse here, and read the
      // same, so the parser retypes plain scalars by the same patterns.
      test('unquoted values are typed as YAML 1.2 types them, and what only '
          'YAML 1.1 reads as a number is text', () {
        final deck = parse(
          vocab(
            cards: '''
  - id: test-0001
    target: 1:30
    native: !!str 007
''',
          ).replaceFirst('script: latin}', 'script: latin, rtl: True}'),
        );
        expect(deck.language.rtl, isTrue);
        expect(deck.cards.single.target, '1:30');
        expect(deck.cards.single.native, '007');

        // 08 is the number 8 in YAML 1.2; YAML 1.1 read it as text.
        final yaml = vocab().replaceFirst('native: the house', 'native: 08');
        expect(
          () => parse(yaml),
          throwsParseError(line: lineOf(yaml, '08'), mentions: ['number']),
        );

        for (final text in [
          '0b11',
          '1:30.5',
          '1_000',
          '+0x1F',
          '-0x1F',
          '0O17',
          '-.nan',
          '1e',
          '2001-12-14',
          '=',
        ]) {
          final card = parse(vocab().replaceFirst('la casa', text))
              .cards
              .single;
          expect(card.target, text, reason: text);
        }
      });
    });

    group('the id checks', () {
      test('a duplicate card id, a badly formed deck or card id', () {
        final yaml = vocab(cards: '$oneCard$oneCard');
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'id: test-0001', occurrence: 2),
            mentions: [
              'cards[1].id',
              'duplicate card id "test-0001"',
              'first used on line ${lineOf(yaml, 'id: test-0001')}',
            ],
          ),
        );

        {
          final yaml = vocab().replaceFirst('id: test-deck', 'id: Test_Deck');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'Test_Deck'),
              mentions: ['id must be', '"Test_Deck"'],
            ),
          );
        }

        {
          final yaml = vocab().replaceFirst('id: test-0001', 'id: test--0001');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'test--0001'),
              mentions: ['cards[0].id must be', '"test--0001"'],
            ),
          );
        }
      });

      test('a pattern\'s slots and forms: a duplicate slot, a missing one, all '
          'null', () {
        final yaml = grammar.replaceFirst('[yo, tú, él]', '[yo, tú, yo]');
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'slots:'),
            mentions: ['pattern.slots[2]', 'duplicate slot "yo"'],
          ),
        );

        {
          final yaml = grammar.replaceFirst('        tú: hablas\n', '');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'yo: hablo'),
              mentions: ['pattern.entries[0].forms', 'missing slot "tú"'],
            ),
          );
        }

        {
          final yaml = grammar.replaceFirst('él: llueve', 'él: null');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'yo: null'),
              mentions: ['pattern.entries[1].forms', 'every form is null'],
            ),
          );
        }
      });
    });

    group('the kind rules', () {
      test(
        'a deck\'s kind decides what it holds: a vocab deck has cards and no '
        'pattern, a grammar deck a pattern and no cards',
        () {
          final yaml = vocab(extra: 'pattern: {}\n');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'pattern:'),
              mentions: ['only for a grammar deck'],
            ),
          );

          {
            final yaml = '${grammar}cards:\n$oneCard';
            expect(
              () => parse(yaml),
              throwsParseError(
                line: lineOf(yaml, 'cards:'),
                mentions: ['a grammar deck has a pattern, not cards'],
              ),
            );
          }

          {
            final yaml = vocab(cards: '')
                .replaceFirst('cards:\n', 'cards: []\n');
            expect(
              () => parse(yaml),
              throwsParseError(
                line: lineOf(yaml, 'cards:'),
                mentions: ['cards must not be empty'],
              ),
            );
          }
        },
      );
    });

    group('language codes', () {
      test('iso639_3 is required on both language blocks, as three lowercase '
          'letters', () {
        for (final (line, code) in [(4, 'spa'), (5, 'eng')]) {
          expect(
            () => parse(vocab().replaceFirst('iso639_3: $code, ', '')),
            throwsParseError(line: line, mentions: ['iso639_3']),
            reason: code,
          );
        }

        for (final bad in ['es', 'spain', 'SPA', 's1a', '"spa\\n"']) {
          expect(
            () =>
                parse(vocab().replaceFirst('iso639_3: spa', 'iso639_3: $bad')),
            throwsParseError(line: 4, mentions: ['ISO 639-3']),
            reason: bad,
          );
        }
      });
    });
  });

  group('cores, layers and rules', () {
    group('typed notes (6.1)', () {
      test('ids, kinds, sources and words', () {
        final notes = parseProbe(
          probeCard('''
    notes:
      - { id: "school", kind: "culture", text: "A gift.", source: "A book, 1990" }
      - { kind: "behaviour", text: "{1} and {2}.", words: [{ word: "కలాలు", reading: "kalālu" }, { word: "-లు" }] }
      - { kind: "note", text: "Literal {x}, { 1 } and {." }
'''),
        ).cards.single.notes;
        expect(notes.map((n) => n.id), ['school', '2', '3']);
        expect(notes.first.source, 'A book, 1990');
        expect(notes[1].text, 'కలాలు (kalālu) and -లు.');
        expect(notes[2].text, 'Literal {x}, { 1 } and {.');
      });

      test('homograph and lookalike notes name another card', () {
        final notes = parseProbe(
          probeCard('''
    notes:
      - { kind: "homograph", ref: "zz-9004", text: "Same spelling." }
      - { kind: "lookalike", ref: "zz-9004", text: "A dot apart." }
'''),
        ).cards.single.notes;
        expect(notes.map((n) => n.kind), [
          NoteKind.homograph,
          NoteKind.lookalike,
        ]);
        expect(notes.map((n) => n.ref), ['zz-9004', 'zz-9004']);
      });

      test('a layer entry may carry a Wiktionary dictionary entry', () {
        final deck = merge(
          homeCore,
          homeLayer.replaceFirst(
            '    native: "home; house"\n',
            '    native: "home; house"\n'
                '    dictionary: { senses: ["household"], '
                'etymology: "Old.", '
                'source: "https://en.wiktionary.org/wiki/x" }\n',
          ),
        );
        expect(deck.cards.first.native, 'home; house');
      });
    });

    group('layers (2.6)', () {
      test('a malformed layer is refused', () {
        for (final (yaml, why) in <(String, String)>[
          (
            homeLayer.replaceFirst(
              'name: "Home"',
              'language: { code: "zz" }\nname: "Home"',
            ),
            'a layer takes its language from its core, zz-home',
          ),
          (
            homeLayer.replaceFirst(
              'name: "Home"',
              'theme: "home"\nname: "Home"',
            ),
            'a layer takes its theme from its core, zz-home',
          ),
          (
            homeLayer.replaceFirst('core: "zz-home"', 'core: "Zz Home"'),
            "core must be the id of a core file, such as 'te-home', got "
                '"Zz Home"',
          ),
          (
            homeLayer.replaceFirst('kind: "layer"', 'kind: "vocab"'),
            'a layer is marked kind: "layer", got "vocab"',
          ),
          (
            homeLayer.replaceFirst(RegExp(r'cards:\n[\s\S]*$'), 'cards: []\n'),
            "cards: a layer's cards is a mapping of card id to what this "
                'language gives it',
          ),
          (
            homeLayer.replaceFirst('  "zz-9001":', '  1:'),
            'cards: key 1 was read as int; quote it',
          ),
          (
            homeLayer.replaceFirst(
              '    native: "mother"\n',
              '    native: "mother"\n    reading: "amma"\n',
            ),
            'cards.zz-9004: "reading" belongs to the word, in the core; a layer '
                'gives native, alt_native, notes, examples, bases, wiktionary and '
                'dictionary',
          ),
          (
            homeLayer.replaceFirst(
              '      "address": "Also',
              '      true: "Also',
            ),
            'key True was read as bool; quote it',
          ),
          (
            homeLayer.replaceFirst(
              '    native: "mother"\n',
              '    native: "mother"\n    wiktionary: false\n',
            ),
            'wiktionary must be true',
          ),
        ]) {
          expect(() => layerOf(yaml), fails(why), reason: why);
        }
      });
    });

    group('mergeLayer (2.7)', () {
      test('Appendix A: the core\'s words with the layer\'s meanings', () {
        final deck = merge(homeCore, homeLayer);
        expect(deck.id, 'zz-en-home');
        expect(deck.name, 'Home');
        expect(deck.kind, DeckKind.vocab);
        expect(deck.language.code, 'zz');
        expect(deck.native.code, 'en');
        expect(deck.license, 'CC-BY-SA-4.0');
        expect(deck.tags, ['unreviewed']);
        expect(deck.refs, isEmpty);
        expect(deck.cards.map((c) => c.id).take(5), [
          'zz-9001',
          'zz-9004',
          'zz-9006',
          'zz-9003',
          'zz-9002',
        ]);
        expect(deck.cards, hasLength(20));
        final home = deck.cards.first;
        expect(home.deckId, 'zz-en-home');
        expect(home.target, 'ఇల్లు');
        expect(home.reading, 'illu');
        expect(home.native, 'home; house');
        expect(home.pos, 'noun');
        expect(home.wiktionary, isTrue);
        expect(
          home.notes.single.text,
          'Before an ending it becomes ఇంటి- (iṇṭi-), as in ఇంట్లో (iṇṭlō), at '
          'home.',
        );
        expect(home.notes.single.kind, NoteKind.behaviour);
        expect(
          deck.cards[3].notes.single.text,
          'I will go is వెళ్తాను (veḷtānu).',
        );
        final sentence = deck.cards[4];
        expect(sentence.rules, ['zz-rule-ki']);
        expect(sentence.bases.map((b) => b.ref), ['zz-9001', 'zz-9003']);
        expect(deck.cards.where((c) => c.phrasebook), hasLength(15));
        expect(deck.cards.last.native, 'Mother 15!');
      });

      test('cards skipped, refs placed, layer-only cards appended', () {
        final deck = merge(marketCore, marketLayer);
        expect(deck.cards.map((c) => c.id), [
          'zz-9301',
          'zz-9302',
          'zz-9303',
          'zz-9305',
          'zz-9501',
        ]);
        // zz-9304 has no English entry, so it is not counted before a ref.
        expect(deck.refs.map((r) => (r.id, r.position)), [
          ('zz-9401', 3),
          ('zz-9402', 4),
        ]);
        expect(deck.refs.first.native, isNull);
        expect(deck.refs.first.notes, isNull);
        expect(deck.refs.last.notes!.single.text, 'Said of any fruit.');
        expect(deck.refs.last.examples, isEmpty, reason: 'no translation');

        // A layer may give a ref its own meaning, its mark, and texts for the
        // notes and examples the core's ref gives.
        final own = merge(
          marketCore,
          marketLayer.replaceFirst(
            '  "zz-9402":\n    notes:\n',
            '  "zz-9401":\n    native: "drinking water"\n    wiktionary: true\n'
                '  "zz-9402":\n    examples: { "పండు తిను.": "Eat fruit." }\n'
                '    notes:\n',
          ),
        );
        expect(own.refs.first.native, 'drinking water');
        expect(own.refs.first.wiktionary, isTrue);
        expect(own.refs.last.wiktionary, isNull);
        expect(own.refs.last.examples!.single.native, 'Eat fruit.');
        expect(own.refs.last.examples!.single.reading, 'paṇḍu tinu.');

        final bengali = merge(marketCore, marketBengali);
        expect(bengali.cards.map((c) => (c.id, c.native)), [
          ('zz-9301', 'কলম'),
          ('zz-9304', 'বাজার'),
        ]);
        expect(bengali.refs.map((r) => (r.id, r.position)), [
          ('zz-9401', 2),
          ('zz-9402', 3),
        ]);
        expect(bengali.refs.last.notes, isEmpty, reason: 'no Bengali text');
      });
    });

    group('rules decks: expansion into cells (4.6)', () {
      final home = merge(homeCore, homeLayer);
      Card? wordOf(String id) =>
          home.cards.where((c) => c.id == id).firstOrNull;
      List<Card> cells(
        String core,
        String layer, {
        Card? Function(String)? of,
      }) => expandRules(merge(core, layer), wordOf: of ?? wordOf);

      test('one card per filled cell, its id from the row and the slot', () {
        final cards = cells(rulesCore, rulesLayer);
        expect(cards.map((c) => c.id), [
          for (final row in ['9001', '9004'])
            for (var i = 0; i < 4; i++) 'zz-grammar-case-endings-$row-$i',
        ]);
        final withMother = cards[6];
        expect(withMother.target, 'అమ్మతో');
        expect(withMother.reading, 'ammatō');
        expect(withMother.deckId, 'zz-en-grammar-case-endings');
        expect(withMother.modes, DrillMode.vocabulary);
        expect(withMother.notes, isEmpty);
      });
    });

    group('the catalog loads cores and layers (9.6)', () {
      test('refs resolve through the layer of their own native language', () {
        final catalog = DeckCatalog.parseAll(tree(features));
        expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
        expect(catalog.byId('zz-market'), isNull);
        expect(catalog.byId('zz-grammar-past'), isNull);

        final market = catalog.byId('zz-en-market')!.cards;
        expect(market.map((c) => c.id), [
          'zz-9301',
          'zz-9302',
          'zz-9303',
          'zz-9401',
          'zz-9402',
          'zz-9305',
          'zz-9501',
        ]);
        final fruit = market[4];
        expect(fruit.native, 'fruit', reason: 'from zz-en-words, same native');
        expect(fruit.notes.single.text, 'Said of any fruit.');
        expect(fruit.examples, isEmpty);
        expect(fruit.wiktionary, isTrue, reason: 'the written card\'s mark');
        expect(fruit.deckId, 'zz-en-market');

        // The Bengali layer gives zz-9401 no native, and its card is English.
        expect(catalog.byId('zz-bn-market')!.cards.map((c) => c.id), [
          'zz-9301',
          'zz-9304',
        ]);

        final words = catalog.byId('zz-en-words')!.cards;
        final pen = words.firstWhere((c) => c.id == 'zz-9301');
        expect(pen.native, 'pen', reason: 'the English layer, not the Bengali');
        expect(pen.wiktionary, isTrue);
        expect(pen.notes.map((n) => n.id), ['pair', 'plural']);
        expect(pen.pair, 'zz-9302');
        expect(pen.deckId, 'zz-en-words');
        final time = words.firstWhere((c) => c.id == 'zz-9302');
        expect(time.wiktionary, isTrue, reason: 'the ref\'s own');

        final past = catalog.byId('zz-en-grammar-past')!.cards;
        expect(past.map((c) => c.id), [
          'zz-grammar-past-vellu-0',
          'zz-grammar-past-vellu-1',
        ]);
      });

      test(
        'a layer that does not fit its core is broken, and the rest load',
        () {
          final files = tree(appendix)
            ..['decks/zz/en/zz-en-home.yaml'] = homeLayer.replaceFirst(
              '      "drop":',
              '      "fall":',
            );
          final catalog = DeckCatalog.parseAll(files);
          expect(catalog.broken.single.path, 'decks/zz/en/zz-en-home.yaml');
          expect(
            catalog.byId('zz-en-grammar-case-endings')!.cards,
            isEmpty,
            reason: 'its rows\' words are not taught from English',
          );
        },
      );
    });
  });
}
