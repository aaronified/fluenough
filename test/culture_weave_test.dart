// Culture woven through the course and the recommendations list (wiki
// Plan-Deck-Kinds-And-Topics.md, D11, D13, T20, T26): which culture item goes
// into which unit at the learner's level, how many, what is never woven, the
// timeline's events from the works at the level to today, and what the
// recommendations list offers, counts as hidden or leaves out for a learner.

import 'package:fluenough/app/culture.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/decks/recommendation_list.dart';
import 'package:fluenough/core/decks/recommendations.dart';
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
      final woven = weaveCulture(_plan(), items, Level.b1);
      expect(_ids(woven.of(0)), <String>['proverb-a1']);
      expect(_ids(woven.of(1)), <String>['stanza-a2']);
      // The unit between the A2 mark and the B1 mark is a B1 unit.
      expect(_ids(woven.of(2)), <String>['passage-b1']);
      // A lower item left over fills a later unit; an item is woven once.
      expect(_ids(woven.of(3)), <String>['proverb-a1-too']);
      expect(woven.all, hasLength(4));
      expect(woven.above, isEmpty);
    });

    test('never weaves an item above the learner, and counts it', () {
      final woven = weaveCulture(_plan(), items, Level.a1);
      expect(_ids(woven.all), <String>['proverb-a1', 'proverb-a1-too']);
      expect(_ids(woven.above), <String>['stanza-a2', 'passage-b1']);
      expect(woven.nextUnlock, Level.a2);
    });

    test('gives a unit as many as the learner asked for, up to three', () {
      final woven = weaveCulture(_plan(), items, Level.b1, perUnit: 2);
      expect(_ids(woven.of(0)), <String>['proverb-a1', 'proverb-a1-too']);
      expect(woven.all, hasLength(4));
      expect(
        weaveCulture(_plan(), items, Level.b1, perUnit: 9).all,
        hasLength(4),
      );
    });

    test('weaves nothing for a language with no levels', () {
      final woven = weaveCulture(_plan(), items, null);
      expect(woven.all, isEmpty);
      expect(woven.above, hasLength(4));
      expect(
        weaveCulture(_plan(), const <CultureItem>[], Level.b1).all,
        isEmpty,
      );
    });

    test('offers the next item not met yet, in path order', () {
      final woven = weaveCulture(_plan(), items, Level.b1);
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
        expect(_ids(items), <String>['zz-7101', 'zz-7201', 'zz-pasaje-1']);
        final proverb = items[0];
        expect(proverb.kind, CultureKind.proverb);
        expect(proverb.level, Level.a1);
        expect(proverb.meaning, 'Better late than never.');
        expect(proverb.creators, isEmpty);
        final stanza = items[1];
        expect(stanza.level, Level.a2);
        expect(stanza.creators, <String>['zz-machado']);
        expect(stanza.source!.work, 'Proverbios y cantares');
        final passage = items[2];
        expect(passage.kind, CultureKind.passage);
        expect(passage.glossary.single.word, 'lugar');
        expect(passage.cardIds, <String>['zz-7301', 'zz-7302']);
      },
    );

    test('are woven at the learner\'s level, and move up with them', () async {
      final a1 = await cultureApp();
      expect(_ids(a1.wovenCultureOf('zz').all), <String>['zz-7101']);
      expect(_ids(a1.wovenCultureOf('zz').above), <String>[
        'zz-7201',
        'zz-pasaje-1',
      ]);
      final b1 = await cultureApp(reach: 'b1');
      expect(_ids(b1.wovenCultureOf('zz').all), <String>[
        'zz-7101',
        'zz-7201',
        'zz-pasaje-1',
      ]);
    });

    test('are offered on Today only while culture is on and not met', () async {
      final state = await cultureApp();
      expect(state.nextCultureItem('zz')!.id, 'zz-7101');
      state.settings.cultureItems = false;
      expect(state.nextCultureItem('zz'), isNull);
    });
  });

  group('the timeline of the culture, to today', () {
    test('has the works at the level, the legacy marks and today', () async {
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

    test(
      'leaves out a work above the level, and the person only it cites',
      () async {
        final state = await cultureApp();
        final timeline = state.cultureTimelineOf('zz');
        expect(timeline.works, isEmpty);
        expect(timeline.spans.map((s) => s.creator.id), isEmpty);
        expect(state.cultureTimelineEntriesOf('zz'), isEmpty);
      },
    );

    test('runs from the works to the present year', () {
      final file = parseCreators(cultureCreators, source: 'zz.yaml');
      final built = buildTimeline(
        file,
        const <TimelineWork>[
          TimelineWork(
            cardId: 'w',
            creatorIds: <String>['zz-machado'],
            year: 1912,
            level: Level.a1,
          ),
        ],
        Level.a1,
        today: 2026,
      );
      expect(built.end, 2026);
      expect(built.works.single.year, 1912);
    });
  });

  group('the recommendations list', () {
    final file = parseRecommendations(
      cultureRecommendations,
      source: 'zz.yaml',
    );
    const latin = RecommendationCourse(latinOnly: true);

    test('offers what the level allows and counts what it hides', () {
      final a1 = recommendationList(file.recommendations, latin, Level.a1);
      expect(a1.offered.map((r) => r.id), <String>['zz-rec-camino']);
      expect(a1.hiddenAbove, 2);
      expect(a1.unlocksAt, Level.a2);
      expect(a1.media.map((m) => m.name), <String>['book']);
      final b1 = recommendationList(file.recommendations, latin, Level.b1);
      expect(b1.offered, hasLength(3));
      expect(b1.hiddenAbove, 0);
      expect(b1.count(file.recommendations.first.medium), 2);
      expect(b1.of(null), hasLength(3));
    });

    test('offers no book to a learner who learns no script', () {
      final none = recommendationList(
        file.recommendations,
        const RecommendationCourse(),
        Level.b1,
      );
      expect(none.offered.map((r) => r.id), <String>['zz-rec-pelicula']);
      // A book they would never see is not counted as above their level.
      expect(
        recommendationList(
          file.recommendations,
          const RecommendationCourse(),
          Level.a1,
        ).hiddenAbove,
        1,
      );
    });

    test('shows a script-only learner books in their script only', () {
      final list = recommendationList(
        file.recommendations,
        const RecommendationCourse(
          scriptOnly: true,
          scriptsLearned: <String>{'devanagari'},
        ),
        Level.b1,
      );
      expect(list.offered, isEmpty);
      expect(list.otherScript, 2);
      final latinOnly = recommendationList(
        file.recommendations,
        const RecommendationCourse(
          scriptOnly: true,
          scriptsLearned: <String>{'latin'},
        ),
        Level.b1,
      );
      expect(latinOnly.offered.map((r) => r.id), <String>[
        'zz-rec-camino',
        'zz-rec-novela',
      ]);
    });

    test('gives the public-domain badge to a work a deck quotes', () {
      expect(isPublicDomainWork(file.byId('zz-rec-camino')!), isTrue);
      expect(isPublicDomainWork(file.byId('zz-rec-pelicula')!), isFalse);
    });
  });
}
