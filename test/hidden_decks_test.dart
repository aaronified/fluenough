// Hidden decks (wiki/Plan-Deck-Kinds-And-Topics.md, D3, T13): a hidden deck
// never appears in the Decks tab's lists, the path, placement or the counts,
// and is in the catalog only as a deck a learner added. An added one is
// drilled (its due reviews join Today) and found by its id; a deck with a
// genre is not a path deck either. Backward compatible: decks with none of
// it are read as before.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/unlocks.dart';
import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/decks/levels.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_course.dart';

const String _hiddenId = 'zz-en-medicine-registro';

AppState _state(Map<String, String> files, {MemoryProgress? progress}) =>
    AppState(
      catalog: DeckCatalog(MemoryDeckSource(files)),
      progress: progress ?? MemoryProgress(),
      tts: const NullTtsEngine(),
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    );

void main() {
  group('the catalog', () {
    final catalog = DeckCatalog.parseAll(kindsCourse());

    test('keeps a hidden deck out of its decks, and has it as hidden', () {
      expect(ids(catalog.decks), isNot(contains(_hiddenId)));
      expect(ids(catalog.hidden), <String>[_hiddenId]);
      expect(catalog.broken, isEmpty);
    });

    test('keeps every other deck where it was', () {
      expect(
        ids(catalog.decks),
        containsAll(<String>[
          'zz-en-words',
          'zz-en-more',
          'zz-en-last',
          'zz-en-culture-a1',
          'zz-en-culture-b1',
          'zz-en-proverbs-a2',
          'yy-en-words',
        ]),
      );
    });

    test('finds a hidden deck by its id', () {
      expect(catalog.byId(_hiddenId)?.deck.hidden, isTrue);
      expect(catalog.byId(_hiddenId)?.deck.professional, 'medicine');
      expect(catalog.byId('zz-en-words')?.deck.hidden, isFalse);
      expect(catalog.byId('zz-en-nada'), isNull);
    });

    test('lists no language that has only hidden decks', () {
      final only = DeckCatalog.parseAll(<String, String>{
        for (final e in kindsCourse().entries)
          if (e.key.contains('medicine-registro')) e.key: e.value,
      });
      expect(only.languages, isEmpty);
      expect(only.decks, isEmpty);
      expect(only.hidden, hasLength(1));
    });

    test('has no hidden deck on the path', () {
      final path = catalog.paths['zz/en']!;
      expect(path.deckIds, <String>['zz-en-words', 'zz-en-more', 'zz-en-last']);
    });

    test('keeps a hidden deck when adult content is switched', () {
      expect(catalog.forAdult(adult: false).hidden, hasLength(1));
      expect(catalog.forAdult(adult: true), same(catalog));
    });

    test('has the same decks as before when none is hidden', () {
      final plain = DeckCatalog.parseAll(<String, String>{
        for (final e in kindsCourse().entries)
          if (!e.key.contains('medicine-registro')) e.key: e.value,
      });
      expect(plain.hidden, isEmpty);
      expect(plain.decks, hasLength(catalog.decks.length));
    });
  });

  group('the path', () {
    Map<String, String> withPath(List<String> units) => <String, String>{
      ...kindsCourse(),
      'decks/zz/zz-path.yaml': kindsPath('zz', units),
      ...kindsDeck('zz', 'extra', <KindsCard>[
        kindsCard('zz-0701', 'sol', 'sun'),
      ]),
    };

    test('is never given a hidden deck by its wildcard', () {
      final catalog = DeckCatalog.parseAll(
        withPath(<String>['[zz-words]', '["*"]']),
      );
      final placed = catalog.paths['zz/en']!.deckIds.toList();
      expect(placed, contains('zz-en-extra'));
      expect(placed, isNot(contains(_hiddenId)));
    });

    test('is not given a deck with a genre by its wildcard either', () {
      final catalog = DeckCatalog.parseAll(
        withPath(<String>['[zz-words]', '["*"]']),
      );
      final placed = catalog.paths['zz/en']!.deckIds.toList();
      for (final genre in <String>[
        'zz-en-culture-a1',
        'zz-en-culture-b1',
        'zz-en-proverbs-a2',
      ]) {
        expect(placed, isNot(contains(genre)));
      }
    });

    test('places a deck with a genre where it names it', () {
      final catalog = DeckCatalog.parseAll(
        withPath(<String>['[zz-words]', '[zz-culture-a1]']),
      );
      expect(catalog.paths['zz/en']!.deckIds, <String>[
        'zz-en-words',
        'zz-en-culture-a1',
      ]);
    });

    test('does not teach a hidden deck a path names', () {
      final catalog = DeckCatalog.parseAll(
        withPath(<String>['[zz-words]', '[zz-medicine-registro]']),
      );
      expect(catalog.paths['zz/en']!.deckIds, <String>['zz-en-words']);
    });
  });

  group('placement', () {
    final loaded = loadPlacementCourse(
      kindsCourse(),
      language: 'zz',
      native: 'en',
    );

    test('has the path decks and no hidden deck, nor one with a genre', () {
      expect(loaded.deckIds, <String>[
        'zz-en-words',
        'zz-en-more',
        'zz-en-last',
      ]);
      expect(loaded.broken, isEmpty);
    });

    test('has no hidden deck whatever the path says', () {
      final named = <String, String>{
        ...kindsCourse(),
        'decks/zz/zz-path.yaml': kindsPath('zz', <String>[
          '[zz-words]',
          '[zz-medicine-registro]',
        ]),
      };
      final deckIds = loadPlacementCourse(
        named,
        language: 'zz',
        native: 'en',
      ).deckIds;
      expect(deckIds.first, 'zz-en-words');
      expect(deckIds, isNot(contains(_hiddenId)));
      expect(deckIds, isNot(contains('zz-en-culture-a1')));
    });
  });

  group('the app', () {
    late AppState app;

    setUp(() async {
      app = _state(kindsCourse());
      await app.load();
    });

    test('keeps a hidden deck out of the Decks tab\'s decks and units', () {
      expect(ids(app.decks), isNot(contains(_hiddenId)));
      expect(<String>[
        for (final unit in app.courseUnits('zz')) ...ids(unit),
      ], isNot(contains(_hiddenId)));
      expect(
        ids(app.pendingUnits.expand((unit) => unit)),
        isNot(contains(_hiddenId)),
      );
    });

    test('has an added hidden deck, found by its id', () {
      expect(ids(app.addedHiddenDecks), <String>[_hiddenId]);
      expect(app.deckById(_hiddenId)?.id, _hiddenId);
      expect(ids(app.drillDecks), contains(_hiddenId));
      expect(app.cardById('zz-0501')?.target, 'el resumen');
    });

    test('has no hidden deck in placement', () {
      final plan = app.placementRunPlan('zz');
      expect(plan, isNotNull);
      expect(ids(plan!.decks), isNot(contains(_hiddenId)));
      expect(ids(app.walkDecks('zz')), isNot(contains(_hiddenId)));
    });

    test('has no hidden deck in the counts of cards', () {
      final cards = <String>[
        for (final entry in app.decks)
          for (final card in entry.cards) card.id,
      ];
      expect(cards, isNot(contains('zz-0501')));
      expect(cards, contains('zz-0001'));
    });

    test('has no genre deck among the words placement asks', () {
      expect(ids(app.walkDecks('zz')), isNot(contains('zz-en-culture-a1')));
    });
  });

  group('Today', () {
    test('has the due reviews of an added hidden deck, and none new', () async {
      final progress = MemoryProgress();
      final base = _state(kindsCourse());
      await base.load();
      progress.record(
        deckId: _hiddenId,
        cardId: 'zz-0501',
        mode: DrillMode.recognition,
        grade: 4,
        now: base.now().subtract(const Duration(days: 3)),
      );
      final app = _state(kindsCourse(), progress: progress);
      await app.load();
      // The language bar shows the first language (yy) by default, and
      // profileDecks follows it, so show zz as a learner of it would.
      app.showLanguage('zz');
      final due = app
          .buildSession(const DrillRequest.today(language: 'zz'))
          .due
          .map((item) => item.card.id)
          .toList();
      expect(due, contains('zz-0501'));
      expect(
        ids(app.profileDecks),
        contains(_hiddenId),
        reason: 'the learner added it, so its reviews join Today',
      );
    });

    test('teaches new words from the path, not from a hidden deck', () async {
      final app = _state(kindsCourse());
      await app.load();
      final fresh = app
          .buildSession(const DrillRequest.today(language: 'zz'))
          .fresh
          .map((item) => item.card.id)
          .toSet();
      expect(fresh, isNot(contains('zz-0501')));
    });

    test('is unchanged for a course with no hidden deck', () async {
      final files = <String, String>{
        for (final e in kindsCourse().entries)
          if (e.key.contains('zz-words') ||
              e.key.contains('zz-en-words') ||
              e.key.contains('zz-path'))
            e.key: e.value,
      };
      final app = _state(files);
      await app.load();
      expect(app.addedHiddenDecks, isEmpty);
      expect(ids(app.decks), <String>['zz-en-words']);
    });
  });

  group('a deck with a bad kind field', () {
    test('still loads, and the problem is in the catalog\'s list', () {
      final files = <String, String>{
        ...kindsDeck('zz', 'odd', <KindsCard>[
          kindsCard('zz-0801', 'a', 'a'),
        ], header: 'level: "Q"'),
      };
      final catalog = DeckCatalog.parseAll(files);
      expect(catalog.decks.single.id, 'zz-en-odd');
      // A present but unreadable level fails closed: it counts as the highest level.
      expect(catalog.decks.single.deck.level, Level.c2);
      expect(catalog.kindProblems.single, contains('zz-en-odd'));
      expect(catalog.kindProblems.single, contains('level'));
    });
  });
}

List<String> ids(Iterable<DeckEntry> entries) => <String>[
  for (final e in entries) e.id,
];
