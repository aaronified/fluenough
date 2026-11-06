// Split out of deck_format_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: reading decks, target scripts, script guides, the catalog, words in a script without spaces, a narrow transcription (phonetic).

import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'support/deck_format_shared.dart';

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
            // A recording or an image is a binary file, not a deck.
            .where((p) => !index.filesByPath[p]!.isMedia)
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

  group('a narrow transcription (phonetic)', () {
    test('a single-file card carries it with its source', () {
      final card = parseProbe(
        probeCard(
          '    phonetic: "[kʰɐlɐm]"\n    phonetic_source: "wiktionary"\n',
        ),
      ).cards.single;
      expect(card.phonetic, '[kʰɐlɐm]');
      expect(card.phoneticSource, 'wiktionary');
    });

    test('a core card carries it through its layer', () {
      final card = merged(
        '    pos: "noun"\n'
            '    phonetic: "[kʰɐlɐm]"\n'
            '    phonetic_source: "rules"\n',
        '',
      );
      expect(card.phonetic, '[kʰɐlɐm]');
      expect(card.phoneticSource, 'rules');
    });

    test('a card without one has neither, and ipa is untouched', () {
      final card = parseProbe(probeCard('    ipa: "kalam"\n')).cards.single;
      expect(card.phonetic, isNull);
      expect(card.phoneticSource, isNull);
      expect(card.ipa, 'kalam');
    });
  });
}
