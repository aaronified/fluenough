// The level gate (wiki/Plan-Deck-Kinds-And-Topics.md, D2, T13): a learner is
// never given a deck, a card or a passage above their level in a language, the
// level being that of the furthest path unit they have studied or been placed
// past. A language whose path has no levels offers no levelled item at all, a
// B2 item is never shown to a learner whose path ends at B1, and an item with
// no level is open to everyone.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/learner_levels.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/levels.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_course.dart';

List<String> _ids(Iterable<DeckEntry> entries) => <String>[
  for (final e in entries) e.id,
];

List<String> _cards(Catalog catalog, String deck) => <String>[
  for (final card in catalog.byId(deck)!.cards) card.id,
];

/// A reading deck with a passage for A1 and one for B1.
Map<String, String> _reading() => <String, String>{
  'decks/zz/zz-en-lectura.yaml': '''
schema: 1
id: "zz-en-lectura"
name: "A reading"
kind: "reading"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
genre: "culture"
level: "A1"
passages:
  - id: "zz-p1"
    title: "One"
    level: "A1"
    sentences:
      - { text: "Hola." }
    questions:
      - id: "zz-0901"
        prompt: { en: "Q1?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: 1
  - id: "zz-p2"
    title: "Two"
    level: "B1"
    sentences:
      - { text: "Adios." }
    questions:
      - id: "zz-0902"
        prompt: { en: "Q2?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: 1
''',
};

AppState _state(MemoryProgress progress, {Set<String>? placed}) => AppState(
  catalog: DeckCatalog(MemoryDeckSource(kindsCourse())),
  progress: progress,
  tts: const NullTtsEngine(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    placedDecks: placed ?? const <String>{},
  ),
);

void _answer(
  MemoryProgress progress,
  AppState base,
  String deck,
  String card,
) => progress.record(
  deckId: deck,
  cardId: card,
  mode: DrillMode.recognition,
  grade: 4,
  now: base.now().subtract(const Duration(days: 3)),
);

void main() {
  final catalog = DeckCatalog.parseAll(kindsCourse());

  group('a catalog at a level', () {
    test('has no deck above the level, and no card above it in the rest', () {
      final at = catalog.forLevels((_) => Level.a1);
      expect(_ids(at.decks), contains('zz-en-culture-a1'));
      expect(_ids(at.decks), isNot(contains('zz-en-culture-b1')));
      expect(_ids(at.decks), isNot(contains('zz-en-proverbs-a2')));
      expect(_cards(at, 'zz-en-culture-a1'), <String>['zz-0301']);
    });

    test('has a deck once the learner is at its level, with its own cards', () {
      final at = catalog.forLevels((l) => l == 'zz' ? Level.a2 : Level.a1);
      expect(_ids(at.decks), contains('zz-en-proverbs-a2'));
      expect(_ids(at.decks), isNot(contains('zz-en-culture-b1')));
      expect(_cards(at, 'zz-en-culture-a1'), <String>['zz-0301']);
    });

    test(
      'has every item at B1, and is the very catalog when nothing is left out',
      () {
        final at = catalog.forLevels((_) => Level.b1);
        expect(at, same(catalog));
        expect(_cards(at, 'zz-en-culture-a1'), <String>['zz-0301', 'zz-0302']);
      },
    );

    test('offers no levelled item in a language with no levels', () {
      final at = catalog.forLevels((l) => l == 'zz' ? Level.b1 : null);
      expect(_ids(at.decks), isNot(contains('yy-en-culture')));
      expect(_ids(at.decks), contains('yy-en-words'));
      final none = catalog.forLevels((_) => null);
      expect(_ids(none.decks), isNot(contains('zz-en-culture-a1')));
      expect(_ids(none.hidden), isEmpty);
      expect(
        _ids(none.decks),
        containsAll(<String>['zz-en-words', 'zz-en-more', 'zz-en-last']),
      );
    });

    test('leaves out a hidden deck above the level too', () {
      final files = <String, String>{
        ...kindsCourse(),
        ...kindsDeck('zz', 'cardiology', <KindsCard>[
          kindsCard('zz-0551', 'el corazon', 'the heart'),
        ], header: 'genre: "professional"\nhidden: true\nlevel: "B1"'),
      };
      final both = DeckCatalog.parseAll(files);
      expect(_ids(both.hidden), hasLength(2));
      final a1 = both.forLevels((_) => Level.a1);
      expect(_ids(a1.hidden), <String>['zz-en-medicine-registro']);
    });

    test(
      'has the passages and questions of a reading deck up to the level',
      () {
        final reading = DeckCatalog.parseAll(<String, String>{
          ...kindsCourse(),
          ..._reading(),
        });
        final deck = reading.forLevels((_) => Level.a1).byId('zz-en-lectura')!;
        expect(deck.deck.passages.map((p) => p.id), <String>['zz-p1']);
        expect(deck.cards.map((c) => c.id), <String>['zz-0901']);
        final all = reading.forLevels((_) => Level.b1).byId('zz-en-lectura')!;
        expect(all.cards.map((c) => c.id), <String>['zz-0901', 'zz-0902']);
      },
    );

    test('leaves out a deck with nothing left for the learner', () {
      final files = <String, String>{
        ...kindsDeck('zz', 'later', <KindsCard>[
          kindsCard('zz-0951', 'a', 'a', extra: 'level: "B1"'),
        ]),
      };
      final later = DeckCatalog.parseAll(files);
      expect(_ids(later.decks), <String>['zz-en-later']);
      expect(_ids(later.forLevels((_) => Level.a1).decks), isEmpty);
    });

    test('never shows a B2 item to a learner whose path ends at B1', () {
      final files = <String, String>{
        ...kindsCourse(),
        ...kindsDeck('zz', 'advanced', <KindsCard>[
          kindsCard('zz-0961', 'a', 'a'),
        ], header: 'genre: "culture"\nlevel: "B2"'),
      };
      final both = DeckCatalog.parseAll(files);
      final reached = both.forLevels((_) => Level.b1);
      expect(_ids(reached.decks), isNot(contains('zz-en-advanced')));
    });
  });

  group('the learner\'s level', () {
    final levels = LearnerLevels(catalog);

    Map<String, Level?> at({
      List<String> studied = const <String>[],
      Set<String> placed = const <String>{},
    }) => levels.levels(studied: studied, placedDecks: placed);

    test('is A1 for a learner who has begun nothing', () {
      expect(at(), <String, Level?>{'zz': Level.a1});
    });

    test('is that of the furthest unit a studied card is in', () {
      expect(at(studied: <String>['zz-0001'])['zz'], Level.a1);
      expect(at(studied: <String>['zz-0101'])['zz'], Level.a2);
      expect(at(studied: <String>['zz-0001', 'zz-0201'])['zz'], Level.b1);
    });

    test('is moved by placement past a unit it placed whole', () {
      expect(at(placed: <String>{'zz-en-words'})['zz'], Level.a2);
      expect(at(placed: <String>{'zz-en-more'})['zz'], Level.b1);
      // The last unit placed: no further to go.
      expect(at(placed: <String>{'zz-en-last'})['zz'], Level.b1);
    });

    test('is not moved by a card of a culture deck, which is on no unit', () {
      expect(at(studied: <String>['zz-0301', 'zz-0401'])['zz'], Level.a1);
    });

    test('has no level for a language whose path has none', () {
      expect(at().containsKey('yy'), isFalse);
      expect(at(studied: <String>['yy-0001']).containsKey('yy'), isFalse);
    });

    test(
      'names the core of a deck, and no core for one that is not its own',
      () {
        expect(LearnerLevels.coreIdOf('zz-en-words', 'zz', 'en'), 'zz-words');
        expect(LearnerLevels.coreIdOf('zz-bn-words', 'zz', 'en'), isNull);
        expect(LearnerLevels.coreIdOf('zz-en-', 'zz', 'en'), isNull);
      },
    );

    test('compares two sets of levels', () {
      expect(
        sameLevels(
          <String, Level?>{'zz': Level.a1},
          <String, Level?>{'zz': Level.a1},
        ),
        isTrue,
      );
      expect(
        sameLevels(
          <String, Level?>{'zz': Level.a1},
          <String, Level?>{'zz': Level.a2},
        ),
        isFalse,
      );
      expect(
        sameLevels(<String, Level?>{'zz': null}, <String, Level?>{}),
        isFalse,
      );
    });
  });

  group('the app', () {
    test('gives a new learner what is at A1 and nothing above', () async {
      final app = _state(MemoryProgress());
      await app.load();
      expect(app.levelIn('zz'), Level.a1);
      expect(app.levelIn('yy'), isNull);
      expect(_ids(app.decks), contains('zz-en-culture-a1'));
      expect(_ids(app.decks), isNot(contains('zz-en-culture-b1')));
      expect(_ids(app.decks), isNot(contains('zz-en-proverbs-a2')));
      expect(_ids(app.decks), isNot(contains('yy-en-culture')));
      expect(app.deckById('zz-en-culture-a1')!.cards.map((c) => c.id), <String>[
        'zz-0301',
      ]);
      expect(app.deckById('zz-en-culture-b1'), isNull);
    });

    test(
      'is not given a deck of a language with no levels, whoever asks',
      () async {
        final app = _state(MemoryProgress());
        await app.load();
        expect(app.deckById('yy-en-culture'), isNull);
        expect(_ids(app.decks), contains('yy-en-words'));
      },
    );

    test(
      'moves up as the learner starts the next unit, with no reload',
      () async {
        final progress = MemoryProgress();
        final app = _state(progress);
        await app.load();
        expect(app.levelIn('zz'), Level.a1);
        expect(_ids(app.decks), isNot(contains('zz-en-proverbs-a2')));
        _answer(progress, app, 'zz-en-more', 'zz-0101');
        expect(app.levelIn('zz'), Level.a2);
        expect(_ids(app.decks), contains('zz-en-proverbs-a2'));
        expect(_ids(app.decks), isNot(contains('zz-en-culture-b1')));
        _answer(progress, app, 'zz-en-last', 'zz-0201');
        expect(app.levelIn('zz'), Level.b1);
        expect(_ids(app.decks), contains('zz-en-culture-b1'));
        expect(
          app.deckById('zz-en-culture-a1')!.cards.map((c) => c.id),
          <String>['zz-0301', 'zz-0302'],
        );
      },
    );

    test('moves up when placement passes a unit', () async {
      final app = _state(
        MemoryProgress(),
        placed: const <String>{'zz-en-words'},
      );
      await app.load();
      expect(app.levelIn('zz'), Level.a2);
      expect(_ids(app.decks), contains('zz-en-proverbs-a2'));
    });

    test('never puts a card above the level in Today', () async {
      final progress = MemoryProgress();
      final base = _state(MemoryProgress());
      await base.load();
      // The learner has reviews of an A1 card and of two cards above their level.
      _answer(progress, base, 'zz-en-culture-a1', 'zz-0301');
      _answer(progress, base, 'zz-en-culture-a1', 'zz-0302');
      _answer(progress, base, 'zz-en-culture-b1', 'zz-0401');
      final app = _state(progress);
      await app.load();
      final due = app
          .buildSession(const DrillRequest.today(language: 'zz'))
          .due
          .map((item) => item.card.id)
          .toSet();
      expect(due, contains('zz-0301'));
      expect(due, isNot(contains('zz-0302')));
      expect(due, isNot(contains('zz-0401')));
    });

    test('keeps a deck with no level for every learner', () async {
      final app = _state(MemoryProgress());
      await app.load();
      expect(
        _ids(app.decks),
        containsAll(<String>['zz-en-words', 'zz-en-more', 'zz-en-last']),
      );
    });
  });
}
