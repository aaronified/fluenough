import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:yaml/yaml.dart';

Deck parse(String yaml) => DeckParser.parse(yaml, source: 'test.yaml');

Deck parseFile(String path) =>
    DeckParser.parse(File(path).readAsStringSync(), source: path);

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

void main() {
  group('the decks in decks/', () {
    final paths =
        Directory('decks')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => p.endsWith('.yaml'))
            // Facts files (#48), the themes file (#52), number rules (#54),
            // course paths (#117) and sounds files (#89) are valid in decks/
            // but are not decks.
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
                  }.contains(doc['kind']));
            })
            .toList()
          ..sort();

    test('are found', () {
      expect(paths, isNotEmpty);
    });

    for (final path in paths) {
      test('$path parses', () {
        final deck = parseFile(path);
        expect(deck.id, File(path).uri.pathSegments.last.split('.').first);
      });
    }

    test('carry both language codes', () {
      final deck = parseFile('decks/es/es-en-core-100.yaml');
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
      final deck = parseFile('decks/es/es-en-grammar-present-ar.yaml');
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
      const path = 'decks/es/es-en-core-100.yaml';
      final inFile = RegExp(
        r'^  - id: ',
        multiLine: true,
      ).allMatches(File(path).readAsStringSync()).length;
      final deck = parseFile(path);
      expect(inFile, greaterThan(0));
      expect(deck.cards, hasLength(inFile));
      final casa = deck.cards.singleWhere((c) => c.id == 'es-en-core-0010');
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
      expect(card.notes, 'Also a line of verse.');
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
      expect(card.notes, isNull);
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
    test('a bare no is a boolean, and the message says to quote it', () {
      final yaml = vocab().replaceFirst('native: the house', 'native: no');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'native: no'),
          mentions: ['cards[0].native', 'boolean false', 'Quote it: "no"'],
        ),
      );
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

    test('the language code for Norwegian must be quoted too', () {
      final yaml = vocab().replaceFirst('code: es', 'code: no');
      expect(
        () => parse(yaml),
        throwsParseError(
          line: lineOf(yaml, 'code: no'),
          mentions: ['language.code', 'boolean false'],
        ),
      );
    });

    // PyYAML, which CI validates with, reads YAML 1.1. package:yaml reads
    // YAML 1.2. A deck CI accepts must parse here, so the 1.1 reading wins.
    test('unquoted values are typed as PyYAML types them', () {
      final deck = parse(
        vocab(
          cards: '''
  - id: test-0001
    target: 08
    native: !!str 007
''',
        ).replaceFirst('script: latin}', 'script: latin, rtl: yes}'),
      );
      expect(deck.language.rtl, isTrue);
      expect(deck.cards.single.target, '08');
      expect(deck.cards.single.native, '007');

      final yaml = vocab().replaceFirst('native: the house', 'native: 1:30');
      expect(
        () => parse(yaml),
        throwsParseError(line: lineOf(yaml, '1:30'), mentions: ['number']),
      );
    });

    // These are what package:yaml alone would get wrong, so each one fails if
    // the retyping of a word or a number form is lost.
    String withRtl(String value) =>
        vocab().replaceFirst('script: latin}', 'script: latin, rtl: $value}');

    test('yes, on and true are true, and no, off and false are false', () {
      for (final word in ['yes', 'on', 'true', 'no', 'off', 'false']) {
        final value = const {'yes', 'on', 'true'}.contains(word);
        for (final written in [
          word,
          '${word[0].toUpperCase()}${word.substring(1)}',
          word.toUpperCase(),
        ]) {
          expect(parse(withRtl(written)).language.rtl, value, reason: written);
        }
      }
    });

    test('other spellings of them are text, as in CI', () {
      for (final written in ['y', 'n', 'yEs', 'oN']) {
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

    test('what PyYAML reads as a number is a number', () {
      for (final number in [
        '0x1A',
        '0b11',
        '017',
        '+12',
        '1.5',
        '.5',
        '6.8523015e+5',
        '.inf',
        '-.Inf',
        '.nan',
        '1:30.5',
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

    // In YAML 1.1 an octal number is 017, not 0o17, and an exponent needs a
    // dot and a sign.
    test('what only YAML 1.2 reads as a number is text, as in CI', () {
      for (final text in ['08', '09', '0o17', '1e5', '1.0e5', '+.5', '-.5']) {
        final card = parse(vocab().replaceFirst('la casa', text)).cards.single;
        expect(card.target, text);
      }
    });

    test('schema is 1 however PyYAML can write 1', () {
      for (final one in [
        '+1',
        '01',
        '0x1',
        '0b1',
        '+0b1',
        '1_',
        '1.',
        '.1e+1',
        '0:1.0',
      ]) {
        final yaml = vocab().replaceFirst('schema: 1', 'schema: $one');
        expect(parse(yaml).id, 'test-deck', reason: one);
      }
    });

    // 0o1 and 1e0 are 1 in YAML 1.2, and yes and true are 1 to Python's ==.
    test('schema is not 1 when it only looks like 1', () {
      for (final other in ['0o1', '1e0', 'yes', 'true', '!!str 1']) {
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

    // PyYAML types a scalar tagged `!` by its look, even quoted. package:yaml
    // makes it text.
    test('a value tagged with a bare ! is typed by its look', () {
      expect(parse(withRtl('! "yes"')).language.rtl, isTrue);
      final one = vocab().replaceFirst('schema: 1', r'schema: ! "1\n"');
      expect(parse(one).id, 'test-deck');

      // A lone newline stays text: PyYAML picks its patterns by the first
      // character, and none of them starts with one.
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
          mentions: ['kind must be vocab or grammar', '"flashcards"'],
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
      final yaml = vocab().replaceFirst('native: the house', 'native: no');
      try {
        DeckParser.parse(yaml, source: 'es-en-core-100.yaml');
        fail('expected a DeckParseException');
      } on DeckParseException catch (e) {
        expect(e.source, 'es-en-core-100.yaml');
        expect(e.line, lineOf(yaml, 'native: no'));
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
