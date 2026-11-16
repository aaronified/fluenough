// Culture woven through the course and the recommendations list (wiki
// Plan-Deck-Kinds-And-Topics.md, D11, D13, T20, T26): which culture item goes
// into which unit at the learner's level, how many, what is never woven, the
// timeline's events from the works at the level to today, and what the
// recommendations list offers, counts as hidden or leaves out for a learner.

import 'package:fluenough/app/culture.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/decks/culture_options.dart';
import 'package:fluenough/core/decks/recommendation_list.dart';
import 'package:fluenough/core/decks/timeline.dart';
import 'package:fluenough/core/decks/timeline_entries.dart';
import 'package:fluenough/core/decks/weave.dart';
import 'package:fluenough/core/data/creators.dart';
import 'package:fluenough/core/data/recommendations.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';

CultureItem _item(String id, Level level, {List<String> creators = const []}) =>
    CultureItem(
      id: id,
      deckId: 'zz-en-x',
      deckName: 'X',
      kind: CultureKind.line,
      level: level,
      target: id,
      cardIds: <String>[id],
      creators: creators,
    );

List<PlanUnit> _plan() => const <PlanUnit>[
  PlanUnit(decks: <String>['a'], milestone: Milestone.a1),
  PlanUnit(decks: <String>['b'], milestone: Milestone.a2),
  PlanUnit(decks: <String>['c']),
  PlanUnit(decks: <String>['d'], milestone: Milestone.b1),
];

List<String> _ids(Iterable<CultureItem> items) => <String>[
  for (final i in items) i.id,
];

void main() {
  group('weaving culture into the path', () {
    final items = <CultureItem>[
      _item('proverb-a1', Level.a1),
      _item('stanza-a2', Level.a2),
      _item('passage-b1', Level.b1),
      _item('proverb-a1-too', Level.a1),
    ];

    test('puts an item at its unit\'s own level, one to a unit', () {
      final woven = weaveCulture(_plan(), items);
      expect(_ids(woven.of(0)), <String>['proverb-a1']);
      expect(_ids(woven.of(1)), <String>['stanza-a2']);
      // The unit between the A2 mark and the B1 mark is a B1 unit.
      expect(_ids(woven.of(2)), <String>['passage-b1']);
      // A lower item left over fills a later unit; an item is woven once.
      expect(_ids(woven.of(3)), <String>['proverb-a1-too']);
      expect(woven.all, hasLength(4));
    });

    test('gives a unit as many as it is told to', () {
      final woven = weaveCulture(_plan(), items, perUnit: 2);
      expect(_ids(woven.of(0)), <String>['proverb-a1', 'proverb-a1-too']);
      expect(woven.all, hasLength(4));
      // Never fewer than one.
      expect(weaveCulture(_plan(), items, perUnit: 0).of(0), hasLength(1));
    });

    group('with the number a level needs', () {
      final many = <CultureItem>[
        for (var i = 1; i <= 3; i++) _item('a1-$i', Level.a1),
        _item('a2-1', Level.a2),
        for (var i = 1; i <= 3; i++) _item('b1-$i', Level.b1),
      ];

      test('is the items of a level over its units, rounded up', () {
        final per = culturePerUnitByLevel(_plan(), many);
        // Three A1 items in one unit, one A2 in one, three B1 in two.
        expect(per, <Level, int>{Level.a1: 3, Level.a2: 1, Level.b1: 2});
      });

      test('is at least one, also for a level with no item', () {
        final per = culturePerUnitByLevel(_plan(), <CultureItem>[
          _item('a1-1', Level.a1),
        ]);
        expect(per, <Level, int>{Level.a1: 1, Level.a2: 1, Level.b1: 1});
      });

      test('counts an item of a level with no unit for the next level up', () {
        const plan = <PlanUnit>[
          PlanUnit(decks: <String>['a'], milestone: Milestone.a1),
          PlanUnit(decks: <String>['b']),
          PlanUnit(decks: <String>['c'], milestone: Milestone.b1),
        ];
        final per = culturePerUnitByLevel(plan, <CultureItem>[
          _item('a1-1', Level.a1),
          _item('a2-1', Level.a2),
          _item('a2-2', Level.a2),
          _item('b1-1', Level.b1),
        ]);
        // The A2 items go with the B1 ones: three items in two units.
        expect(per, <Level, int>{Level.a1: 1, Level.b1: 2});
      });

      test('weaves every item at or below the level, none piled up', () {
        final woven = weaveCulture(
          _plan(),
          many,
          perByLevel: culturePerUnitByLevel(_plan(), many),
        );
        expect(_ids(woven.of(0)), <String>['a1-1', 'a1-2', 'a1-3']);
        expect(_ids(woven.of(1)), <String>['a2-1']);
        expect(_ids(woven.of(2)), <String>['b1-1', 'b1-2']);
        expect(_ids(woven.of(3)), <String>['b1-3']);
        expect(woven.all, hasLength(many.length));
      });
    });

    test('weaves nothing from no items', () {
      expect(weaveCulture(_plan(), const <CultureItem>[]).all, isEmpty);
    });

    test('offers the next item not met yet, in path order', () {
      final woven = weaveCulture(_plan(), items);
      expect(woven.next((_) => false)!.id, 'proverb-a1');
      expect(woven.next((item) => item.id == 'proverb-a1')!.id, 'stanza-a2');
      expect(woven.next((_) => true), isNull);
    });
  });

  group('the culture items of a course, from the decks', () {
    test(
      'are the proverbs, verse and passages that weave, with their sources',
      () async {
        final state = await cultureApp();
        final items = state.cultureItemsIn('zz');
        // Deck order is the catalog's path order: culture-verso, then
        // proverbs-lugar, then the passage deck.
        expect(_ids(items), <String>['zz-7201', 'zz-7101', 'zz-pasaje-1']);
        final proverb = items[1];
        expect(proverb.kind, CultureKind.proverb);
        expect(proverb.level, Level.a1);
        expect(proverb.meaning, 'Better late than never.');
        expect(proverb.creators, isEmpty);
        final stanza = items[0];
        expect(stanza.level, Level.a2);
        expect(stanza.creators, <String>['zz-machado']);
        expect(stanza.source!.work, 'Proverbios y cantares');
        final passage = items[2];
        expect(passage.kind, CultureKind.passage);
        expect(passage.glossary.single.word, 'lugar');
        expect(passage.cardIds, <String>['zz-7301', 'zz-7302']);
      },
    );

    test('are all woven, whatever the learner has reached', () async {
      final state = await cultureApp();
      expect(_ids(state.wovenCultureOf('zz').all), <String>[
        'zz-7101',
        'zz-7201',
        'zz-pasaje-1',
      ]);
    });

    test('give a unit as many as the course needs, with no setting', () async {
      final state = await cultureApp(
        files: <String, String>{...cultureWorld(), ...cultureMoreProverbs()},
      );
      final woven = state.wovenCultureOf('zz');
      // Three A1 items and one A1 unit: all three are in it.
      expect(
        _ids(woven.of(0)),
        unorderedEquals(<String>['zz-7101', 'zz-7102', 'zz-7103']),
      );
      // The A2 stanza and the B1 passage are woven too, in their own units.
      expect(woven.all, hasLength(5));
    });

    test('are offered on Today only while culture is on and not met', () async {
      final state = await cultureApp();
      expect(state.nextCultureItem('zz')!.id, 'zz-7101');
      state.settings.setCultureFor('hi', const CultureOptions(items: false));
      expect(state.nextCultureItem('zz')!.id, 'zz-7101');
      state.settings.setCultureFor('zz', const CultureOptions(items: false));
      expect(state.nextCultureItem('zz'), isNull);
    });
  });

  group('the timeline of the culture, to today', () {
    test('has the works, the legacy marks and today', () async {
      final state = await cultureApp(reach: 'b1');
      final entries = state.cultureTimelineEntriesOf('zz');
      expect(
        entries.map((e) => (e.kind, e.year)).toList(),
        <(TimelineEntryKind, int)>[
          (TimelineEntryKind.work, 1605),
          (TimelineEntryKind.work, 1912),
          (TimelineEntryKind.legacy, 1969),
          (TimelineEntryKind.today, state.now().year),
        ],
      );
      expect(entries[1].creator!.id, 'zz-machado');
      expect(entries[1].era!.id, 'plata');
    });

    test('runs from the works to the present year', () {
      final file = parseCreators(cultureCreators, source: 'zz.yaml');
      final built = buildTimeline(file, const <TimelineWork>[
        TimelineWork(
          cardId: 'w',
          creatorIds: <String>['zz-machado'],
          year: 1912,
          level: Level.a1,
        ),
      ], today: 2026);
      expect(built.end, 2026);
      expect(built.works.single.year, 1912);
    });
  });

  group('the recommended works', () {
    final file = parseRecommendations(
      cultureRecommendations,
      source: 'zz.yaml',
    );
    test('gives the public-domain badge to a work a deck quotes', () {
      expect(isPublicDomainWork(file.byId('zz-rec-camino')!), isTrue);
      expect(isPublicDomainWork(file.byId('zz-rec-pelicula')!), isFalse);
    });
  });
}
