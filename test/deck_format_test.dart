// The deck format, in the app: what the app's parser does with what a deck
// author writes. The YAML traps, missing and unknown fields with their line
// and column, id and kind rules, iso639_3; a core merged with its layer,
// refs through the layer of their native language, rules expanded to
// stable cell ids; paths, reading decks, target scripts, guide layers; and
// every deck the index lists parses.

import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

// From deck_parser_test.dart.
Deck parse(String yaml) => DeckParser.parse(yaml, source: 'test.yaml');

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

const header = '''
schema: 1
id: test-deck
name: Test deck
language: {code: es, iso639_3: spa, name: Spanish, script: latin}
native: {code: en, iso639_3: eng, name: English}
license: CC0-1.0
''';

const oneCard = '''
  - id: test-0001
    target: la casa
    native: the house
''';

/// A valid vocab deck around [cards], with [extra] header lines.
String vocab({String cards = oneCard, String extra = ''}) =>
    '$header${extra}cards:\n$cards';

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

// From b1_format_test.dart.
const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';

String read(String path) => File(path).readAsStringSync();

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

/// A single-file Testlang deck taught from English, with [cards].
String single(String cards) => '''
schema: 1
id: "zz-en-probe"
name: "Probe"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
cards:
$cards''';

/// One single-file card with [extra] fields, for the card checks.
String probeCard(String extra) => single('''
  - id: "zz-0001"
    target: "కలం"
    reading: "kalam"
    native: "pen"
$extra''');

Deck parseProbe(String yaml) =>
    DeckParser.parse(yaml, source: 'zz-en-probe.yaml');

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');
final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');
final marketCore = read('$features/zz-market.yaml');
final marketLayer = read('$features/en/zz-en-market.yaml');
final marketBengali = read('$features/bn/zz-bn-market.yaml');
final words = read('$features/zz-en-words.yaml');

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

// From reading_parser_test.dart.
/// Reading decks (#98, ADR-0019): `kind: reading`, passages and their
/// questions, read by `DeckParser`.

/// A [DeckParseException] whose message contains every one of [mentions].
Matcher rejects(List<String> mentions) {
  var matcher = isA<DeckParseException>();
  for (final text in mentions) {
    matcher = matcher.having((e) => e.message, 'message', contains(text));
  }
  return throwsA(matcher);
}

const readingHeader = '''
schema: 1
id: bn-en-test-reading
name: "Test reading"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
''';

/// A deck of one passage with [sentences] and [questions], and [extra]
/// passage fields.
String deck({
  String sentences = '''
      - text: "আমি ভাত খাই।"
        reading: "ami bhat khai."
''',
  String questions = '''
      - id: q1
        prompt: { en: "Rice is eaten." }
        answer: true
      - id: q2
        prompt: { en: "What is eaten?" }
        options:
          - { en: "Rice" }
          - { en: "Fish" }
        answer: 1
''',
  String extra = '',
}) =>
    '''
${readingHeader}passages:
  - id: p1
    title: "Lunch"
$extra    sentences:
$sentences    questions:
$questions''';

// From target_scripts_test.dart.
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

// From guide_layers_test.dart.
// A script guide and a sounds file split into a core and an English layer
// (#498, DECK-FORMAT.md, Script guides and Sounds files).
const scriptCore = '''
schema: 1
kind: "script"
part: "core"
id: "bn-script"
language: "bn"
features:
  - id: "headline"
    term: "মাত্রা"
    reading: "mātrā"
    example: "ক"
    letters: ["ক", "খ"]
  - id: "knot"
    example: "ত"
''';

const scriptLayer = '''
schema: 1
id: "bn-en-script"
kind: "layer"
core: "bn-script"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "How Bengali script works"
intro: "A few ideas come back in letter after letter."
features:
  "headline":
    name: "The headline"
    text: "Most letters hang from a line along the top."
  "knot":
    name: "The knot"
    text: "A small loop that tells letters apart."
''';

const soundsCore = '''
schema: 1
kind: "sounds"
part: "core"
id: "bn-sounds"
language: "bn"
contrasts:
  - id: "aspiration"
    pairs: [["ক", "খ"]]
  - id: "inherent-vowel"
    within_word: true
    pairs: [["", "া"]]
''';

const soundsLayer = '''
schema: 1
id: "bn-en-sounds"
kind: "layer"
core: "bn-sounds"
native: { code: "en", iso639_3: "eng", name: "English" }
contrasts:
  "aspiration": "a breath after the consonant"
  "inherent-vowel": "the open o against a"
''';

// From deck_catalog_test.dart.
const String miniDeck = '''
schema: 1
id: xx-mini
name: Mini
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - id: xx-mini-0001
    target: ñu
    native: gnu
''';

/// Line 10 has an unquoted `true`, the bug rule 2 is about. (A bare `no`
/// is text, as YAML 1.2 reads it.)
const String brokenDeck = '''
schema: 1
id: xx-broken
name: Broken
language: { code: ja, iso639_3: jpn, name: Japanese, script: kana }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-broken-0001
    target: ほんとう
    native: true
''';

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
          final yaml = vocab(extra: 'level: beginner\n');
          expect(
            () => parse(yaml),
            throwsParseError(
              line: lineOf(yaml, 'level'),
              mentions: ['unknown field', '"level"'],
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

  group('reading decks', () {
    group('a reading deck', () {
      test('a reading deck is its passages and questions; an answer that is no '
          'option is refused', () {
        final d = parse(readingFixtureYaml);
        expect(d.kind, DeckKind.reading);
        expect(d.passages.map((p) => p.id), [
          'bn-en-fixture-reading-shop',
          'bn-en-fixture-reading-home',
        ]);
        expect(d.cards.map((c) => c.id), [
          'bn-en-fixture-reading-shop-q1',
          'bn-en-fixture-reading-shop-q2',
          'bn-en-fixture-reading-shop-q3',
          'bn-en-fixture-reading-home-q1',
          'bn-en-fixture-reading-home-q2',
        ]);
        final first = d.cards.first as QuestionCard;
        expect(first.deckId, 'bn-en-fixture-reading');
        expect(first.passage.title, 'At the shop');
        expect(first.target, 'নমস্কার। কত দাম?');
        expect(first.native, 'What does the buyer ask first?');
        expect(first.modesIn(ttsAvailable: true), {
          DrillMode.reading,
          DrillMode.listening,
        });
        expect(first.source, readingFixtureSource);
        expect(first.passage.theme, 'market');
        // The second passage names no source, so its deck's is used.
        expect((d.cards.last as QuestionCard).source, readingFixtureDeckSource);
        expect(d.source, readingFixtureDeckSource);

        expect(
          () => parse(
            deck(
              questions: '''
      - id: q1
        prompt: { en: "Which?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: 3
''',
            ),
          ),
          rejects(['answer', 'from 1 to 2', '3']),
        );
        expect(
          () => parse(
            deck(
              questions: '''
      - id: q1
        prompt: { en: "Which?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: true
''',
            ),
          ),
          rejects(['answer', 'from 1 to 2']),
        );
        expect(
          () => parse(
            deck(
              questions: '''
      - id: q1
        prompt: { en: "True?" }
        answer: 1
''',
            ),
          ),
          rejects(['true or false']),
        );
      });
    });
  });

  group('target scripts', () {
    group('target_scripts (#623)', () {
      test('a card keeps its second spelling; a malformed one is refused', () {
        final deck = DeckParser.parse(_deck(_book), source: 'test.yaml');
        final card = deck.cards.single;
        expect(card.target, 'किताब');
        expect(card.targetScripts, {'perso_arabic': 'کتاب'});
        expect(card.reading, 'kitāb');
        expect(card.ipa, 'kɪtaːb');
        expect(
          card.targetIn('perso_arabic', firstScript: 'devanagari'),
          'کتاب',
        );
        expect(card.targetIn('devanagari', firstScript: 'devanagari'), 'किताब');
        expect(card.targetIn('shahmukhi', firstScript: 'devanagari'), isNull);
        expect(deck.language.script, 'devanagari');
        expect(deck.language.allScripts, ['devanagari', 'perso_arabic']);

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
    });
  });

  group('script guides', () {
    Map<String, String> files({String script = scriptLayer}) => {
      'decks/bn/bn-script.yaml': scriptCore,
      'decks/bn/en/bn-en-script.yaml': script,
      'decks/bn/bn-sounds.yaml': soundsCore,
      'decks/bn/en/bn-en-sounds.yaml': soundsLayer,
    };

    test('the catalog merges a guide core with its layer; a layer without '
        'its core is broken', () {
      final catalog = DeckCatalog.parseAll(files());
      expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
      expect(catalog.decks, isEmpty);
      final guide = catalog.scriptGuides['bn']!;
      expect(guide.name, 'How Bengali script works');
      expect(guide.features.map((f) => f.id), ['headline', 'knot']);
      expect(guide.features.first.name, 'The headline');
      expect(guide.features.first.term, 'মাত্রা');
      expect(guide.features.first.letters, ['ক', 'খ']);
      expect(
        guide.features.last.text,
        'A small loop that tells letters apart.',
      );
      final sounds = catalog.sounds['bn']!;
      expect(sounds.contrasts.map((c) => c.name), [
        'a breath after the consonant',
        'the open o against a',
      ]);
      expect(sounds.contrasts.last.withinWord, isTrue);
      expect(sounds.between('খ', 'ক')?.id, 'aspiration');

      {
        final catalog = DeckCatalog.parseAll({
          'decks/bn/en/bn-en-script.yaml': scriptLayer,
        });
        expect(catalog.scriptGuides, isEmpty);
        expect(catalog.broken.single.path, 'decks/bn/en/bn-en-script.yaml');
      }
    });
  });

  group('the catalog', () {
    group('bundled decks', () {
      late Catalog catalog;

      setUpAll(() async {
        catalog = await DeckCatalog(RepositoryDeckSource()).load();
      });

      test('every deck file the index lists is read and parses', () {
        // What a phone that downloaded every language has (#210): the files
        // decks/index.json lists. A language left out of it, as decks/ja/ is
        // for now, stays in the repository but not in the app.
        final index = DeckIndex.parse(
          File('decks/index.json').readAsStringSync(),
        );
        final onDisk = index.filesByPath.keys
            // Facts, themes, number rules, course paths, sounds and
            // romanisation files sit beside the decks but are not decks, nor
            // is the layer of a script guide or sounds file (#498).
            .where((p) => !index.filesByPath[p]!.isLanguageFile)
            .where(
              (p) => !{
                'facts',
                'themes',
                'numbers',
                'path',
                'sounds',
                'script',
                'romanisation',
              }.contains(DeckCatalog.kindOf(File(p).readAsStringSync())),
            )
            .toSet();
        expect(onDisk, isNotEmpty);
        expect(catalog.broken, isEmpty, reason: '${catalog.broken}');

        // Each is a deck the catalog lists by its path, single-file or a
        // layer merged with its core, or a core (ADR-0036). A core is not
        // listed itself: it is merged into each of its layers, the files in
        // a folder below it whose `core` names it, and one of them at least
        // is listed.
        final listed = catalog.decks.map((d) => d.path).toSet();
        String folderOf(String path) =>
            path.substring(0, path.lastIndexOf('/'));
        String stemOf(String path) =>
            path.substring(path.lastIndexOf('/') + 1, path.lastIndexOf('.'));
        final header = <String, YamlMap>{
          for (final path in onDisk)
            path: loadYaml(File(path).readAsStringSync()) as YamlMap,
        };
        final cores = {
          for (final path in onDisk)
            if (header[path]!['part'] == 'core') path,
        };
        expect(cores, isNotEmpty);
        expect(listed, onDisk.difference(cores));
        for (final core in cores) {
          final layers = listed.where(
            (path) =>
                header[path]!['kind'] == 'layer' &&
                header[path]!['core'] == stemOf(core) &&
                folderOf(folderOf(path)) == folderOf(core),
          );
          expect(layers, isNotEmpty, reason: '$core is in no deck listed');
          for (final layer in layers) {
            final deck = catalog.decks.singleWhere((d) => d.path == layer).deck;
            // Merged: the deck has the core's language and its layer's id.
            expect(deck.id, header[layer]!['id'], reason: layer);
            expect(
              deck.language.code,
              header[core]!['language']['code'],
              reason: layer,
            );
          }
        }
      });
    });

    group('parseAll', () {
      test('a file that fails to parse is a row with its line; a second deck '
          'with the same id is reported, not merged', () {
        final catalog = DeckCatalog.parseAll({
          'decks/es/es-mini.yaml': miniDeck,
          'decks/ja/ja-broken.yaml': brokenDeck,
        });
        expect(catalog.decks, hasLength(1));
        expect(catalog.broken, hasLength(1));
        final broken = catalog.broken.single;
        expect(broken.path, 'decks/ja/ja-broken.yaml');
        expect(broken.fileName, 'ja-broken.yaml');
        expect(broken.error.source, 'ja-broken.yaml');
        expect(broken.error.line, 10);
        expect(broken.error.message, contains('boolean'));

        {
          final catalog = DeckCatalog.parseAll({
            'decks/es/a.yaml': miniDeck,
            'decks/es/b.yaml': miniDeck,
          });
          expect(catalog.decks.map((d) => d.path), ['decks/es/a.yaml']);
          expect(catalog.broken.single.path, 'decks/es/b.yaml');
          expect(
            catalog.broken.single.error.message,
            contains('decks/es/a.yaml'),
          );
        }
      });
    });

    group('themes', () {
      const themes = '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
  - { id: help, name: "Help" }
''';

      String deck(
        String id, {
        String? theme,
        String lang = 'hi',
        String native = 'en',
      }) =>
          '''
schema: 1
id: $id
name: "$id"
${theme == null ? '' : 'theme: $theme'}
language: { code: $lang, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: $native, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: $id-0001
    target: "नमस्ते"
    native: "hello"
''';

      group('with a path', () {
        Map<String, String> files(String units) => <String, String>{
          'decks/themes.yaml': themes,
          'decks/hi/hi-en-core.yaml': deck('hi-en-core'),
          'decks/hi/hi-en-help.yaml': deck('hi-en-help', theme: 'help'),
          'decks/hi/hi-en-first-words.yaml': deck(
            'hi-en-first-words',
            theme: 'first-words',
          ),
          'decks/hi/hi-en-market.yaml': deck('hi-en-market', theme: 'market'),
          'decks/hi/hi-path.yaml': '''
schema: 1
kind: path
id: hi-path
language: hi
units:
$units''',
          'decks/ja/ja-en-kana.yaml': deck('ja-en-kana', lang: 'ja'),
        };

        test('the course\'s decks come in the path\'s order, whatever their '
            'themes', () {
          final catalog = DeckCatalog.parseAll(
            files(
              '  - [hi-first-words, hi-core]\n'
              '  - [hi-help]\n'
              '  - [hi-market]\n',
            ),
          );
          expect(catalog.broken, isEmpty);
          expect(catalog.decks.map((d) => d.id), [
            'hi-en-first-words',
            'hi-en-core',
            'hi-en-help',
            'hi-en-market',
            'ja-en-kana',
          ]);
          expect(catalog.paths['hi/en']!.units, [
            ['hi-en-first-words', 'hi-en-core'],
            ['hi-en-help'],
            ['hi-en-market'],
          ]);
          expect(catalog.pathOf(catalog.byId('ja-en-kana')!), isNull);
        });
      });
    });
  });

  // A card's and an example's `words` (DECK-FORMAT.md, Base words; #661):
  // Chinese and Japanese are written without spaces, so the deck gives the
  // words of each target, and the app splits by them where it would split
  // at spaces.
  group('words in a script without spaces', () {
    const header = '''
schema: 1
id: test-deck
name: Test deck
language: { code: zh, iso639_3: cmn, name: Mandarin Chinese, script: han_simplified, scripts: [han_simplified, han_traditional] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
''';
    const phrase = '''
  - id: zh-0011
    target: "我听不懂"
    target_scripts: { han_traditional: "我聽不懂" }
    words: ["我", "听不懂"]
    reading: "wǒ tīng bu dǒng"
    native: "I don't understand"
    pos: "phrase"
    examples:
      - target: "对不起，我听不懂。"
        words: ["对不起", "我", "听不懂"]
        native: "Sorry, I don't understand."
''';
    Card parsed(String yaml) =>
        DeckParser.parse('$header$yaml', source: 'test.yaml').cards.single;

    test('the words give the tiles put in order; words that are not the '
        'text, in order, fall back to its spaces', () {
      final card = parsed(phrase);
      expect(card.rearranges, isTrue);
      expect(card.tilesOfSpelling('我听不懂'), <String>['我', '听不懂']);
      expect(tilesOfWords('对不起，我听不懂。', <String>['对不起', '我', '听不懂']), <String>[
        '对不起',
        '，',
        '我',
        '听不懂',
        '。',
      ]);
      // Without its words it is one word, and typed instead.
      expect(
        parsed(phrase.replaceAll('    words: ["我", "听不懂"]\n', '')).rearranges,
        isFalse,
      );
      expect(tilesOfWords('多少钱？', <String>['多', '钱']), <String>['多少钱', '？']);
      expect(tilesOfWords('多少钱？', <String>['钱', '多少']), <String>['多少钱', '？']);
      expect(tilesOfWords('多少钱？', <String>['多少']), <String>['多少钱', '？']);
    });

    test('the traditional spelling takes the words letter for letter; a '
        'spelling of another length takes none', () {
      final card = parsed(phrase);
      expect(card.wordsOfSpelling('我聽不懂'), <String>['我', '聽不懂']);
      expect(card.tilesOfSpelling('我聽不懂'), <String>['我', '聽不懂']);
      expect(card.wordsOfSpelling('我不懂'), isNull);
      expect(carryWords(<String>['我', '听不懂'], from: '我听不懂', to: '我聽不'), isNull);
    });

    test('a card of several given words is not one word; a card of one '
        'is', () {
      final several = parsed(
        phrase.replaceAll('    pos: "phrase"\n', '    pos: "other"\n'),
      );
      expect(countsAsWord(several, DeckKind.vocab), isFalse);
      final one = parsed('''
  - id: zh-0101
    target: "我"
    words: ["我"]
    native: "I"
    pos: "pronoun"
''');
      expect(one.wordCount, 1);
      expect(countsAsWord(one, DeckKind.vocab), isTrue);
    });
  });
}
