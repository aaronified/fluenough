import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';

/// A deck of [cards] in Spanish, taught from [native].
String vocab(String id, String cards, {String native = 'en', String? theme}) {
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

String grammar(String id, {String native = 'en'}) {
  final name = native == 'en' ? 'eng, name: English' : 'ben, name: Bengali';
  return '''
schema: 1
id: $id
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: $native, iso639_3: $name }
license: CC0-1.0
pattern:
  name: Present
  slot_name: person
  slots: [yo, tú]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
    - lemma: hablar
      gloss: to speak
      forms: { yo: ["hablo", "hablo yo"], tú: hablas }
''';
}

void main() {
  group('refs (ADR-0018)', () {
    test('a ref is parsed apart from the cards, with its place', () {
      final deck = DeckParser.parse(
        vocab(
          'es-en-b',
          '  - id: es-0003\n    target: "pez"\n    native: "fish"\n'
              '  - ref: es-0001\n    native: "dog (the pet)"\n',
        ),
        source: 'es-en-b.yaml',
      );
      expect(deck.cards.map((c) => c.id), ['es-0003']);
      expect(deck.refs.single.id, 'es-0001');
      expect(deck.refs.single.position, 1);
      expect(deck.refs.single.native, 'dog (the pet)');
      expect(deck.refs.single.notes, isNull);
    });

    test('a ref cannot give the card itself, nor list it twice', () {
      expect(
        () => DeckParser.parse(
          vocab('es-en-b', '  - ref: es-0001\n    target: "x"\n'),
          source: 'es-en-b.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckParser.parse(
          vocab('es-en-b', '  - ref: es-0001\n  - ref: es-0001\n'),
          source: 'es-en-b.yaml',
        ),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('already in the deck'),
          ),
        ),
      );
    });

    test('the catalog lists the written card in the ref\'s place, with '
        'what the ref gives', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/es-en-a.yaml': vocab('es-en-a', written),
        'decks/es/es-en-b.yaml': vocab(
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

    test('a deck taught from another language takes only what the ref '
        'gives, and leaves out a ref with no native', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/es-en-a.yaml': vocab('es-en-a', written),
        'decks/es/es-bn-b.yaml': vocab(
          'es-bn-b',
          '  - ref: es-0001\n    native: "কুকুর"\n  - ref: es-0002\n',
          native: 'bn',
        ),
      });
      final cards = catalog.byId('es-bn-b')!.deck.cards;
      expect(cards.map((c) => c.id), ['es-0001']);
      expect(cards.single.native, 'কুকুর');
      expect(cards.single.target, 'perro');
      expect(cards.single.notes, isEmpty, reason: 'English notes stay behind');
      expect(cards.single.tags, isEmpty);
    });
  });

  group('grammar cells (ADR-0018, #144)', () {
    test('a cell lists its forms: the first shown, every one accepted', () {
      final deck = DeckParser.parse(
        grammar('es-en-grammar-probe'),
        source: 'es-en-grammar-probe.yaml',
      );
      final entry = deck.pattern!.entries.single;
      expect(entry.forms['yo'], 'hablo');
      expect(entry.alternatives, {
        'yo': ['hablo yo'],
      });
      final cards = expandPattern(deck);
      expect(cards.first.target, 'hablo');
      expect(cards.first.altTarget, ['hablo yo']);
      expect(cards.first.acceptedAnswers(DrillMode.grammar), [
        'hablo',
        'hablo yo',
      ]);
      expect(cards.last.altTarget, isEmpty);
      final cell = grammarCellOf(cards.first, deck)!;
      expect(cell.answer, 'hablo');
      expect(cell.alternatives, ['hablo yo']);
    });

    test('a cell is one card whichever language it is learned from', () {
      final fromEnglish = expandPattern(
        DeckParser.parse(grammar('es-en-grammar-probe'), source: 'a.yaml'),
      );
      final fromBengali = expandPattern(
        DeckParser.parse(
          grammar('es-bn-grammar-probe', native: 'bn'),
          source: 'b.yaml',
        ),
      );
      expect(fromEnglish.map((c) => c.id), [
        'es-grammar-probe-hablar-0',
        'es-grammar-probe-hablar-1',
      ]);
      expect(fromBengali.map((c) => c.id), fromEnglish.map((c) => c.id));
    });
  });

  test('the bundled decks share a repeated word\'s card', () {
    final files = <String, String>{
      for (final file in Directory('decks').listSync(recursive: true))
        if (file is File && file.path.endsWith('.yaml'))
          file.path: file.readAsStringSync(),
    };
    final catalog = DeckCatalog.parseAll(files);
    expect(catalog.broken, isEmpty);
    final water = <String, String>{
      for (final entry in catalog.decks)
        if (entry.language.code == 'bn')
          for (final card in entry.cards)
            if (card.target == 'জল') entry.id: card.id,
    };
    expect(water.keys, hasLength(greaterThanOrEqualTo(3)));
    expect(water.values.toSet(), hasLength(1), reason: '$water');
  });
}
