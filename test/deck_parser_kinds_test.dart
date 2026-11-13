// The deck kinds' fields (wiki/Plan-Deck-Kinds-And-Topics.md, T10): `genre`,
// `level`, `hidden`, `professional`, `section`, `weave` and `pattern_family`
// on a deck, and a card's or a passage's `level`, `creator`, `source` block and
// `legacy`. Read from test/fixtures/deck-kinds, tolerantly: a bad value is left
// out and reported, never refused, and a deck with none of them is unchanged.

import 'dart:io';

import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/decks/levels.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/card_source.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:flutter_test/flutter_test.dart';

const String _folder = 'test/fixtures/deck-kinds/decks/zz';

String _read(String name) => File('$_folder/$name').readAsStringSync();

/// The merged deck of the core [core] and its English layer.
Deck _merged(String core) {
  final c = DeckParser.parseCore(_read('zz-$core.yaml'), source: 'zz-$core');
  final l = DeckParser.parseLayer(
    _read('en/zz-en-$core.yaml'),
    source: 'zz-en-$core',
  );
  return mergeLayer(c, l, source: 'zz-en-$core');
}

Card _card(Deck deck, String id) => deck.cards.firstWhere((c) => c.id == id);

const String _header = '''
schema: 1
id: "zz-x"
name: "X"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
''';

void main() {
  group('a culture deck', () {
    final deck = _merged('culture-ejemplo');

    test('has its genre, level and tags', () {
      expect(deck.genre, 'culture');
      expect(deck.level, Level.a2);
      expect(deck.hidden, isFalse);
      expect(deck.professional, isNull);
      expect(deck.section, isNull);
      expect(deck.weave, isNull);
      expect(deck.tags, contains('unreviewed'));
      expect(deck.kindProblems, isEmpty);
    });

    test('has a level on a card that gives one, and none on the rest', () {
      expect(_card(deck, 'zz-9201').level, Level.a2);
      expect(_card(deck, 'zz-9202').level, isNull);
    });

    test('names the creator of each card', () {
      expect(_card(deck, 'zz-9201').creators, <String>['zz-ejemplo-autora']);
      expect(_card(deck, 'zz-9202').creators, <String>['zz-ejemplo-poeta']);
    });

    test('reads a public-domain source block', () {
      final source = _card(deck, 'zz-9201').sourceBlock!;
      expect(source.author, 'Ana Ejemplo');
      expect(source.work, 'Obra de prueba');
      expect(source.date, '1890');
      expect(source.year, 1890);
      expect(source.edition, 'Edición de prueba, 1901');
      expect(source.basisKind, SourceBasis.publicDomain);
      expect(source.authorDied, 1910);
      expect(source.jurisdiction, 'ES');
      expect(source.rightsChecked, '2026-11-12');
    });

    test('reads a licensed one and a quotation', () {
      final licensed = _card(deck, 'zz-9202').sourceBlock!;
      expect(licensed.basisKind, SourceBasis.licensed);
      expect(licensed.licence, 'CC-BY-4.0');
      expect(
        licensed.licenceUrl,
        'https://creativecommons.org/licenses/by/4.0/',
      );
      expect(licensed.url, 'https://example.org/poema-de-prueba');
      final quoted = _card(deck, 'zz-9203').sourceBlock!;
      expect(quoted.basisKind, SourceBasis.quotation);
      expect(quoted.licence, contains('Berne'));
    });

    test('is read the same from the core alone', () {
      final core = DeckParser.parseCore(
        _read('zz-culture-ejemplo.yaml'),
        source: 'core',
      );
      expect(core.genre, 'culture');
      expect(core.level, Level.a2);
      final first = core.cards.first as CoreWritten;
      expect(first.level, Level.a2);
      expect(first.creators, <String>['zz-ejemplo-autora']);
      expect(first.sourceBlock?.author, 'Ana Ejemplo');
    });
  });

  group('a culture reading deck', () {
    final deck = DeckParser.parse(
      _read('zz-en-culture-lectura.yaml'),
      source: 'lectura',
    );
    final passage = deck.passages.single;

    test('has its genre and level', () {
      expect(deck.kind, DeckKind.reading);
      expect(deck.genre, 'culture');
      expect(deck.level, Level.a2);
    });

    test('has a passage with a level, a creator and a source block', () {
      expect(passage.level, Level.a2);
      expect(passage.creators, <String>['zz-ejemplo-autora']);
      expect(passage.source, isNull);
      expect(passage.sourceBlock?.work, 'Cartas de prueba');
      expect(passage.sourceBlock?.basisKind, SourceBasis.publicDomain);
    });

    test(
      'gives each question the level, creators and source of its passage',
      () {
        expect(deck.cards, hasLength(2));
        for (final card in deck.cards) {
          expect(card, isA<QuestionCard>());
          expect(card.level, Level.a2);
          expect(card.creators, <String>['zz-ejemplo-autora']);
          expect(card.sourceBlock?.author, 'Ana Ejemplo');
        }
      },
    );

    test('still takes a passage source that is plain text', () {
      final plain = DeckParser.parse('''
$_header
kind: reading
passages:
  - id: "zz-p1"
    title: "T"
    source: "A textbook"
    sentences:
      - { text: "Hola." }
    questions:
      - id: "zz-9990"
        prompt: { en: "Q?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: 1
''', source: 'plain');
      expect(plain.passages.single.source, 'A textbook');
      expect(plain.passages.single.sourceBlock, isNull);
      expect(plain.kindProblems, isEmpty);
    });
  });

  group('a proverbs deck', () {
    final deck = _merged('proverbs-ejemplo');

    test('has an oral-tradition source dated as an estimate', () {
      expect(deck.genre, 'proverbs');
      final source = _card(deck, 'zz-9401').sourceBlock!;
      expect(source.basisKind, SourceBasis.oralTradition);
      expect(source.author, 'anonymous');
      expect(source.collection, 'Refranes de prueba');
      expect(source.date, 'c. 1600');
      expect(source.year, 1600);
    });

    test('has the register of each card', () {
      expect(_card(deck, 'zz-9401').register, 'neutral');
      expect(_card(deck, 'zz-9402').register, 'informal');
    });
  });

  group('a multi-word deck', () {
    test('has its pattern family and a usage note', () {
      final deck = _merged('multiword-ejemplo');
      expect(deck.genre, 'multiword');
      expect(deck.patternFamily, 'pronominal');
      expect(
        _card(deck, 'zz-9501').notes.map((n) => n.kind),
        contains(NoteKind.usage),
      );
    });
  });

  group('a hidden professional deck', () {
    test('has its profession and is hidden', () {
      final deck = _merged('medicine-registro');
      expect(deck.genre, 'professional');
      expect(deck.professional, 'medicine');
      expect(deck.hidden, isTrue);
      expect(deck.level, Level.b1);
      expect(deck.cardCount, 2);
    });
  });

  group('a deck with no kind fields', () {
    test('is unchanged', () {
      final deck = _merged('words');
      expect(deck.genre, isNull);
      expect(deck.level, isNull);
      expect(deck.hidden, isFalse);
      expect(deck.professional, isNull);
      expect(deck.section, isNull);
      expect(deck.weave, isNull);
      expect(deck.patternFamily, isNull);
      expect(deck.kindProblems, isEmpty);
      for (final card in deck.cards) {
        expect(card.level, isNull);
        expect(card.creators, isEmpty);
        expect(card.sourceBlock, isNull);
        expect(card.legacy, isNull);
      }
    });

    test('keeps its kind fields through withCards', () {
      final deck = _merged('culture-ejemplo').withCards(const <Card>[]);
      expect(deck.genre, 'culture');
      expect(deck.level, Level.a2);
    });
  });

  group('a layer', () {
    test('ignores kind fields of its own, taking its core\'s', () {
      final layer = DeckParser.parseLayer(
        _read('en/zz-en-words.yaml').replaceFirst(
          'license:',
          'genre: "culture"\nlevel: "B1"\nhidden: true\nlicense:',
        ),
        source: 'layer',
      );
      final core = DeckParser.parseCore(_read('zz-words.yaml'), source: 'core');
      final deck = mergeLayer(core, layer, source: 'layer');
      expect(deck.genre, isNull);
      expect(deck.level, isNull);
      expect(deck.hidden, isFalse);
    });
  });

  group('tolerance', () {
    test('reads a level that is not one as C2 and says so', () {
      final deck = DeckParser.parse('''
$_header
level: "D9"
cards:
  - { id: "zz-9901", target: "a", native: "a", level: "Z" }
''', source: 'bad');
      expect(deck.level, Level.c2);
      expect(deck.cards.single.level, Level.c2);
      expect(deck.kindProblems, hasLength(2));
      expect(deck.kindProblems.first, contains('level'));
    });

    test('reads a lower-case level as C2, never as open to all', () {
      final deck = DeckParser.parse('''
$_header
level: "b1"
cards:
  - { id: "zz-9901", target: "a", native: "a" }
''', source: 'bad');
      expect(deck.level, Level.c2);
      expect(deck.kindProblems, hasLength(1));
    });

    test('leaves out fields of the wrong type and still loads', () {
      final deck = DeckParser.parse('''
$_header
genre: 5
hidden: "yes"
weave: 3
section: [a]
professional: ""
pattern_family: 7
cards:
  - id: "zz-9901"
    target: "a"
    native: "a"
    creator: 5
    source: "just text"
    legacy: [1, 2]
''', source: 'bad');
      expect(deck.genre, isNull);
      expect(deck.hidden, isTrue);
      expect(deck.weave, isNull);
      expect(deck.section, isNull);
      expect(deck.professional, isNull);
      expect(deck.patternFamily, isNull);
      final card = deck.cards.single;
      expect(card.creators, isEmpty);
      expect(card.sourceBlock, isNull);
      expect(card.legacy, isNull);
      expect(deck.kindProblems, isNotEmpty);
    });

    test('takes a list of creators and drops an item that is not an id', () {
      final deck = DeckParser.parse('''
$_header
cards:
  - id: "zz-9901"
    target: "a"
    native: "a"
    creator: ["zz-one", "zz-two", 3]
''', source: 'many');
      expect(deck.cards.single.creators, <String>['zz-one', 'zz-two']);
      expect(deck.kindProblems, hasLength(1));
    });

    test(
      'never refuses over rights: a source with nothing right still loads',
      () {
        final deck = DeckParser.parse('''
$_header
genre: "culture"
cards:
  - id: "zz-9901"
    target: "a"
    native: "a"
    source:
      basis: "stolen"
      author_died: "long ago"
      date: [1, 2]
      unknown_key: true
''', source: 'rights');
        final source = deck.cards.single.sourceBlock!;
        expect(source.basis, 'stolen');
        expect(source.basisKind, isNull);
        expect(source.authorDied, isNull);
        expect(source.date, isNull);
        expect(deck.kindProblems, hasLength(2));
      },
    );

    test('keeps a card legacy as the mapping it is', () {
      final deck = DeckParser.parse('''
$_header
cards:
  - id: "zz-9901"
    target: "a"
    native: "a"
    legacy:
      text: { en: "Still taught." }
      items:
        - { kind: "curriculum", year: 1990 }
''', source: 'legacy');
      final legacy = deck.cards.single.legacy!;
      expect((legacy['text'] as Map)['en'], 'Still taught.');
      expect(legacy['items'], isA<List<Object?>>());
      expect(deck.kindProblems, isEmpty);
    });

    test('takes level, hidden and weave as written', () {
      final deck = DeckParser.parse('''
$_header
genre: "later-genre"
level: "C2"
hidden: true
weave: false
section: "beyond-basics"
cards:
  - { id: "zz-9901", target: "a", native: "a" }
''', source: 'ok');
      expect(deck.genre, 'later-genre');
      expect(deck.level, Level.c2);
      expect(deck.hidden, isTrue);
      expect(deck.weave, isFalse);
      expect(deck.section, 'beyond-basics');
      expect(deck.kindProblems, isEmpty);
    });
  });
}
