import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:yaml/yaml.dart';

Deck parse(String yaml) => DeckParser.parse(yaml, source: 'test.yaml');

Deck parseFile(String path) =>
    DeckParser.parse(File(path).readAsStringSync(), source: path);

/// Spanish's deck [name] as an English speaker is taught it: its core in
/// `decks/es/` and its layer in `decks/es/en/`, merged.
Deck parseSpanish(String name) => mergeLayer(
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

/// [grammar] with readings and IPA on its second entry, `llover`, whose
/// first two slots have no form: [readings] and [ipas] are the mappings.
String grammarWith({required String readings, required String ipas}) =>
    grammar.replaceFirst(
      '        él: llueve\n',
      '        él: llueve\n      readings: $readings\n      ipas: $ipas\n',
    );

void main() {
  group('the decks in decks/', () {
    final paths =
        Directory('decks')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => p.endsWith('.yaml'))
            // Facts files (#48), the themes file (#52), number rules (#54),
            // course paths (#117), sounds files (#89) and romanisation files
            // (#47) are valid in decks/ but are not decks.
            .where((p) {
              final doc = loadYaml(File(p).readAsStringSync());
              return !(doc is Map &&
                  {
                    'facts',
                    'themes',
                    'numbers',
                    'path',
                    'sounds',
                    'script',
                    'romanisation',
                  }.contains(doc['kind']));
            })
            .toList()
          ..sort();

    test('are found', () {
      expect(paths, isNotEmpty);
    });

    for (final path in paths) {
      test('$path parses', () {
        final stem = File(path).uri.pathSegments.last.split('.').first;
        final text = File(path).readAsStringSync();
        final doc = loadYaml(text);
        // A core and a layer (the B1 format) are read apart, and a layer
        // with its core, the file named for it in the folder above.
        if (doc is Map && doc['part'] == 'core' && doc['kind'] != 'layer') {
          expect(DeckParser.parseCore(text, source: path).id, stem);
        } else if (doc is Map && doc['kind'] == 'layer') {
          final layer = DeckParser.parseLayer(text, source: path);
          final core = DeckParser.parseCore(
            File('${File(path).parent.parent.path}/${layer.core}.yaml')
                .readAsStringSync(),
            source: '${layer.core}.yaml',
          );
          expect(mergeLayer(core, layer, source: path).id, stem);
        } else {
          expect(parseFile(path).id, stem);
        }
      });
    }

    test('carry both language codes', () {
      final deck = parseSpanish('core-100');
      expect(deck.language.code, 'es');
      expect(deck.language.iso639_3, 'spa');
      expect(deck.native.iso639_3, 'eng');
    });

    test('ja-en-hiragana has all 46 kana, and "no" survives as text', () {
      final deck = parseFile('decks/ja/ja-en-hiragana.yaml');
      expect(deck.kind, DeckKind.vocab);
      expect(deck.cards, hasLength(46));
      expect(deck.language.script, 'kana');
      final no = deck.cards.singleWhere((c) => c.target == 'の');
      expect(no.native, 'no');
      expect(no.reading, 'no');
    });

    test('es-en-grammar-present-ar is a pattern with no cards', () {
      final deck = parseSpanish('grammar-present-ar');
      expect(deck.kind, DeckKind.grammar);
      expect(deck.cards, isEmpty);
      final pattern = deck.pattern!;
      expect(pattern.entries, hasLength(5));
      expect(pattern.slots, [
        'yo',
        'tú',
        'él/ella',
        'nosotros',
        'vosotros',
        'ellos',
      ]);
      expect(pattern.entries.first.forms.keys, pattern.slots);
      expect(pattern.entries.first.forms['vosotros'], 'habláis');
    });

    test('es-en-core-100 has every card in the file', () {
      const path = 'decks/es/es-core-100.yaml';
      final inFile = RegExp(
        r'^  - id: ',
        multiLine: true,
      ).allMatches(File(path).readAsStringSync()).length;
      final deck = parseSpanish('core-100');
      expect(inFile, greaterThan(0));
      expect(deck.cards, hasLength(inFile));
      final casa = deck.cards.singleWhere((c) => c.id == 'es-0006');
      expect(casa.altNative, ['the home']);
      expect(casa.examples.single.target, 'La casa es muy grande.');
    });
  });

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
      expect(deck.authors.map((a) => a.url), ['https://example.org/ada', null]);

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

    test('leaves out what the deck leaves out', () {
      final deck = parse(vocab());
      expect(deck.kind, DeckKind.vocab);
      expect(deck.description, isNull);
      expect(deck.source, isNull);
      expect(deck.tags, isEmpty);
      expect(deck.authors, isEmpty);
      expect(deck.language.tts, isNull);
      expect(deck.language.rtl, isFalse);
      expect(deck.native.script, 'latin');

      final card = deck.cards.single;
      expect(card.reading, isNull);
      expect(card.altTarget, isEmpty);
      expect(card.altNative, isEmpty);
      expect(card.pos, isNull);
      expect(card.gender, isNull);
      expect(card.tags, isEmpty);
      expect(card.notes, isEmpty);
      expect(card.audio, isNull);
      expect(card.examples, isEmpty);
      expect(card.modes, isEmpty, reason: 'empty means every mode');
    });

    test('accepts any script name', () {
      final deck = parse(
        vocab().replaceFirst('script: latin', 'script: tamil'),
      );
      expect(deck.language.script, 'tamil');
    });

    test('ignores a byte order mark, as CI does', () {
      expect(parse('\uFEFF${vocab()}').id, 'test-deck');
    });

    test('accepts unknown fields in a language block, as CI does', () {
      final deck = parse(
        vocab().replaceFirst('name: English}', 'name: English, flag: gb}'),
      );
      expect(deck.native.name, 'English');
    });
  });

  group('a valid grammar deck', () {
    test('keeps the pattern unexpanded, in slot order', () {
      final deck = parse(grammar);
      expect(deck.kind, DeckKind.grammar);
      expect(deck.cards, isEmpty);
      final pattern = deck.pattern!;
      expect(pattern.name, 'Present tense');
      expect(pattern.slotName, 'person');
      expect(pattern.slots, ['yo', 'tú', 'él']);
      expect(pattern.prompt, '{lemma} ({gloss}) — {slot}');
      expect(pattern.notes, 'Regular -ar endings.');
      expect(pattern.entries.map((e) => e.lemma), ['hablar', 'llover']);
      expect(pattern.entries.first.gloss, 'to speak');
      expect(pattern.entries.first.forms, {
        'yo': 'hablo',
        'tú': 'hablas',
        'él': 'habla',
      });
    });

    test('keeps null forms', () {
      final forms = parse(grammar).pattern!.entries.last.forms;
      expect(forms.keys, ['yo', 'tú', 'él']);
      expect(forms, {'yo': null, 'tú': null, 'él': 'llueve'});
    });
  });

  group('malformed YAML', () {
    test('is reported at the line the YAML parser stopped at', () {
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
    });

    test('an empty file is not a deck', () {
      expect(() => parse(''), throwsParseError(line: 1, mentions: ['empty']));
    });

    // package:yaml throws a RangeError on these, not a YamlException.
    test('a tag package:yaml trips over is reported, with no position', () {
      for (final value in ['!!float 1', '!!float ""', '!!int ""']) {
        expect(
          () => parse(vocab().replaceFirst('la casa', value)),
          throwsParseError(
            line: null,
            mentions: ['could not be read as YAML: RangeError'],
          ),
          reason: value,
        );
      }
    });

    test('so is anything else package:yaml throws', () {
      // Keyed by how each error describes itself.
      final cases = {
        // Each anchor wraps the one before, so the last is 100000 lists deep,
        // and package:yaml hashes a key recursively. Nesting written out that
        // deep overflows too, but takes minutes to scan.
        'Stack Overflow': [
          vocab(),
          for (var i = 1; i < 100000; i++) 'a$i: &a$i [*a${i - 1}]',
          '? *a99999',
          ': x',
        ].join('\n').replaceFirst('la casa', '&a0 la casa'),
        'Invalid URL encoding': vocab().replaceFirst('la casa', '!<%ZZ> casa'),
        'FormatException': '%YAML 99999999999999999999.1\n---\n${vocab()}',
      };
      for (final MapEntry(key: error, value: yaml) in cases.entries) {
        expect(
          () => parse(yaml),
          throwsParseError(
            line: null,
            mentions: ['could not be read as YAML: ', error],
          ),
          reason: error,
        );
      }
    });
  });

  group('hostile YAML that loads', () {
    test('nesting where text belongs', () {
      final yaml = vocab().replaceFirst(
        'la casa',
        '${'[' * 1000}${']' * 1000}',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'target:'),
          mentions: ['cards[0].target must be text, not a list'],
        ),
      );
    });

    test('a list as a key', () {
      final yaml = vocab(cards: '$oneCard    ? [a, b]\n    : c\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, '[a, b]'),
          mentions: ['cards[0]: unknown field a list'],
        ),
      );
    });

    test('numbers too big for an int', () {
      String withSchema(String schema) =>
          vocab().replaceFirst('schema: 1', 'schema: $schema');
      for (final other in [
        '9' * 400,
        // 60 to the 34th, plus 1, which wraps round to 1 in a 64-bit int.
        '1:${List.filled(33, '00').join(':')}:01',
      ]) {
        expect(
          () => parse(withSchema(other)),
          throwsParseError(line: 1, mentions: ['schema must be 1']),
          reason: other,
        );
      }
      expect(parse(withSchema('0x${'0' * 5000}1')).id, 'test-deck');
    });
  });

  group('a missing required field', () {
    test('at the top level', () {
      final yaml = vocab().replaceFirst('license: CC0-1.0\n', '');
      expect(
        () => parse(yaml),
        throwsParseError(line: 1, mentions: ['missing', '"license"']),
      );
    });

    test('on a card, pointing at the card', () {
      final yaml = vocab().replaceFirst('    native: the house\n', '');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'id: test-0001'),
          mentions: ['cards[0]', 'missing', '"native"'],
        ),
      );
    });

    test('in the pattern, pointing at the pattern', () {
      final yaml = grammar.replaceFirst(RegExp(r'  prompt: .*\n'), '');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'name: Present tense'),
          mentions: ['pattern', 'missing', '"prompt"'],
        ),
      );
    });

    test('that is present but empty', () {
      final yaml = vocab().replaceFirst('native: the house', 'native:');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'native:', occurrence: 2),
          mentions: ['cards[0].native', 'has no value'],
        ),
      );
    });

    // CI tests `str.strip()`. Dart's `trim()` also strips U+FEFF, and does
    // not strip U+001F.
    test('that is blank, the way CI means blank', () {
      final kept = vocab().replaceFirst('the house', r'"\uFEFF"');
      expect(parse(kept).cards.single.native, '\uFEFF');

      final yaml = vocab().replaceFirst('the house', r'"\x1F"');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'x1F'),
          mentions: ['cards[0].native must not be empty'],
        ),
      );
    });
  });

  group('an unknown field', () {
    test('on a card', () {
      final yaml = vocab(cards: '$oneCard    colour: red\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'colour'),
          mentions: ['cards[0]', 'unknown field', '"colour"'],
        ),
      );
    });

    test('at the top level', () {
      final yaml = vocab(extra: 'level: beginner\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'level'),
          mentions: ['unknown field', '"level"'],
        ),
      );
    });

    test('in the pattern', () {
      final yaml = grammar.replaceFirst(
        '  slot_name: person\n',
        '  slot_name: person\n  tense: present\n',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'tense:'),
          mentions: ['pattern', 'unknown field', '"tense"'],
        ),
      );
    });

    test('in an example', () {
      final yaml = vocab(
        cards:
            '$oneCard    examples:\n      - {target: a, native: b, level: 1}\n',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'level'),
          mentions: ['cards[0].examples[0]: unknown field "level"'],
        ),
      );
    });

    test('in an author', () {
      final yaml = vocab(
        extra: 'authors:\n  - name: Ada\n    email: a@b.org\n',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'email'),
          mentions: ['authors[0]: unknown field "email"'],
        ),
      );
    });

    test('in a pattern entry', () {
      final yaml = grammar.replaceFirst(
        '      gloss: to speak\n',
        '      gloss: to speak\n      mood: indicative\n',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'mood'),
          mentions: ['pattern.entries[0]: unknown field "mood"'],
        ),
      );
    });
  });

  group('the YAML traps', () {
    test('a bare false is a boolean, and the message says to quote it', () {
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
    });

    // The validator reads plain scalars as YAML 1.2 does (spec ground rule
    // 8), so the hiragana の's romanisation is text in both, as package:yaml
    // reads it too.
    test('a bare no is text, as in CI', () {
      final card = parse(vocab(cards: '$oneCard    reading: no\n'))
          .cards
          .single;
      expect(card.reading, 'no');
    });

    test('a bare 007 is a number, and the message says to quote it', () {
      final yaml = vocab().replaceFirst('target: la casa', 'target: 007');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'target: 007'),
          mentions: ['cards[0].target', 'number', 'Quote it: "007"'],
        ),
      );
    });

    test('a quoted no or 007 is text', () {
      final card = parse(
        vocab()
            .replaceFirst('target: la casa', 'target: "007"')
            .replaceFirst('native: the house', 'native: "no"'),
      ).cards.single;
      expect(card.target, '007');
      expect(card.native, 'no');
    });

    test('the language code for Norwegian needs no quotes, as in CI', () {
      final deck = parse(vocab().replaceFirst('code: es', 'code: no'));
      expect(deck.language.code, 'no');

      final yaml = vocab().replaceFirst('code: es', 'code: false');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'code: false'),
          mentions: ['language.code', 'boolean false'],
        ),
      );
    });

    // tools/validate_decks.py reads plain scalars by YAML 1.2's core schema
    // (its DeckResolver). A deck CI accepts must parse here, and read the
    // same, so the parser retypes plain scalars by the same patterns.
    test('unquoted values are typed as the validator types them', () {
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
    });

    // Each of these fails if the parser's reading of a word or a number form
    // drifts from the validator's.
    String withRtl(String value) =>
        vocab().replaceFirst('script: latin}', 'script: latin, rtl: $value}');

    test('true and false in three spellings are booleans', () {
      for (final word in ['true', 'false']) {
        for (final written in [
          word,
          '${word[0].toUpperCase()}${word.substring(1)}',
          word.toUpperCase(),
        ]) {
          expect(
            parse(withRtl(written)).language.rtl,
            word == 'true',
            reason: written,
          );
        }
      }
    });

    // YAML 1.1's other boolean words are text in YAML 1.2, so a bare yes
    // where a boolean is wanted is refused, as the validator refuses it.
    test('yes, no, on, off and other spellings are text, as in CI', () {
      for (final written in [
        'yes',
        'no',
        'on',
        'off',
        'Yes',
        'NO',
        'y',
        'n',
        'yEs',
        'tRUE',
      ]) {
        expect(
          () => parse(withRtl(written)),
          throwsParseError(
            line: lineOf(withRtl(written), 'rtl'),
            mentions: ['language.rtl must be true or false', '"$written"'],
          ),
          reason: written,
        );
      }
    });

    test('what the validator reads as a number is a number', () {
      for (final number in [
        '0x1A',
        '0x1f',
        '0o17',
        '017',
        '08',
        '+12',
        '-5',
        '1.5',
        '.5',
        '1.',
        '+.5',
        '-.5',
        '1e5',
        '1.0e5',
        '6.8523015e+5',
        '.inf',
        '-.Inf',
        '+.INF',
        '.nan',
        '123456789012345678901234567890',
      ]) {
        final yaml = vocab().replaceFirst('la casa', number);
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'target:'),
            mentions: [
              'read as a number',
              'bare $number',
              'Quote it: "$number"',
            ],
          ),
          reason: number,
        );
      }
    });

    // YAML 1.1 read these as numbers: binary, base 60, and digits with
    // underscores. YAML 1.2, and so the validator, reads them as text.
    test('what only YAML 1.1 reads as a number is text, as in CI', () {
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
        final card = parse(vocab().replaceFirst('la casa', text)).cards.single;
        expect(card.target, text, reason: text);
      }
    });

    test('schema is 1 however the validator can write 1', () {
      for (final one in [
        '+1',
        '01',
        '0x1',
        '0o1',
        '1.',
        '1.0',
        '1e0',
        '.1e+1',
      ]) {
        final yaml = vocab().replaceFirst('schema: 1', 'schema: $one');
        expect(parse(yaml).id, 'test-deck', reason: one);
      }
    });

    // 0b1, 1_ and 0:1.0 are text in YAML 1.2, and true is not a number,
    // though Python's == says True is 1.
    test('schema is not 1 when it only looks like 1', () {
      for (final other in [
        '0b1',
        '+0b1',
        '1_',
        '0:1.0',
        'yes',
        'true',
        '!!str 1',
      ]) {
        final yaml = vocab().replaceFirst('schema: 1', 'schema: $other');
        expect(
          () => parse(yaml),
          throwsParseError(line: 1, mentions: ['schema must be 1, got']),
          reason: other,
        );
      }
    });

    test('an anchor with no value is empty, as in CI', () {
      final card = parse(vocab(cards: '$oneCard    reading: &r\n'))
          .cards
          .single;
      expect(card.reading, isNull);
    });

    test('a tag types a value even after an anchor', () {
      final card = parse(
        vocab(
          cards: '''
  - id: test-0001
    target: &a !!str 007
    native: !!str &b 007
''',
        ),
      ).cards.single;
      expect(card.target, '007');
      expect(card.native, '007');
    });

    // PyYAML types a scalar tagged `!` by its look, even quoted, with the
    // validator's patterns. package:yaml makes it text.
    test('a value tagged with a bare ! is typed by its look', () {
      expect(parse(withRtl('! "true"')).language.rtl, isTrue);
      final one = vocab().replaceFirst('schema: 1', 'schema: ! "0x1"');
      expect(parse(one).id, 'test-deck');

      // The patterns match the whole text: a 1 followed by a newline is
      // text, and so not the schema 1.
      final newline = vocab().replaceFirst('schema: 1', r'schema: ! "1\n"');
      expect(
        () => parse(newline),
        throwsParseError(line: 1, mentions: ['schema must be 1, got']),
      );

      // So is a lone newline, which is not the empty null.
      final blank = vocab(cards: '$oneCard    reading: ! "\\n"\n');
      expect(
        () => parse(blank),
        throwsParseError(
          line: lineOf(blank, 'reading'),
          mentions: ['cards[0].reading must not be empty'],
        ),
      );

      final yaml = vocab().replaceFirst('la casa', '! 007');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'target:'),
          mentions: ['read as a number', 'it is tagged !. Remove the tag'],
        ),
      );
    });

    // The validator reads a null reading as one left out (spec 4.2): so a
    // slot with no form may give its reading and IPA as null, and only as
    // null.
    test('a null reading or IPA under a null form is none, as in CI', () {
      final entry = parse(
        grammarWith(
          readings: '{yo: null, tú: ~, él: yueve}',
          ipas: '{yo: ~, él: ʎweβe}',
        ),
      ).pattern!.entries.last;
      expect(entry.readings, {
        'él': ['yueve'],
      });
      expect(entry.ipas, {'él': 'ʎweβe'});

      for (final (readings, ipas, slot) in [
        ('{yo: yo, él: yueve}', '{él: ʎweβe}', 'readings'),
        ('{él: yueve}', '{tú: tu, él: ʎweβe}', 'ipas'),
      ]) {
        final yaml = grammarWith(readings: readings, ipas: ipas);
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, '$slot:', occurrence: 1),
            mentions: ['has no form, so it has no'],
          ),
          reason: '$readings $ipas',
        );
      }

      // A null under a slot with a form is a reading missing.
      final missing = grammarWith(readings: '{él: null}', ipas: '{él: ʎweβe}');
      expect(() => parse(missing), throwsA(isA<DeckParseException>()));
    });

    test('a tagged value is not called bare', () {
      for (final (value, read, tag, text) in [
        ('!!int 5', 'a number', '!!int', '5'),
        ('!!int "5"', 'a number', '!!int', '5'),
        ('!!bool true', 'the boolean true', '!!bool', 'true'),
      ]) {
        final yaml = vocab().replaceFirst('la casa', value);
        expect(
          () => parse(yaml),
          throwsParseError(
            line: lineOf(yaml, 'target:'),
            mentions: [
              'cards[0].target was read as $read, not as text: it is tagged '
                  '$tag. Remove the tag and quote it: "$text"',
            ],
            omits: ['bare'],
          ),
          reason: value,
        );
      }
    });
  });

  group('the id checks', () {
    test('a duplicate card id', () {
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
    });

    test('a badly formed deck id', () {
      final yaml = vocab().replaceFirst('id: test-deck', 'id: Test_Deck');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'Test_Deck'),
          mentions: ['id must be', '"Test_Deck"'],
        ),
      );
    });

    test('a badly formed card id', () {
      final yaml = vocab().replaceFirst('id: test-0001', 'id: test--0001');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'test--0001'),
          mentions: ['cards[0].id must be', '"test--0001"'],
        ),
      );
    });

    test('a duplicate lemma', () {
      final yaml = grammar.replaceFirst('lemma: llover', 'lemma: hablar');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'lemma: hablar', occurrence: 2),
          mentions: ['pattern.entries[1].lemma', 'duplicate lemma "hablar"'],
        ),
      );
    });

    test('a lemma that cannot go into a card id, without a key', () {
      final yaml = grammar.replaceFirst('lemma: llover', 'lemma: "जाना"');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'lemma: "जाना"'),
          mentions: ['pattern.entries[1]', '"जाना" cannot go into a card id'],
        ),
      );
    });

    test('a badly formed key', () {
      final yaml = grammar.replaceFirst(
        'lemma: llover',
        'lemma: llover\n      key: Llover',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'key: Llover'),
          mentions: ['pattern.entries[1].key must be', '"Llover"'],
        ),
      );
    });

    test('a key that another row already uses as its lemma', () {
      final yaml = grammar.replaceFirst(
        'lemma: llover',
        'lemma: llover\n      key: hablar',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'key: hablar'),
          mentions: ['pattern.entries[1]', '"hablar" already names a row'],
        ),
      );
    });

    test('a duplicate slot', () {
      final yaml = grammar.replaceFirst('[yo, tú, él]', '[yo, tú, yo]');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'slots:'),
          mentions: ['pattern.slots[2]', 'duplicate slot "yo"'],
        ),
      );
    });

    test('forms missing a slot', () {
      final yaml = grammar.replaceFirst('        tú: hablas\n', '');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'yo: hablo'),
          mentions: ['pattern.entries[0].forms', 'missing slot "tú"'],
        ),
      );
    });

    test('forms with a key that is not a slot', () {
      final yaml = grammar.replaceFirst(
        '        él: habla\n',
        '        él: habla\n        ella: habla\n',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'ella: habla'),
          mentions: ['pattern.entries[0].forms', '"ella" is not a slot'],
        ),
      );
    });

    test('forms that are all null', () {
      final yaml = grammar.replaceFirst('él: llueve', 'él: null');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'yo: null'),
          mentions: ['pattern.entries[1].forms', 'every form is null'],
        ),
      );
    });

    test('a blank form', () {
      final yaml = grammar.replaceFirst('tú: hablas', 'tú: ""');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'tú: ""'),
          mentions: ['pattern.entries[0].forms.tú must not be empty'],
        ),
      );
    });
  });

  group('the kind rules', () {
    test('a vocab deck with a pattern', () {
      final yaml = vocab(extra: 'pattern: {}\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'pattern:'),
          mentions: ['only for a grammar deck'],
        ),
      );
    });

    test('a grammar deck with cards', () {
      final yaml = '${grammar}cards:\n$oneCard';
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'cards:'),
          mentions: ['a grammar deck has a pattern, not cards'],
        ),
      );
    });

    test('a grammar deck with no pattern', () {
      final yaml = grammar.substring(0, grammar.indexOf('pattern:'));
      expect(
        () => parse(yaml),
        throwsParseError(line: 1, mentions: ['missing', '"pattern"']),
      );
    });

    test('a vocab deck with no cards', () {
      final yaml = vocab(cards: '').replaceFirst('cards:\n', 'cards: []\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'cards:'),
          mentions: ['cards must not be empty'],
        ),
      );
    });

    test('a grammar deck with no slots', () {
      final yaml = grammar.replaceFirst('[yo, tú, él]', '[]');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'slots:'),
          mentions: ['pattern.slots must not be empty'],
        ),
      );
    });

    test('a grammar deck with no entries', () {
      final yaml =
          '${grammar.substring(0, grammar.indexOf('  entries:'))}  entries: []\n';
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'entries:'),
          mentions: ['pattern.entries must not be empty'],
        ),
      );
    });

    test('schema 2', () {
      final yaml = vocab().replaceFirst('schema: 1', 'schema: 2');
      expect(
        () => parse(yaml),
        throwsParseError(line: 1, mentions: ['schema must be 1, got 2']),
      );
    });

    test('an unknown kind', () {
      final yaml = vocab(extra: 'kind: flashcards\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'flashcards'),
          mentions: ['kind must be vocab, grammar or reading', '"flashcards"'],
        ),
      );
    });

    test('an unknown drill mode', () {
      final yaml = vocab(cards: '$oneCard    modes: [production, singing]\n');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'singing'),
          mentions: ['cards[0].modes[1]', 'unknown mode "singing"'],
        ),
      );
    });

    test('rtl that is not a boolean', () {
      final yaml = vocab().replaceFirst(
        'script: latin}',
        'script: latin, rtl: "true"}',
      );
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'rtl'),
          mentions: ['language.rtl must be true or false'],
        ),
      );
    });
  });

  group('messages', () {
    test('start with the source, line and column', () {
      final yaml = vocab().replaceFirst('native: the house', 'native: false');
      try {
        DeckParser.parse(yaml, source: 'es-en-core-100.yaml');
        fail('expected a DeckParseException');
      } on DeckParseException catch (e) {
        expect(e.source, 'es-en-core-100.yaml');
        expect(e.line, lineOf(yaml, 'native: false'));
        expect(e.column, 13);
        expect(e.toString(), 'es-en-core-100.yaml:${e.line}:13: ${e.message}');
      }
    });

    test('leave out a position that is unknown', () {
      const e = DeckParseException('unreadable', source: 'deck.yaml');
      expect(e.toString(), 'deck.yaml: unreadable');
    });
  });

  group('language codes', () {
    test('iso639_3 is required on both language blocks', () {
      for (final (line, code) in [(4, 'spa'), (5, 'eng')]) {
        expect(
          () => parse(vocab().replaceFirst('iso639_3: $code, ', '')),
          throwsParseError(line: line, mentions: ['iso639_3']),
          reason: code,
        );
      }
    });

    test('iso639_3 must be three lowercase letters', () {
      for (final bad in ['es', 'spain', 'SPA', 's1a', '"spa\\n"']) {
        expect(
          () => parse(vocab().replaceFirst('iso639_3: spa', 'iso639_3: $bad')),
          throwsParseError(line: 4, mentions: ['ISO 639-3']),
          reason: bad,
        );
      }
    });
  });

  test('a facts file is refused as not a deck', () {
    const facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: {code: hi, iso639_3: hin, name: Hindi, script: devanagari}
license: CC0-1.0
facts:
  - id: hi-fact-001
    text: {en: "No Hindi word begins with ड़ or ढ़."}
''';
    expect(
      () => parse(facts),
      throwsParseError(line: 4, mentions: ['facts file, not a deck']),
    );
  });
}
