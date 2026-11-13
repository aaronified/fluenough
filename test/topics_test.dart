// Topics (wiki/Plan-Deck-Kinds-And-Topics.md, D6, T14): a language's topics
// file is read tolerantly, a script topic keeps its script units and character
// list, every reference is resolved against the language's decks, path, cards,
// situation sheets and script guides, and a drill on a topic uses only cards at
// or below the learner's level, a hidden deck's only once it is added.

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/topics.dart';
import 'package:fluenough/core/data/deck_parser.dart' show DeckParseException;
import 'package:fluenough/core/data/topics.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:fluenough/core/models/topic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/kinds_fixture.dart';

String _fixtureTopics() =>
    kindsFixtureFiles(language: 'zz')['decks/zz/zz-topics.yaml']!;

void main() {
  group('the topics file', () {
    final file = parseTopics(_fixtureTopics(), source: 'zz-topics.yaml');

    test('keeps a script topic with its script units and characters', () {
      final script = file.byId('zz-juktakkhor')!;
      expect(script.kind, TopicKind.script);
      expect(script.level, Level.a1);
      expect(script.scriptUnits, <String>['conjuncts', 'r-forms']);
      expect(script.chars.map((c) => c.text), <String>[
        'ক্ষ',
        'জ্ঞ',
        'ক্ত',
        'ন্দ',
        'স্ত',
      ]);
      expect(script.term?.reading, 'juktakkhor');
      expect(script.nameFor(<String>['bn', 'en']), 'Conjunct letters');
      expect(file.problems, isEmpty);
    });

    test('keeps the order and what a topic names', () {
      expect(file.topics.map((t) => t.id), <String>[
        'zz-juktakkhor',
        'zz-reflexive-verbs',
        'zz-conference',
      ]);
      final verbs = file.byId('zz-reflexive-verbs')!;
      expect(verbs.decks, <String>['zz-multiword-ejemplo']);
      expect(verbs.cards, <String>['zz-9501']);
      expect(verbs.units, <String>['zz-words']);
      expect(verbs.topics, <String>['zz-juktakkhor']);
    });

    test('costs only the topic that cannot be read, and says why', () {
      final read = parseTopics('''
schema: 1
kind: "topics"
language: "zz"
topics:
  - id: "zz-good"
    name: { en: "Good" }
    decks: ["zz-words"]
  - id: "zz-no-english"
    name: { bn: "x" }
    decks: ["zz-words"]
  - id: "zz-names-nothing"
    name: { en: "Nothing" }
  - id: "zz-good"
    name: { en: "Again" }
    decks: ["zz-words"]
  - id: "zz-glyphs"
    name: { en: "Glyphs" }
    kind: "something-new"
    level: "Z9"
    chars: ["ক্ষ", "a b", "abcdefghijklmnop", { text: "জ্ঞ", reading: "gya" }]
  - "not a mapping"
''', source: 'zz-topics.yaml');
      expect(read.topics.map((t) => t.id), <String>['zz-good', 'zz-glyphs']);
      final glyphs = read.byId('zz-glyphs')!;
      expect(glyphs.kind, TopicKind.other);
      expect(glyphs.level, isNull);
      expect(glyphs.chars.map((c) => c.text), <String>['ক্ষ', 'জ্ঞ']);
      expect(glyphs.chars.last.reading, 'gya');
      expect(read.byId('zz-good')!.names['en'], 'Good');
      expect(read.problems.length, greaterThanOrEqualTo(5));
    });

    test('refuses only a file that is not a topics file, or is newer', () {
      expect(
        () => parseTopics('kind: "themes"\n', source: 'x.yaml'),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => parseTopics(
          'schema: 9\nkind: "topics"\nlanguage: "zz"\ntopics: []\n',
          source: 'x.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('resolving against the language', () {
    final files = kindsFixtureFiles();
    final catalog = DeckCatalog.parseAll(files);
    final topics = Topics.of(catalog, 'zz');

    test('is read by the catalog, one file per language', () {
      expect(catalog.topics.keys, <String>['zz']);
      expect(catalog.dataProblems, isEmpty);
    });

    test(
      'finds the script units, the deck, the card, the unit and the topic',
      () {
        final script = topics.byId('zz-juktakkhor')!;
        expect(script.scriptUnits, <String>['conjuncts', 'r-forms']);
        final verbs = topics.byId('zz-reflexive-verbs')!;
        expect(verbs.decks, <String>['zz-multiword-ejemplo']);
        expect(verbs.cards, <String>['zz-9501']);
        expect(verbs.units, <int>[0]);
        expect(verbs.related, <String>['zz-juktakkhor']);
        expect(verbs.unresolved, isEmpty);
      },
    );

    test(
      'reports a reference that names nothing, and still resolves the rest',
      () {
        final broken = DeckCatalog.parseAll(<String, String>{
          ...files,
          'decks/zz/zz-topics.yaml': '''
schema: 1
kind: "topics"
language: "zz"
topics:
  - id: "zz-lost"
    name: { en: "Lost" }
    decks: ["zz-words", "zz-nowhere"]
    grammar: ["lo"]
    situations: ["taxi"]
''',
        });
        final lost = Topics.of(broken, 'zz').byId('zz-lost')!;
        expect(lost.decks, <String>['zz-words']);
        expect(
          lost.unresolved,
          containsAll(<String>[
            'decks:zz-nowhere',
            'grammar:lo',
            'situations:taxi',
          ]),
        );
      },
    );

    test('has none for a language with no topics file', () {
      expect(Topics.of(catalog, 'yy').resolved, isEmpty);
    });

    test('drills only cards at or below the learner\'s level', () {
      // A2: the verbs topic, its deck (level A2), its card and the unit's deck.
      expect(
        topics.drillCards('zz-reflexive-verbs', Level.a2),
        containsAll(<String>['zz-9501', 'zz-9001', 'zz-9002']),
      );
      // A1: the topic is A2, so nothing is given.
      expect(topics.drillCards('zz-reflexive-verbs', Level.a1), isEmpty);
      // A language with no levels is given no levelled topic at all.
      expect(topics.drillCards('zz-reflexive-verbs', null), isEmpty);
    });

    test('lists as startable only the topics at or below the level', () {
      expect(topics.startable(Level.a1).map((r) => r.topic.id), <String>[
        'zz-juktakkhor',
      ]);
      expect(topics.startable(Level.b1), hasLength(3));
    });

    test('uses a hidden deck\'s cards only once it is added', () {
      expect(
        topics.drillCards('zz-conference', Level.b1),
        containsAll(<String>['zz-9601', 'zz-9602']),
      );
      // The deck is only listed by the index, not on the phone: it exists for
      // a topic to name, and nothing is drilled.
      final notAdded = DeckCatalog.parseAll(<String, String>{
        for (final e in files.entries)
          if (!e.key.contains('medicine-registro')) e.key: e.value,
      });
      final shelves = DeckIndex.parse(
        indexFor(kindsFixtureFiles(language: 'zz')),
      ).language('zz')!.shelves;
      final listed = Topics.of(notAdded, 'zz', shelves: shelves);
      expect(listed.byId('zz-conference')!.decks, <String>[
        'zz-medicine-registro',
      ]);
      expect(listed.drillCards('zz-conference', Level.b1), isEmpty);
    });
  });
}
