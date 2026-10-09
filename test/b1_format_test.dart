// The B1 deck format's Dart side: cores and layers, typed notes, bases, the
// phrasebook mark, Wiktionary marks, rules decks and their cells, and the B1
// plan in a path. Section numbers are those of the format's spec.
//
// The fixtures are in test/fixtures/b1/, in a language with no decks in the
// repository, `zz` (Testlang, written in the Telugu script):
// appendix-a/ is the spec's Appendix A, a valid set; features/ exercises
// what Appendix A does not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';

String read(String path) => File(path).readAsStringSync();

String nameOf(String path) => path.split('/').last;

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
String oneCard(String extra) => single('''
  - id: "zz-0001"
    target: "కలం"
    reading: "kalam"
    native: "pen"
$extra''');

Deck parse(String yaml) => DeckParser.parse(yaml, source: 'zz-en-probe.yaml');

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');
final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');
final marketCore = read('$features/zz-market.yaml');
final marketLayer = read('$features/en/zz-en-market.yaml');
final marketBengali = read('$features/bn/zz-bn-market.yaml');
final pastCore = read('$features/zz-grammar-past.yaml');
final pastLayer = read('$features/en/zz-en-grammar-past.yaml');
final words = read('$features/zz-en-words.yaml');

void main() {
  group('parse() reads single-file decks only (9.2)', () {
    test('a layer, a core, and what only they have, are refused', () {
      for (final (yaml, why) in <(String, String)>[
        (homeLayer, 'this is a layer; it is read with DeckParser.parseLayer'),
        (
          homeCore,
          'this is a core file; it is read with DeckParser.parseCore and '
              'merged with a layer',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'part: "half"\ncards:'),
          'part must be "core", or left out on a single-file deck; got "half"',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'core: "zz-home"\ncards:'),
          'only a layer names a core (kind: "layer")',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'table: {}\ncards:'),
          'only a rules core has table; a rules deck is written as a core '
              'and layers',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'rules: []\ncards:'),
          'only a rules core has rules',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'kind: "rules"\ncards:'),
          'a rules deck is written as a core and layers',
        ),
        (
          single('  []\n').replaceFirst('cards:', 'kind: "lexicon"\ncards:'),
          'kind must be vocab, grammar or reading',
        ),
      ]) {
        expect(() => parse(yaml), fails(why), reason: why);
      }
    });

    test('a layer with a part is a layer, as the validator dispatches', () {
      expect(
        () => parse(homeLayer.replaceFirst('kind:', 'part: "core"\nkind:')),
        fails('this is a layer'),
      );
      expect(
        () => layerOf(homeLayer.replaceFirst('kind:', 'part: "core"\nkind:')),
        fails('a layer has no part; only a core is marked part: "core"'),
      );
      expect(
        () => coreOf(homeLayer.replaceFirst('kind:', 'part: "core"\nkind:')),
        fails('a layer has no part'),
      );
    });
  });

  group('typed notes (6.1)', () {
    final deck = parse(words);
    Card card(String id) => deck.cards.firstWhere((c) => c.id == id);

    test('text is one note of kind note, and blank text is none', () {
      final note = card('zz-9401').notes.single;
      expect(note.id, '1');
      expect(note.kind, NoteKind.note);
      expect(note.text, 'Plural in form.');
      expect(card('zz-9403').notes, isEmpty);
      expect(parse(oneCard('    notes: "   "\n')).cards.single.notes, isEmpty);
    });

    test('a list of notes, ids by position, placeholders filled', () {
      final notes = card('zz-9402').notes;
      expect(notes.map((n) => n.kind), [NoteKind.usage, NoteKind.pair]);
      expect(notes.map((n) => n.id), ['1', '2']);
      expect(notes.last.ref, 'zz-9403');
      expect(notes.last.text, 'Not బండి (baṇḍi), cart.');
    });

    test('a pair note gives the card its pair, unless pair is written', () {
      expect(card('zz-9402').pair, 'zz-9403');
      final written = parse(
        oneCard('''
    pair: "zz-0002"
    notes:
      - { kind: "pair", ref: "zz-0003", text: "Not this one." }
'''),
      ).cards.single;
      expect(written.pair, 'zz-0002');
    });

    test('ids, kinds, sources and words', () {
      final notes = parse(
        oneCard('''
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

    test('malformed notes are refused', () {
      for (final (notes, why) in <(String, String)>[
        ('    notes: []\n', 'must not be an empty list; leave it out'),
        ('    notes: { kind: "note" }\n', 'must be text, or a list of notes'),
        ('    notes: 5\n', 'was read as a number'),
        ('    notes: ["text"]\n', 'notes[0] must be a mapping'),
        (
          '    notes: [{ kind: "trivia", text: "x" }]\n',
          'notes[0].kind must be one of behaviour, culture, note, pair, '
              'usage, got "trivia"',
        ),
        ('    notes: [{ kind: "note" }]\n', 'missing required field "text"'),
        ('    notes: [{ kind: "note", text: " " }]\n', 'must not be empty'),
        (
          '    notes: [{ kind: "note", text: "x", colour: "red" }]\n',
          'unknown field "colour"',
        ),
        (
          '    notes: [{ kind: "culture", text: "x" }]\n',
          'notes[0].source: a culture note names where its claims can be '
              'checked',
        ),
        (
          '    notes: [{ kind: "pair", text: "x" }]\n',
          'notes[0].ref: a pair note names its partner, the id of another zz '
              'card',
        ),
        (
          '    notes: [{ kind: "usage", text: "x", ref: "zz-0002" }]\n',
          'notes[0].ref is only for a pair note',
        ),
        (
          '    notes: [{ id: "1st", kind: "note", text: "x" }]\n',
          'notes[0].id must start with a letter and match [a-z0-9-]+, and not '
              'be a YAML 1.1 boolean word, got "1st"',
        ),
        (
          '    notes: [{ id: "no", kind: "note", text: "x" }]\n',
          'not be a YAML 1.1 boolean word, got "no"',
        ),
        (
          '    notes: [{ id: "a", kind: "note", text: "x" }, '
              '{ id: "a", kind: "usage", text: "y" }]\n',
          'notes[1].id "a" is used twice',
        ),
        (
          '    notes: [{ kind: "note", text: "x", words: "కలాలు" }]\n',
          'notes[0].words must be a list of { word, reading }',
        ),
        (
          '    notes: [{ kind: "note", text: "x", words: [{ reading: "a" }] }]\n',
          'missing required field "word"',
        ),
      ]) {
        expect(() => parse(oneCard(notes)), fails(why), reason: why);
      }
    });

    test('a region note names its regions, one or a list (10.5)', () {
      final notes = parse(
        oneCard('''
    notes:
      - { kind: "usage", region: "telangana", text: "In Telangana often {1}.", words: [{ word: "ఉల్లిగడ్డ", reading: "ulligaḍḍa" }] }
      - { kind: "note", region: ["coastal-andhra", "rayalaseema"], text: "Heard so on the coast and in the south." }
      - { kind: "note", text: "Everywhere." }
'''),
      ).cards.single.notes;
      expect(notes[0].regions, ['telangana']);
      expect(notes[0].text, 'In Telangana often ఉల్లిగడ్డ (ulligaḍḍa).');
      expect(notes[1].regions, ['coastal-andhra', 'rayalaseema']);
      expect(notes[2].regions, isEmpty);
      for (final (region, why) in <(String, String)>[
        ('5', 'notes[0].region must be a region id, or a list of them'),
        ('[]', 'notes[0].region must be a region id, or a list of them'),
        ('"Telangana"', 'notes[0].region must be a region id'),
        ('"no"', 'notes[0].region must be a region id'),
        (
          '["telangana", "telangana"]',
          'notes[0].region lists "telangana" twice',
        ),
      ]) {
        expect(
          () => parse(
            oneCard(
              '    notes: [{ kind: "usage", text: "x", region: $region }]\n',
            ),
          ),
          fails(why),
          reason: region,
        );
      }
    });

    test('a core note\'s regions are the core\'s, kept when merged', () {
      final core = homeCore.replaceFirst(
        '{ id: "address", kind: "usage" }',
        '{ id: "address", kind: "usage", region: ["telangana", "rayalaseema"] }',
      );
      final note = merge(
        core,
        homeLayer,
      ).cards.firstWhere((c) => c.id == 'zz-9004').notes.single;
      expect(note.id, 'address');
      expect(note.regions, ['telangana', 'rayalaseema']);
      expect(
        merge(
          homeCore,
          homeLayer,
        ).cards.firstWhere((c) => c.id == 'zz-9004').notes.single.regions,
        isEmpty,
      );
    });

    test('placeholders count from {1}, without leading zeros, to the words '
        '(6.4)', () {
      for (final (text, why) in <(String, String)>[
        (
          '{0}',
          '{0} is not a placeholder: placeholders count from {1}, '
              'without leading zeros',
        ),
        ('{01}', '{01} is not a placeholder'),
        ('{2}', 'notes[0].text uses {2}, but the note has 1 words'),
        ('{1}', 'uses {1}, but the note has 0 words'),
      ]) {
        final words = text == '{1}'
            ? ''
            : ', words: [{ word: "కలాలు", reading: "kalālu" }]';
        expect(
          () => parse(
            oneCard('    notes: [{ kind: "note", text: "$text"$words }]\n'),
          ),
          fails(why),
          reason: why,
        );
      }
    });
  });

  group('bases, the phrasebook, rules and Wiktionary on single-file cards', () {
    final deck = parse(words);
    Card card(String id) => deck.cards.firstWhere((c) => c.id == id);

    test('are read', () {
      final hello = card('zz-9404');
      expect(hello.phrasebook, isTrue);
      expect(hello.rules, ['zz-rule-ki']);
      final base = hello.bases.single;
      expect(base.word, 'నమస్కారం');
      expect(base.ref, isNull);
      expect(base.base, 'నమస్కారం');
      expect(base.reading, 'namaskāram');
      expect(base.meaning, 'a greeting');
      expect(base.wiktionary, isTrue);

      final fruit = card('zz-9402');
      expect(fruit.wiktionary, isTrue);
      expect(fruit.phrasebook, isFalse);
      expect(fruit.rules, isEmpty);
      expect(fruit.examples.single.bases.single.meaning, 'to eat');
      expect(card('zz-9401').wiktionary, isFalse);
      expect(card('zz-9401').bases, isEmpty);

      expect(deck.refs.map((r) => (r.id, r.wiktionary)), [
        ('zz-9301', null),
        ('zz-9302', true),
      ]);
      final byRef = parse(
        oneCard('    bases: [{ word: "కలం", ref: "zz-0002" }]\n'),
      ).cards.single.bases.single;
      expect(byRef.ref, 'zz-0002');
      expect(byRef.base, isNull);
      expect(byRef.wiktionary, isFalse);
    });

    test('a mark is true, unquoted, or left out', () {
      for (final (field, why) in <(String, String)>[
        (
          '    phrasebook: false\n',
          'phrasebook must be true, unquoted, or left out; got false',
        ),
        ('    phrasebook: "true"\n', 'phrasebook must be true, unquoted'),
        (
          '    wiktionary: false\n',
          'wiktionary must be true, or left out where Wiktionary has no '
              'entry; got false',
        ),
        ('    wiktionary: 1\n', 'wiktionary must be true'),
        (
          '    bases: [{ word: "కలం", base: "కలం", reading: "kalam", '
              'meaning: "pen", wiktionary: "yes" }]\n',
          'bases[0]: wiktionary must be true',
        ),
      ]) {
        expect(() => parse(oneCard(field)), fails(why), reason: why);
      }
      expect(
        () => parse(single('  - ref: "zz-0001"\n    wiktionary: false\n')),
        fails('wiktionary must be true'),
      );
    });

    test('malformed bases and rules are refused', () {
      for (final (field, why) in <(String, String)>[
        (
          '    bases: "కలం"\n',
          'bases must be a list of { word, ref } or { word, base, reading }',
        ),
        ('    bases: [{ ref: "zz-0002" }]\n', 'missing required field "word"'),
        (
          '    bases: [{ word: "కలం", ref: "zz-0002", base: "కలం" }]\n',
          'bases[0] gives ref or base, not both',
        ),
        (
          '    bases: [{ word: "కలం" }]\n',
          'bases[0] needs ref, or base and its reading',
        ),
        (
          '    bases: [{ word: "కలం", base: "కలం", reading: "kalam" }]\n',
          'bases[0].meaning is required beside base',
        ),
        (
          '    bases: [{ word: "కలం", ref: "zz-0002", reading: "kalam" }]\n',
          'bases[0].reading is only for a base written in full',
        ),
        (
          '    bases: [{ word: "కలం", ref: "zz-0002", gloss: "x" }]\n',
          'unknown field "gloss"',
        ),
        (
          '    rules: "zz-rule-ki"\n',
          'rules must be a list of rule ids, such as ["zz-rule-past"]',
        ),
        (
          '    rules: ["te-rule-ki"]\n',
          'rules[0] must be a zz rule id, zz-rule- and a name, got '
              '"te-rule-ki"',
        ),
        ('    rules: ["zz-rule-"]\n', 'must be a zz rule id'),
        (
          '    rules: ["zz-rule-ki", "zz-rule-ki"]\n',
          'rules lists "zz-rule-ki" twice',
        ),
      ]) {
        expect(() => parse(oneCard(field)), fails(why), reason: why);
      }
    });

    test('a ref cannot give the phrasebook mark, bases or rules', () {
      for (final key in const <String>['phrasebook', 'bases', 'rules']) {
        expect(
          () => parse(single('  - ref: "zz-0001"\n    $key: true\n')),
          fails('unknown field "$key"'),
          reason: key,
        );
      }
    });

    test('grammarUnderstood is refused in modes (4.7)', () {
      expect(
        () => parse(oneCard('    modes: ["grammarUnderstood"]\n')),
        fails("grammarUnderstood is only for a rules table's cells"),
      );
      expect(
        () => parse(oneCard('    modes: ["typing"]\n')),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('unknown mode'), isNot(contains('Understood'))),
          ),
        ),
      );
    });
  });

  group('cores (2.2 to 2.5)', () {
    test('a vocab core keeps the language side of its cards', () {
      final core = coreOf(homeCore);
      expect(core.id, 'zz-home');
      expect(core.kind, DeckKind.vocab);
      expect(core.language.code, 'zz');
      expect(core.tags, ['unreviewed']);
      expect(core.cards, hasLength(20));
      final home = core.cards.first as CoreWritten;
      expect(home.target, 'ఇల్లు');
      expect(home.notes.single.id, 'stem');
      expect(home.notes.single.words.single.shown, 'ఇంటి- (iṇṭi-)');
      final sentence = core.cards[4] as CoreWritten;
      expect(sentence.rules, ['zz-rule-ki']);
      expect(sentence.bases.map((b) => b.ref), ['zz-9001', 'zz-9003']);
      expect((core.cards.last as CoreWritten).phrasebook, isTrue);
    });

    test('a core lists refs, with core-form notes and examples', () {
      final core = coreOf(read('$features/zz-market.yaml'));
      final refs = core.cards.whereType<CoreRef>().toList();
      expect(refs.map((r) => r.id), ['zz-9401', 'zz-9402']);
      expect(refs.first.notes, isNull);
      expect(refs.last.notes!.single.kind, NoteKind.usage);
      expect(refs.last.examples!.single.target, 'పండు తిను.');
      final pen = core.cards.first as CoreWritten;
      expect(pen.notes.map((n) => n.id), ['pair', 'school', 'plural']);
      expect(pen.notes.first.ref, 'zz-9302');
      expect(pen.notes[1].source, 'https://example.org/school');
      expect(pen.examples.first.bases.single.meaning, isNull);
      expect(core.theme, 'market');
    });

    test('what is the learner\'s language is refused in a core', () {
      String card(String extra) => homeCore.replaceFirst(
        '    target: "ఇల్లు"\n',
        '    target: "ఇల్లు"\n$extra',
      );
      for (final (yaml, why) in <(String, String)>[
        (
          homeCore.replaceFirst('license:', 'native: { code: "en" }\nlicense:'),
          'a core file has no native: the language it is taught from is in '
              'each layer, in decks/zz/<native>/',
        ),
        (
          homeCore.replaceFirst('license:', 'name: "Home"\nlicense:'),
          "a core file's name is in each layer, in the learner's language",
        ),
        (
          homeCore.replaceFirst('license:', 'description: "x"\nlicense:'),
          "a core file's description is in each layer",
        ),
        (
          card('    native: "home"\n'),
          'a core card\'s "native" is in each layer, under cards.zz-9001',
        ),
        (card('    alt_native: ["house"]\n'), 'a core card\'s "alt_native"'),
        (card('    wiktionary: true\n'), 'a core card\'s "wiktionary"'),
        (
          card('    pair: "zz-9004"\n'),
          'pair: in a core file a pair note names the partner',
        ),
        (
          homeCore.replaceFirst(
            '{ id: "address", kind: "usage" }',
            '{ id: "address", kind: "usage", text: "x" }',
          ),
          "notes[0].text: a core note's text is in each layer",
        ),
        (
          homeCore.replaceFirst(
            '{ id: "address", kind: "usage" }',
            '{ kind: "usage" }',
          ),
          'notes[0].id is required in a core file: each layer names the note '
              'by it',
        ),
        (
          homeCore.replaceFirst(
            '    notes:\n      - { id: "stem", kind: "behaviour", words: '
                '[{ word: "ఇంటి-", reading: "iṇṭi-" }] }\n',
            '    notes: "A house."\n',
          ),
          'cards[0].notes must be a list of notes in a core file; their text '
              'is in each layer',
        ),
        (
          card('    examples: [{ target: "ఇల్లు.", native: "A house." }]\n'),
          "a core example's translation is in each layer, keyed by its target",
        ),
        (
          card('    examples: [{ target: "ఇల్లు." }, { target: "ఇల్లు." }]\n'),
          'examples[1] has the same target as cards[0].examples[0]',
        ),
        (
          card(
            '    bases: [{ word: "ఇల్లు", base: "ఇల్లు", reading: "illu", '
            'meaning: "house" }]\n',
          ),
          "bases[0].meaning: a core file's meanings are in each layer",
        ),
        (
          homeCore.replaceFirst('kind: "vocab"', 'kind: "reading"'),
          'a core is vocab, grammar or rules, got "reading"; a reading deck '
              'stays a single-file deck',
        ),
        (
          homeCore.replaceFirst('kind: "vocab"', 'kind: "facts"'),
          'a core is vocab, grammar or rules, got "facts"',
        ),
        (
          homeCore.replaceFirst('id: "zz-home"', 'id: "te-home"'),
          'id must be zz- and a name, the filename stem, got "te-home"',
        ),
        (
          homeCore.replaceFirst('part: "core"\n', ''),
          'a core file is marked part: "core"',
        ),
        (
          homeCore.replaceFirst('part: "core"', 'part: "base"'),
          'a core file is marked part: "core", got "base"',
        ),
      ]) {
        expect(() => coreOf(yaml), fails(why), reason: why);
      }
    });

    test('a grammar core leaves its names and glosses to each layer', () {
      final core = coreOf(pastCore);
      expect(core.kind, DeckKind.grammar);
      expect(core.pattern!.slots, ['నేను', 'నువ్వు']);
      expect(core.pattern!.entries.map((e) => e.idPart), ['vellu', 'tinu']);
      expect(
        () => coreOf(
          pastCore.replaceFirst('  slots:', '  name: "Past"\n  slots:'),
        ),
        fails('a core pattern\'s "name" is in each layer, under pattern'),
      );
      expect(
        () => coreOf(
          pastCore.replaceFirst(
            '      key: "tinu"',
            '      key: "tinu"\n      gloss: "to eat"',
          ),
        ),
        fails(
          "a core entry's gloss is in each layer, under "
          'pattern.entries.tinu',
        ),
      );
    });

    test('a rules core: its table and its rules', () {
      final core = coreOf(rulesCore);
      expect(core.kind, DeckKind.rules);
      final table = core.table!;
      expect(table.appliesTo.pos, ['noun']);
      expect(table.slots, ['lo', 'ki', 'to', 'nunci']);
      expect(table.rows.map((r) => r.idPart), ['9001', '9004']);
      expect(table.rows.first.forms['nunci'], 'ఇంటి నుంచి');
      expect(table.rows.first.readings['lo'], ['iṇṭlō']);
      expect(core.rules.map((r) => r.id), [
        'zz-rule-lo',
        'zz-rule-ki',
        'zz-rule-to',
        'zz-rule-nunci',
      ]);
      expect(core.rules.first.words, hasLength(3));
    });

    test('a malformed rules core is refused (4.2)', () {
      for (final (yaml, why) in <(String, String)>[
        (
          rulesCore.replaceFirst('"lo", "ki"', '"1st", "ki"'),
          'table.slots[0] must start with a letter and match [a-z0-9-]+, and '
              'not be a YAML 1.1 boolean word, got "1st"',
        ),
        (
          rulesCore.replaceFirst('"lo", "ki"', '"n", "ki"'),
          'not be a YAML 1.1 boolean word, got "n"',
        ),
        (
          rulesCore.replaceFirst('"lo", "ki"', '"lo", "lo"'),
          'table.slots contains duplicates',
        ),
        (
          rulesCore.replaceFirst(
            '    slots: ["ki"]',
            '    slots: ["ki", "lo"]',
          ),
          'rule zz-rule-ki: "lo" is also in rule zz-rule-lo; a slot belongs to '
              'one rule',
        ),
        (
          rulesCore.replaceFirst('    slots: ["ki"]', '    slots: ["at"]'),
          'rule zz-rule-ki: "at" is not a slot of the table',
        ),
        (
          rulesCore.replaceFirst('    slots: ["ki"]', '    slots: []'),
          "rule zz-rule-ki: slots must be a non-empty list of the table's "
              'slots',
        ),
        (
          rulesCore.replaceFirst(
            '  - id: "zz-rule-nunci"\n    slots: ["nunci"]',
            '  - id: "zz-rule-nunci"\n    slots: ["to"]',
          ),
          'rule zz-rule-nunci: "to" is also in rule zz-rule-to',
        ),
        (
          rulesCore.replaceFirst(
            '  - id: "zz-rule-nunci"\n    slots: ["nunci"]\n'
                '    words: [{ word: "నుంచి", reading: "nuñci" }]\n',
            '',
          ),
          'table.slots: "nunci" belongs to no rule',
        ),
        (
          rulesCore.replaceFirst('id: "zz-rule-to"', 'id: "zz-to"'),
          'rules[2]: id must be zz-rule- and a name, such as zz-rule-past, got '
              '"zz-to"',
        ),
        (
          rulesCore.replaceFirst('id: "zz-rule-to"', 'id: "zz-rule-ki"'),
          'rule zz-rule-ki: duplicate rule id',
        ),
        (
          rulesCore.replaceFirst('- word: "zz-9004"', '- word: "zz-9001"'),
          'table.rows[zz-9001]: zz-9001 has a row already',
        ),
        (
          rulesCore.replaceFirst(
            '- word: "zz-9004"',
            '- word: "zz-9004"\n      key: "9001"',
          ),
          'table.rows[zz-9004]: "9001" already names another row; give one of '
              'them a key',
        ),
        (rulesCore.replaceFirst('"ki": "అమ్మకి", ', ''), 'missing slot "ki"'),
        (
          rulesCore.replaceFirst(
            '{ "lo": "అమ్మలో", "ki": "అమ్మకి", "to": "అమ్మతో", "nunci": "అమ్మ నుంచి" }',
            '{ "lo": null, "ki": null, "to": null, "nunci": null }',
          ),
          'every form is null',
        ),
        (
          rulesCore.replaceFirst('pos: ["noun"]', 'pos: []'),
          'table.applies_to.pos must be a non-empty list of parts of speech',
        ),
        (
          rulesCore.replaceFirst('  applies_to: { pos: ["noun"] }\n', ''),
          'missing required field "applies_to"',
        ),
        (
          rulesCore.replaceFirst('  rows:', '  colour: "red"\n  rows:'),
          'unknown field "colour"',
        ),
        (
          rulesCore.replaceFirst('rules:\n', 'cards: []\nrules:\n'),
          'a rules deck has a table and rules, not cards',
        ),
        (
          rulesCore.replaceFirst('license:', 'theme: "home"\nlicense:'),
          'a rules deck has no theme',
        ),
        (
          rulesCore.replaceFirst(RegExp(r'rules:\n[\s\S]*$'), ''),
          'missing required field "rules"',
        ),
      ]) {
        expect(() => coreOf(yaml), fails(why), reason: why);
      }
    });
  });

  group('layers (2.6)', () {
    test('a layer gives the learner\'s language, keyed by card id', () {
      final layer = layerOf(homeLayer);
      expect(layer.id, 'zz-en-home');
      expect(layer.core, 'zz-home');
      expect(layer.native.code, 'en');
      expect(layer.name, 'Home');
      expect(layer.cards, hasLength(20));
      final home = layer.cards['zz-9001']! as LayerEntry;
      expect(home.native, 'home; house');
      expect(home.wiktionary, isTrue);
      expect(home.notes!['stem']!.text, startsWith('Before an ending'));
      expect((layer.cards['zz-9004']! as LayerEntry).wiktionary, isNull);
    });

    test('an entry with a target is a card only the layer has', () {
      final layer = layerOf(marketLayer);
      final curry = layer.cards['zz-9501']! as LayerOnlyCard;
      expect(curry.card.id, 'zz-9501');
      expect(curry.card.deckId, 'zz-en-market');
      expect(curry.card.wiktionary, isTrue);
      expect(curry.card.notes.single.kind, NoteKind.culture);
    });

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
          homeLayer.replaceFirst('name: "Home"', 'theme: "home"\nname: "Home"'),
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
              'gives native, alt_native, notes, examples, bases and wiktionary',
        ),
        (
          homeLayer.replaceFirst('      "address": "Also', '      true: "Also'),
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
      expect(deck.license, 'CC0-1.0');
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

    test('notes and examples without the layer\'s text are left out; pair '
        'from the first pair note', () {
      final pen = merge(marketCore, marketLayer).cards.first;
      expect(pen.notes.map((n) => n.id), ['pair', 'plural']);
      expect(pen.notes.first.ref, 'zz-9302');
      expect(pen.notes.last.text, 'Its plural is కలాలు (kalālu).');
      expect(pen.pair, 'zz-9302');
      expect(pen.altNative, ['ink pen']);
      expect(pen.picture, '🖊');
      final example = pen.examples.single;
      expect(example.target, 'నా కలం.');
      expect(example.native, 'my pen');
      expect(example.reading, 'nā kalam.');
      expect(example.bases.single.base, 'నేను');
      expect(example.bases.single.meaning, 'I');
      expect(example.bases.single.wiktionary, isTrue);

      final chunk = merge(marketCore, marketLayer).cards[2];
      expect(chunk.phrasebook, isTrue);
      expect(chunk.bases.map((b) => (b.word, b.meaning, b.wiktionary)), [
        ('నాకు', 'to me', false),
        ('రాదు', 'to come; here, to know', true),
      ]);
      // The Bengali layer gives zz-9301 no notes, so it has no pair.
      expect(merge(marketCore, marketBengali).cards.first.pair, isNull);
      expect(merge(marketCore, marketBengali).cards.first.notes, isEmpty);
    });

    test('the deck\'s header from each side', () {
      final deck = merge(marketCore, marketLayer);
      expect(deck.name, 'At the market');
      expect(deck.description, 'Buying and selling.');
      expect(deck.license, 'CC0-1.0 AND CC-BY-4.0');
      expect(deck.authors.map((a) => a.name), ['Core author', 'Layer author']);
      expect(deck.source, 'https://example.org/core');
      expect(deck.theme, 'market');
      // The core says reviewed, the layer unreviewed: unreviewed it is.
      expect(deck.tags, ['market', 'unreviewed']);
      expect(
        merge(
          marketCore,
          marketLayer.replaceFirst(
            'tags: ["unreviewed", "market"]',
            'tags: []',
          ),
        ).tags,
        ['market', 'reviewed'],
      );
    });

    test('a grammar core and its layer', () {
      final deck = merge(pastCore, pastLayer);
      expect(deck.kind, DeckKind.grammar);
      final pattern = deck.pattern!;
      expect(pattern.name, 'Past tense');
      expect(pattern.slotName, 'person');
      expect(pattern.slots, ['నేను', 'నువ్వు']);
      expect(pattern.entries.map((e) => (e.idPart, e.gloss)), [
        ('vellu', 'to go'),
      ]);
      expect(pattern.notes, startsWith('The past adds'));
      final cells = expandPattern(deck);
      expect(cells.map((c) => c.id), [
        'zz-grammar-past-vellu-0',
        'zz-grammar-past-vellu-1',
      ]);
      expect(cells.map((c) => c.native), [
        'వెళ్ళు (to go) — I, నేను (nēnu)',
        'వెళ్ళు (to go) — నువ్వు',
      ]);
      expect(cells.first.reading, 'veḷḷānu');
    });

    test('a layer that does not fit its core is refused', () {
      for (final (core, layer, why) in <(String, String, String)>[
        (
          homeCore,
          homeLayer.replaceFirst('core: "zz-home"', 'core: "zz-house"'),
          'core: this layer is of zz-house, not of zz-home',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('id: "zz-en-home"', 'id: "zz-en-house"'),
          'id: a layer of zz-home taught from en has id "zz-en-home", got '
              '"zz-en-house"',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('  "zz-9004":', '  "zz-9999":'),
          'cards.zz-9999: zz-9999 is not a card of zz-home; a card only this '
              'layer has gives its target too',
        ),
        (
          homeCore,
          homeLayer.replaceFirst(
            '    native: "I will go home."\n',
            '    native: "I will go home."\n    target: "ఇంటికి."\n',
          ),
          'cards.zz-9002: "target" belongs to the word, in the core',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('    native: "I"\n', ''),
          'cards.zz-9006: native is required: without it the card is not '
              'taught from English',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('      "drop":', '      "fall":'),
          'cards.zz-9006.notes.fall: the core card has no note "fall"',
        ),
        (
          homeCore,
          homeLayer.replaceFirst(
            '    native: "I will go home."\n',
            '    native: "I will go home."\n    examples: { "ఇల్లు.": "A house." }\n',
          ),
          'cards.zz-9002.examples.ఇల్లు.: the core card has no example with '
              'this target',
        ),
        (
          homeCore,
          homeLayer.replaceFirst(
            '    native: "I will go home."\n',
            '    native: "I will go home."\n    bases: { "ఇంటికి": "home" }\n',
          ),
          'cards.zz-9002.bases.ఇంటికి: the core card has no inline base for '
              '"ఇంటికి"; a base given by ref takes its meaning from that card',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('becomes {1}', 'becomes {2}'),
          'cards.zz-9001.notes.stem uses {2}, but the note has 1 words',
        ),
        (
          homeCore,
          homeLayer.replaceFirst('becomes {1}', 'becomes {0}'),
          'cards.zz-9001.notes.stem: {0} is not a placeholder',
        ),
        (
          marketCore,
          marketLayer.replaceFirst(
            '  "zz-9305":',
            '  "zz-9401":\n    notes: { "use": "x" }\n  "zz-9305":',
          ),
          'cards.zz-9401.notes: the core lists zz-9401 by ref without notes; '
              "give them in the core's ref",
        ),
        (
          marketCore,
          marketLayer.replaceFirst(
            '  "zz-9305":',
            '  "zz-9401":\n    examples: { "x": "y" }\n  "zz-9305":',
          ),
          'the core lists zz-9401 by ref without examples',
        ),
        (
          homeCore,
          homeLayer.replaceFirst(
            'cards:',
            'pattern: { name: "x", slot_name: "y", prompt: "z", entries: {} }\n'
                'cards:',
          ),
          'pattern: only a layer of a grammar core has it',
        ),
        (
          homeCore,
          homeLayer.replaceFirst(RegExp(r'cards:\n[\s\S]*$'), ''),
          'missing required field "cards": a layer of a vocab core gives it',
        ),
        (
          pastCore,
          pastLayer.replaceFirst('{ "నేను": "I', '{ "మేము": "I'),
          'pattern.slots: "మేము" is not a slot of the core',
        ),
        (
          pastCore,
          pastLayer.replaceFirst('{ "vellu": "to go" }', '{ "pō": "to go" }'),
          'pattern.entries: "pō" is not an entry of the core',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst('    "nunci": "from {meaning}"\n', ''),
          'table.slots gives no label for "nunci"',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst(
            '    "nunci": "from {meaning}"\n',
            '    "nunci": "from {meaning}"\n    "at": "at {meaning}"\n',
          ),
          'table.slots: "at" is not a slot of the core',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst('    "zz-9001": {', '    "zz-9006": {'),
          'table.prompts: "zz-9006" is not a row of the core',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst('{ "lo": "at home"', '{ "at": "at home"'),
          'table.prompts.zz-9001: "at" is not a slot of the core',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst('  "zz-rule-to":', '  "zz-rule-with":'),
          'rules: "zz-rule-with" is not a rule of the core',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst(
            '"{1} follows the noun',
            '"{1} and {2} follow the noun',
          ),
          'rules.zz-rule-nunci.explanation uses {2}, but the rule has 1 words',
        ),
        (
          rulesCore,
          rulesLayer.replaceFirst(RegExp(r'rules:\n[\s\S]*$'), ''),
          'missing required field "rules": a layer of a rules core gives it',
        ),
      ]) {
        expect(() => merge(core, layer), fails(why), reason: why);
      }
    });
  });

  group('rules decks: expansion into cells (4.6)', () {
    final home = merge(homeCore, homeLayer);
    Card? wordOf(String id) => home.cards.where((c) => c.id == id).firstOrNull;
    List<Card> cells(String core, String layer, {Card? Function(String)? of}) =>
        expandRules(merge(core, layer), wordOf: of ?? wordOf);

    test('the merged deck carries its table and the rules its layer gives', () {
      final deck = merge(rulesCore, rulesLayer);
      expect(deck.id, 'zz-en-grammar-case-endings');
      expect(deck.kind, DeckKind.rules);
      expect(deck.cards, isEmpty);
      expect(deck.table!.slotName, 'case');
      expect(deck.table!.labels['ki'], 'to {meaning}');
      expect(deck.table!.rows.first.prompts, {
        'lo': 'at home',
        'ki': 'home (going there)',
      });
      expect(deck.rules.map((r) => r.id), [
        'zz-rule-lo',
        'zz-rule-ki',
        'zz-rule-to',
        'zz-rule-nunci',
      ]);
      expect(
        deck.rules.first.explanation,
        '-లో (-lō) means in. It joins the noun\'s oblique stem: ఇల్లు (illu) '
        'becomes ఇంట్లో (iṇṭlō).',
      );
      expect(deck.rules.first.name, '-లో (-lō): in');
    });

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
      expect(withMother.modes, {
        DrillMode.grammarUnderstood,
        DrillMode.grammar,
      });
      expect(withMother.notes, isEmpty);
    });

    test(
      'prompts: the layer\'s own, else the label with the first meaning',
      () {
        final natives = cells(rulesCore, rulesLayer).map((c) => c.native);
        expect(natives, [
          'at home',
          'home (going there)',
          'with home',
          'from home',
          'in mother',
          'to mother',
          'with mother',
          'from mother',
        ]);
        final bare = cells(
          rulesCore,
          rulesLayer.replaceFirst('"with {meaning}"', '"together"'),
        );
        expect(bare[6].native, 'mother: together');
      },
    );

    test('the rule cell: its rule, its word and the row\'s other forms', () {
      final cell = cells(rulesCore, rulesLayer)[6].rule!;
      expect(cell.ruleId, 'zz-rule-to');
      expect(cell.word, 'zz-9004');
      expect(cell.wordTarget, 'అమ్మ');
      expect(cell.wordReading, 'amma');
      expect(cell.slot, 'to');
      expect(cell.options.map((o) => (o.form, o.prompt)), [
        ('అమ్మలో', 'in mother'),
        ('అమ్మకి', 'to mother'),
        ('అమ్మ నుంచి', 'from mother'),
      ]);
    });

    test('what each grammar mode shows', () {
      final card = cells(rulesCore, rulesLayer)[6];
      // Understood: the form is shown, and its meaning chosen (OPEN-22).
      expect(card.promptFor(DrillMode.grammarUnderstood), 'అమ్మతో (ammatō)');
      expect(card.acceptedAnswers(DrillMode.grammarUnderstood), [
        'with mother',
      ]);
      // Produced: the word and the meaning, and the form given.
      expect(card.promptFor(DrillMode.grammar), 'అమ్మ (amma): with mother');
      expect(card.acceptedAnswers(DrillMode.grammar), ['అమ్మతో']);
      final unread = cells(
        rulesCore,
        rulesLayer,
        of: (id) {
          final word = wordOf(id);
          return word == null
              ? null
              : Card(
                  id: word.id,
                  deckId: word.deckId,
                  target: word.target,
                  native: word.native,
                );
        },
      )[6];
      expect(unread.promptFor(DrillMode.grammar), 'అమ్మ: with mother');
      // Both schedules, now that both questions are built (4.8).
      expect(card.modesIn(ttsAvailable: true), {
        DrillMode.grammarUnderstood,
        DrillMode.grammar,
      });
      // A grammar cell of a pattern keeps its prompt.
      final past = expandPattern(merge(pastCore, pastLayer)).first;
      expect(past.promptFor(DrillMode.grammar), past.native);
    });

    test('a row key keeps a converted deck\'s ids', () {
      final keyed = cells(
        rulesCore.replaceFirst(
          '    - word: "zz-9001"\n',
          '    - word: "zz-9001"\n      key: "illu"\n',
        ),
        rulesLayer,
      );
      expect(keyed.first.id, 'zz-grammar-case-endings-illu-0');
      expect(keyed.last.id, 'zz-grammar-case-endings-9004-3');
    });

    test('a row without a card in this language is skipped, and no id '
        'shifts', () {
      final cards = cells(
        rulesCore,
        rulesLayer,
        of: (id) => id == 'zz-9001' ? null : wordOf(id),
      );
      expect(cards.map((c) => c.id), [
        for (var i = 0; i < 4; i++) 'zz-grammar-case-endings-9004-$i',
      ]);
    });

    test('a rule the layer leaves out is not asked, nor offered', () {
      final layer = rulesLayer.replaceFirst(
        RegExp(r'  "zz-rule-ki":\n.*\n.*\n'),
        '',
      );
      final deck = merge(rulesCore, layer);
      expect(deck.rules.map((r) => r.id), [
        'zz-rule-lo',
        'zz-rule-to',
        'zz-rule-nunci',
      ]);
      final cards = expandRules(deck, wordOf: wordOf);
      expect(cards.map((c) => c.id.split('-').last).toSet(), {'0', '2', '3'});
      expect(cards, hasLength(6));
      for (final card in cards) {
        expect(
          card.rule!.options.map((o) => o.form),
          isNot(contains('అమ్మకి')),
        );
        expect(
          card.rule!.options.map((o) => o.form),
          isNot(contains('ఇంటికి')),
        );
      }
    });

    test('a null form is skipped, and equal forms are offered once', () {
      final cards = cells(
        rulesCore
            .replaceFirst('"ki": "అమ్మకి", ', '"ki": null, ')
            .replaceFirst('"ki": "ammaki", ', '')
            .replaceFirst('"nunci": "అమ్మ నుంచి"', '"nunci": "అమ్మలో"')
            .replaceFirst('"nunci": "amma nuñci"', '"nunci": "ammalō"'),
        rulesLayer,
      );
      expect(cards.where((c) => c.rule!.word == 'zz-9004').map((c) => c.id), [
        'zz-grammar-case-endings-9004-0',
        'zz-grammar-case-endings-9004-2',
        'zz-grammar-case-endings-9004-3',
      ]);
      final inMother = cards.firstWhere(
        (c) => c.id == 'zz-grammar-case-endings-9004-0',
      );
      expect(inMother.rule!.options.map((o) => o.form), ['అమ్మతో']);
      final withMother = cards.firstWhere(
        (c) => c.id == 'zz-grammar-case-endings-9004-2',
      );
      expect(withMother.rule!.options.map((o) => o.form), ['అమ్మలో']);
    });

    test('a row listing several forms', () {
      final cards = cells(
        rulesCore
            .replaceFirst('"ki": "అమ్మకి"', '"ki": ["అమ్మకి", "అమ్మకు"]')
            .replaceFirst('"ki": "ammaki"', '"ki": ["ammaki", "ammaku"]'),
        rulesLayer,
      );
      final toMother = cards[5];
      expect(toMother.target, 'అమ్మకి');
      expect(toMother.altTarget, ['అమ్మకు']);
      expect(toMother.altReading, ['ammaku']);
    });
  });

  group('counting words (8.5)', () {
    test('wordsForBases splits as the validator does', () {
      expect(wordsForBases('నేను ఇంటికి వెళ్తాను.'), [
        'నేను',
        'ఇంటికి',
        'వెళ్తాను',
      ]);
      expect(wordsForBases("l'eau, c'est 'bon'"), ["l'eau", "c'est", 'bon']);
      expect(wordsForBases('అమ్మ 1! 3a — x/y'), ['అమ్మ', '3a', 'x', 'y']);
      expect(wordsForBases('  '), isEmpty);
    });

    test('countsAsWord', () {
      Card card(String target, {String? pos, bool phrasebook = false}) => Card(
        id: 'zz-0001',
        deckId: 'd',
        target: target,
        native: 'x',
        pos: pos,
        phrasebook: phrasebook,
      );
      expect(countsAsWord(card('అమ్మ', pos: 'noun'), DeckKind.vocab), isTrue);
      expect(countsAsWord(card('అమ్మ'), DeckKind.vocab), isTrue);
      expect(
        countsAsWord(card('ఇంటి పేరు', pos: 'noun'), DeckKind.vocab),
        isTrue,
      );
      expect(
        countsAsWord(card('ఇంటి పేరు', pos: 'pronoun'), DeckKind.vocab),
        isTrue,
      );
      expect(
        countsAsWord(card('ఇంటి పేరు', pos: 'other'), DeckKind.vocab),
        isFalse,
      );
      expect(
        countsAsWord(card('అమ్మ!', pos: 'phrase'), DeckKind.vocab),
        isFalse,
      );
      expect(
        countsAsWord(card('అమ్మ', phrasebook: true), DeckKind.vocab),
        isFalse,
      );
      for (final kind in [DeckKind.grammar, DeckKind.rules, DeckKind.reading]) {
        expect(countsAsWord(card('అమ్మ', pos: 'noun'), kind), isFalse);
      }
      final home = merge(homeCore, homeLayer);
      expect(
        home.cards.where((c) => countsAsWord(c, home.kind)).map((c) => c.id),
        ['zz-9001', 'zz-9004', 'zz-9006', 'zz-9003'],
        reason: 'Appendix A counts 4 words',
      );
    });
  });

  group('the language\'s path and its B1 plan (9.5, 10)', () {
    final language = parseLanguagePath(read('$appendix/zz-path.yaml'));
    final path = language.forNative('en', exists: (_) => true);

    test('Appendix A\'s plan, by core id', () {
      expect(language.id, 'zz-path');
      expect(language.plan.first.decks, ['zz-home']);
      expect(language.plan[2].planned!.id, 'zz-health');
      expect(language.regions.map((r) => r.id), [
        'telangana',
        'coastal-andhra',
        'rayalaseema',
      ]);
      expect(language.regions[1].nameIn('bn'), 'Coastal Andhra');
    });

    test('Appendix A\'s plan, as learners from English are taught it', () {
      expect(path.units, [
        ['zz-en-home'],
        ['zz-en-grammar-case-endings'],
      ]);
      expect(path.open, isEmpty);
      expect(path.plan, hasLength(3));
      expect(path.hasB1Plan, isTrue);
      expect(path.plan.first.decks, ['zz-en-home']);
      expect(path.plan.first.words, 4);
      expect(path.plan.first.milestone, Milestone.a1);
      expect(path.plan[1].grammar, ['lo', 'ki', 'to', 'nunci']);
      expect(path.plan[1].words, isNull);
      final planned = path.plan[2];
      expect(planned.isPlanned, isTrue);
      expect(planned.isComing, isTrue);
      expect(planned.decks, isEmpty);
      expect(planned.planned!.id, 'zz-health');
      expect(planned.planned!.theme, 'health');
      expect(planned.words, 60);
      expect(planned.listeningPassages.single.id, 'doctor-call');
      expect(
        planned.listeningPassages.single.textIn('en'),
        "Booking a doctor's appointment by phone",
      );
      expect(planned.listeningPassages.single.textIn('bn'), isNull);
      expect(planned.readingPassages.single.id, 'clinic-notice');
      expect(path.milestoneIndex(Milestone.a1), 0);
      expect(path.milestoneIndex(Milestone.a2), 1);
      expect(path.milestoneIndex(Milestone.b1), 2);
      expect(path.grammarTopics, ['lo', 'ki', 'to', 'nunci']);
      expect(path.plannedWords, 64);
      expect(path.placing(const [], (_) => null).plan, same(path.plan));
    });

    test('every native language reads the same plan', () {
      final fromBengali = language.forNative(
        'bn',
        exists: (id) => id == 'zz-bn-home',
      );
      expect(fromBengali.units, [
        ['zz-bn-home'],
      ]);
      expect(fromBengali.plan[1].isComing, isTrue);
      expect(fromBengali.plan[1].decks, isEmpty);
      for (final p in <CoursePath>[path, fromBengali]) {
        expect(p.hasB1Plan, language.hasB1Plan);
        expect(p.grammarTopics, language.grammarTopics);
        expect(p.plannedWords, language.plannedWords);
        expect(p.milestoneIndex(Milestone.b1), 2);
      }
    });

    String pathOf(String units) => '''
schema: 1
kind: "path"
id: "zz-path"
language: "zz"
alphabet: ["zz-script"]
units:
$units''';

    CoursePath english(String text) =>
        parseLanguagePath(text).forNative('en', exists: (_) => true);

    test('a path of lists has no plan, and reads as it always did', () {
      final lists = english(
        pathOf('  - ["zz-script"]\n  - ["zz-home", "*"]\n  - ["*"]\n'),
      );
      expect(lists.hasB1Plan, isFalse);
      expect(lists.units, [
        ['zz-en-script'],
        ['zz-en-home'],
        <String>[],
      ]);
      expect(lists.open, {1, 2});
      expect(lists.plan.map((u) => u.decks), [
        ['zz-en-script'],
        ['zz-en-home'],
        <String>[],
      ]);
      expect(lists.plan.map((u) => u.open), [false, true, true]);
      expect(lists.grammarTopics, isEmpty);
      expect(lists.plannedWords, 0);
    });

    test('mapping and planned units beside list units', () {
      final mixed = english(
        pathOf('''
  - ["zz-script"]
  - planned: { id: "zz-grammar-conditional", grammar: "conditional" }
    listening_passages:
      - { id: "rain-plans", text: { "en": "Plans if it rains" } }
    reading_passages:
      - { id: "late-train", text: { "en": "A message: if the train is late" } }
  - decks: ["zz-grammar-differences"]
    words: 0
  - decks: ["zz-home", "*"]
    words: 45
    grammar: "be"
    milestone: "A1"
  - ["*"]
'''),
      );
      expect(mixed.units, [
        ['zz-en-script'],
        ['zz-en-grammar-differences'],
        ['zz-en-home'],
        <String>[],
      ]);
      expect(mixed.open, {2, 3}, reason: 'indices into units, not plan');
      expect(mixed.plan, hasLength(5));
      expect(mixed.plan[1].planned!.theme, isNull);
      expect(mixed.plan[1].grammar, ['conditional']);
      expect(mixed.plan[1].words, isNull);
      expect(mixed.plan[2].words, 0);
      expect(mixed.plan[3].grammar, ['be']);
      expect(mixed.plan[3].open, isTrue);
      expect(mixed.hasB1Plan, isTrue);
      expect(mixed.unitOf('zz-en-home'), 2);
      expect(mixed.grammarTopics, ['conditional', 'be'], reason: 'no B1 mark');
      expect(mixed.plannedWords, 45);
    });

    test('a malformed unit is refused', () {
      const passages =
          '    listening_passages: [{ id: "x", text: { "en": "x" } }]\n'
          '    reading_passages: [{ id: "y", text: { "en": "y" } }]\n';
      for (final (units, why) in <(String, String)>[
        (
          '  - decks: ["zz-home"]\n    size: 4\n',
          'units[0]: unknown field "size" in a unit',
        ),
        (
          '  - decks: ["zz-home"]\n    planned: { id: "zz-x", theme: "x", '
              'words: 1 }\n',
          'units[0] has decks or planned, not both',
        ),
        ('  - words: 4\n', 'units[0] has neither decks nor planned'),
        ('  - "zz-home"\n', 'a list of core ids, or a mapping'),
        (
          '  - decks: ["zz-en-home", "yy-home"]\n',
          '"yy-home" is not a core id of zz',
        ),
        (
          '  - decks: ["zz-home"]\n    words: -1\n',
          'units[0].words must be a whole number of words, 0 or more, got "-1"',
        ),
        (
          '  - decks: ["zz-home"]\n    words: true\n',
          'units[0].words must be a whole number of words',
        ),
        (
          '  - decks: ["zz-home"]\n    words: 1_000\n',
          'units[0].words must be a whole number of words',
        ),
        (
          '  - decks: ["zz-home"]\n    words: 4.5\n',
          'units[0].words must be a whole number of words',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 0 }\n'
              '$passages',
          'units[0].words must be a whole number of words, 1 or more',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    words: 6\n$passages',
          'units[0]: words is given both in planned and beside it',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health" }\n$passages',
          'units[0].planned: a planned theme unit gives its size in words',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n',
          'units[0]: a planned unit names its listening_passages and its '
              'reading_passages',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    listening_passages: []\n'
              '    reading_passages: [{ id: "y", text: { "en": "y" } }]\n',
          'units[0].listening_passages must be a non-empty list of passages, '
              'each { id, text }',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    listening_passages: ["Booking a doctor"]\n'
              '    reading_passages: [{ id: "y", text: { "en": "y" } }]\n',
          'units[0].listening_passages must be a non-empty list of passages',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    listening_passages: [{ id: "x", text: { "en": "x" } }]\n'
              '    reading_passages: [{ id: "x", text: { "en": "y" } }]\n',
          'units[0].reading_passages[0]: passage "x" is also earlier in this '
              'unit',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    listening_passages: [{ id: "x", text: "Booking" }]\n'
              '    reading_passages: [{ id: "y", text: { "en": "y" } }]\n',
          'units[0].listening_passages[0].text must be a mapping of a native '
              'language\'s code to the passage\'s description',
        ),
        (
          '  - planned: { id: "zz-health", theme: "health", words: 6 }\n'
              '    listening_passages: [{ id: "Doctor Call", text: { "en": "x" } }]\n'
              '    reading_passages: [{ id: "y", text: { "en": "y" } }]\n',
          'units[0].listening_passages[0]: id must match [a-z0-9-]+',
        ),
        (
          '  - planned: { id: "bn-en-health", theme: "health", words: 6 }\n'
              '$passages',
          'units[0].planned.id must be a core id of zz, zz- and a name, such '
              'as zz-health, got "bn-en-health"',
        ),
        (
          '  - planned: { id: "zz-x", theme: "x", grammar: "y", words: 6 }\n'
              '$passages',
          'units[0].planned names theme or grammar, not both',
        ),
        (
          '  - planned: { id: "zz-x", words: 6 }\n$passages',
          'units[0].planned needs a theme or a grammar topic',
        ),
        (
          '  - planned: { id: "zz-x", theme: "x", size: 6 }\n$passages',
          'units[0].planned: unknown field "size"',
        ),
        (
          '  - planned: "zz-x"\n$passages',
          'units[0].planned must be a mapping with id, and theme or grammar',
        ),
        (
          '  - decks: ["zz-home"]\n    grammar: ["Past"]\n',
          'units[0].grammar must be a grammar topic id or a list of them, '
              'such as ["past"], got "Past"',
        ),
        (
          '  - decks: ["zz-home"]\n    grammar: ["be", "be"]\n',
          'units[0].grammar: "be" is listed twice',
        ),
        (
          '  - decks: ["zz-home"]\n    milestone: "C1"\n',
          'units[0].milestone must be "A1", "A2" or "B1", got "C1"',
        ),
        (
          '  - decks: ["zz-home"]\n    milestone: "A1"\n'
              '  - decks: ["zz-food"]\n    milestone: "A1"\n',
          'units[1]: milestone "A1" is already on units[0]',
        ),
        (
          '  - decks: ["zz-home"]\n    milestone: "A2"\n'
              '  - decks: ["zz-food"]\n    milestone: "A1"\n',
          'units: the B1 plan needs the milestones A1, A2 and B1, each once '
              'and in that order; found A2, A1',
        ),
        (
          '  - decks: ["zz-home"]\n  - ["zz-home"]\n',
          'units[1]: "zz-home" is listed twice',
        ),
      ]) {
        expect(() => parseLanguagePath(pathOf(units)), fails(why), reason: why);
      }
    });

    test('regions are read, and a malformed one is refused', () {
      String withRegions(String regions) =>
          pathOf('  - ["zz-script"]\n')
              .replaceFirst('units:', '$regions\nunits:');
      final read = parseLanguagePath(
        withRegions(
          'regions:\n'
          '  - { id: "rarhi", name: { "en": "Rāṛhī (west-central)", '
          '"bn": "রাঢ়ী (rāṛhī)" } }',
        ),
      );
      expect(read.regions.single.id, 'rarhi');
      expect(read.regions.single.nameIn('bn'), 'রাঢ়ী (rāṛhī)');
      expect(read.regions.single.nameIn('hi'), 'Rāṛhī (west-central)');
      for (final (regions, why) in <(String, String)>[
        ('regions: []', 'regions must be a non-empty list of regions'),
        ('regions: ["telangana"]', 'regions[0] must be a mapping'),
        (
          'regions:\n  - { id: "telangana", name: { "en": "T" }, capital: "x" }',
          'regions[0]: unknown field "capital"',
        ),
        (
          'regions:\n  - { id: "Telangana", name: { "en": "T" } }',
          'regions[0].id must start with a letter',
        ),
        (
          'regions:\n  - { id: "no", name: { "en": "T" } }',
          'not be a YAML 1.1 boolean word, got "no"',
        ),
        (
          'regions:\n  - { id: "elsewhere", name: { "en": "T" } }',
          "elsewhere is the app's own answer",
        ),
        (
          'regions:\n  - { id: "a", name: { "en": "A" } }\n'
              '  - { id: "a", name: { "en": "B" } }',
          'regions[1].id: "a" is used twice',
        ),
        (
          'regions:\n  - { id: "a", name: "A" }',
          'regions[0].name must be a mapping of a language code',
        ),
        (
          'regions:\n  - { id: "a", name: { "bn": "এ (ē)" } }',
          'regions[0].name has no "en"',
        ),
        (
          'regions:\n  - { id: "a", name: { "English": "A" } }',
          'regions[0].name: "English" is not a language code',
        ),
      ]) {
        expect(
          () => parseLanguagePath(withRegions(regions)),
          fails(why),
          reason: why,
        );
      }
    });

    test('a path in the per-course form is refused', () {
      expect(
        () => parseLanguagePath(
          pathOf('  - ["zz-en-home"]\n')
              .replaceFirst('language: "zz"', 'language: "zz"\nnative: "en"'),
        ),
        fails('a path is one per language learnt'),
      );
    });
  });

  group('the catalog loads cores and layers (9.6)', () {
    test('Appendix A: merged decks, the core not shown, rules expanded', () {
      final catalog = DeckCatalog.parseAll(tree(appendix));
      expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
      expect(catalog.decks.map((e) => e.id).toSet(), {
        'zz-en-home',
        'zz-en-grammar-case-endings',
      });
      final home = catalog.byId('zz-en-home')!;
      expect(home.path, 'decks/zz/en/zz-en-home.yaml');
      expect(home.cards, hasLength(20));
      final rules = catalog.byId('zz-en-grammar-case-endings')!;
      expect(rules.cards, hasLength(8));
      expect(
        rules.cards[6].promptFor(DrillMode.grammar),
        'అమ్మ (amma): with mother',
      );
      expect(catalog.paths['zz/en']!.hasB1Plan, isTrue);
      expect(catalog.paths['zz/en']!.units.expand((u) => u), [
        'zz-en-home',
        'zz-en-grammar-case-endings',
      ]);
    });

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

    test('a layer whose core is missing, broken or not a core is broken', () {
      final files = tree(appendix);
      final missing = Map.of(files)..remove('decks/zz/zz-home.yaml');
      var catalog = DeckCatalog.parseAll(missing);
      expect(catalog.byId('zz-en-home'), isNull);
      expect(
        catalog.broken.single.error.message,
        "no core file zz-home.yaml in decks/zz; a layer's core is in the "
        'folder above it',
      );
      expect(catalog.broken.single.path, 'decks/zz/en/zz-en-home.yaml');

      final broken = Map.of(files)
        ..['decks/zz/zz-home.yaml'] = homeCore.replaceFirst(
          'license:',
          'name: "Home"\nlicense:',
        );
      catalog = DeckCatalog.parseAll(broken);
      expect(catalog.broken.map((b) => b.path).toSet(), {
        'decks/zz/zz-home.yaml',
        'decks/zz/en/zz-en-home.yaml',
      });
      expect(
        catalog.broken.map((b) => b.error.message),
        contains('its core, zz-home.yaml, could not be read'),
      );

      final notCore = Map.of(files)
        ..['decks/zz/zz-home.yaml'] = homeCore.replaceFirst(
          'part: "core"\n',
          '',
        );
      catalog = DeckCatalog.parseAll(notCore);
      expect(
        catalog.broken.map((b) => b.error.message),
        contains('zz-home.yaml is not a core: it has no part: "core"'),
      );
    });

    test('a layer that does not fit its core is broken, and the rest load', () {
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
    });
  });

  group('DrillMode.grammarUnderstood (4.7)', () {
    test('comes just before grammar, and is stored by its name', () {
      expect(
        DrillMode.values.indexOf(DrillMode.grammarUnderstood),
        DrillMode.values.indexOf(DrillMode.grammar) - 1,
      );
      expect(DrillMode.grammarUnderstood.name, 'grammarUnderstood');
      expect(DrillMode.grammar.name, 'grammar');
      expect(
        DrillMode.tryParse('grammarUnderstood'),
        DrillMode.grammarUnderstood,
      );
      expect(DrillMode.grammarUnderstood.isMachineGraded, isTrue);
    });

    test('shares the grammar tile, and implies nothing yet', () {
      expect(Skill.of(DrillMode.grammarUnderstood), Skill.grammar);
      expect(Skill.grammar.modes, contains(DrillMode.grammarUnderstood));
      expect(
        const SkillMap().impliedBy(DrillMode.grammarUnderstood, 'd'),
        isEmpty,
      );
      expect(const SkillMap().impliedBy(DrillMode.grammar, 'd'), isEmpty);
    });

    test('a rules option and cell are plain values', () {
      const option = RuleOption(form: 'అమ్మకి', prompt: 'to mother');
      expect(option.form, 'అమ్మకి');
      expect(const NoteWord(word: '-లో').shown, '-లో');
      expect(const RuleRow(word: 'zz-0042', forms: {'lo': 'x'}).idPart, '0042');
    });
  });
}
