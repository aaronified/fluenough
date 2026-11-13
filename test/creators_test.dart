// Creators and the timeline (wiki/Plan-Deck-Kinds-And-Topics.md, D5, D5b, D5c,
// T15): the people behind the works are read once per language with their
// names, dates, era, bio, legacy and picture credit; the timeline is derived
// from them and the works the cards quote, runs to the present year, and shows
// only what the learner's level allows.

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/creators.dart';
import 'package:fluenough/core/data/deck_parser.dart' show DeckParseException;
import 'package:fluenough/core/decks/timeline.dart';
import 'package:fluenough/core/models/creator.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_fixture.dart';

const int _today = 2026;

CreatorsFile _fixture() => parseCreators(
  kindsFixtureFiles()['decks/creators/zz.yaml']!,
  source: 'zz.yaml',
);

void main() {
  group('the creators file', () {
    final file = _fixture();

    test('keeps each creator once, with era, dates, bio and credit', () {
      expect(file.problems, isEmpty);
      expect(file.creators.map((c) => c.id), <String>[
        'zz-ejemplo-autora',
        'zz-ejemplo-poeta',
      ]);
      final ana = file.byId('zz-ejemplo-autora')!;
      expect(ana.born, const CreatorYear(1850));
      expect(ana.died, const CreatorYear(1910));
      expect(ana.living, isFalse);
      expect(ana.era, 'moderna');
      expect(file.eraById('moderna')!.to, isNull);
      expect(ana.image!.credit, 'Test fixture');
      expect(ana.image!.licence, 'CC-BY-4.0');
      expect(file.byId('zz-ejemplo-poeta')!.image, isNull);
      expect(ana.related.single.creator, 'zz-ejemplo-poeta');
    });

    test('gives a name, a bio and a legacy in the learner\'s language', () {
      final ana = file.byId('zz-ejemplo-autora')!;
      expect(ana.nameFor(<String>['bn']).text, 'Ana Ejemplo');
      expect(ana.nameFor(<String>['en'], target: 'zz').text, 'Ana Ejemplo');
      expect(ana.bioFor(<String>['bn', 'en']), startsWith('A made-up writer'));
      final legacy = ana.legacyFor(Level.a1, <String>['en'])!;
      expect(legacy.text, 'Her letters are read in made-up schools.');
      expect(legacy.items.single.kind, LegacyKind.curriculum);
      expect(legacy.items.single.year, 1990);
      expect(legacy.items.single.sourceUrl, 'https://example.org/curriculum');
      expect(
        file.byId('zz-ejemplo-poeta')!.legacyFor(Level.b1, <String>[]),
        isNull,
      );
    });

    test('shows the target-language text at the highest level at or below', () {
      final read = parseCreators('''
schema: 1
kind: "creators"
language: "zz"
creators:
  - id: "zz-lee"
    name:
      zz: { text: "Lee", reading: "li", ipa: "li" }
      en: { text: "Lee" }
    born: 1900
    bio_target:
      A1: { text: "uno" }
      B1: { text: "tres", reading: "tres" }
    legacy:
      text: { en: "Known." }
      text_target:
        A2: { text: "dos" }
      items:
        - { kind: "film", year: 2001, text: { en: "A film." }, source: { work: "Film" } }
''', source: 'zz.yaml');
      final lee = read.byId('zz-lee')!;
      expect(lee.bioTargetFor(Level.a1)!.text, 'uno');
      expect(lee.bioTargetFor(Level.a2)!.text, 'uno');
      expect(lee.bioTargetFor(Level.b1)!.text, 'tres');
      expect(lee.bioTargetFor(null), isNull);
      expect(lee.legacyFor(Level.a1, <String>['en'])!.target, isNull);
      expect(lee.legacyFor(Level.a2, <String>['en'])!.target!.text, 'dos');
      expect(lee.names['zz']!.ipa, 'li');
    });

    test('costs only what cannot be read, and says why', () {
      final read = parseCreators('''
schema: 1
kind: "creators"
language: "zz"
eras:
  - { id: "old", name: { en: "Old" }, from: 1000, to: 1800 }
  - { id: "no-start", name: { en: "Broken" } }
creators:
  - id: "zz-fine"
    name: { en: { text: "Fine" } }
    born: { year: 1750, circa: true }
    died: 1800
    era: "missing"
  - id: "zz-nameless"
  - id: "zz-fine"
    name: { en: { text: "Again" } }
  - id: "zz-bad-year"
    name: { en: { text: "Bad" } }
    born: "long ago"
''', source: 'zz.yaml');
      expect(read.creators.map((c) => c.id), <String>[
        'zz-fine',
        'zz-bad-year',
      ]);
      expect(read.byId('zz-fine')!.born, const CreatorYear(1750, circa: true));
      expect(read.byId('zz-bad-year')!.born, isNull);
      expect(read.eras.map((e) => e.id), <String>['old']);
      expect(read.problems.length, greaterThanOrEqualTo(4));
    });

    test('refuses a file that is not a creators file, or is newer', () {
      expect(
        () => parseCreators('kind: "topics"\n', source: 'x.yaml'),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => parseCreators(
          'schema: 2\nkind: "creators"\nlanguage: "zz"\ncreators: []\n',
          source: 'x.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('is read by the catalog, with the recommendations beside it', () {
      final catalog = DeckCatalog.parseAll(kindsFixtureFiles());
      expect(catalog.creators['zz']!.creators, hasLength(2));
      expect(catalog.recommendations['zz']!.recommendations, hasLength(2));
      expect(catalog.dataProblems, isEmpty);
    });
  });

  group('the timeline', () {
    final file = _fixture();
    final works = <TimelineWork>[
      const TimelineWork(
        cardId: 'zz-9201',
        creatorIds: <String>['zz-ejemplo-autora'],
        year: 1890,
        level: Level.a2,
      ),
      const TimelineWork(
        cardId: 'zz-9202',
        creatorIds: <String>['zz-ejemplo-poeta'],
        year: 1950,
        yearEnd: 1960,
        level: Level.b1,
      ),
    ];

    test('puts spans, work points, legacy marks and eras on a line that ends today', () {
      final line = buildTimeline(file, works, Level.b1, today: _today);
      expect(line.end, _today);
      expect(line.start, 1850);
      expect(line.spans.map((s) => s.creator.id), <String>[
        'zz-ejemplo-autora',
        'zz-ejemplo-poeta',
      ]);
      expect(line.spans.first.from, 1850);
      expect(line.spans.first.to, 1910);
      expect(line.works.map((w) => w.year), <int>[1890, 1950]);
      expect(line.works.last.yearEnd, 1960);
      expect(line.legacy.single.year, 1990);
      // The open era runs to today.
      expect(line.bands.single.to, _today);
    });

    test('draws a living creator to today', () {
      final living = parseCreators('''
schema: 1
kind: "creators"
language: "zz"
creators:
  - id: "zz-viva"
    name: { en: { text: "Viva" } }
    born: 1980
    living: true
''', source: 'zz.yaml');
      final line = buildTimeline(
        living,
        const <TimelineWork>[],
        null,
        today: _today,
      );
      expect(line.spans.single.open, isTrue);
      expect(line.spans.single.to, _today);
    });

    test('leaves out a work above the level, and a creator only it cites', () {
      final a2 = buildTimeline(file, works, Level.a2, today: _today);
      expect(a2.works.map((w) => w.work.cardId), <String>['zz-9201']);
      expect(a2.spans.map((s) => s.creator.id), <String>['zz-ejemplo-autora']);
      // A learner of a language with no levels is given no levelled work.
      final none = buildTimeline(file, works, null, today: _today);
      expect(none.isEmpty, isTrue);
      expect(none.legacy, isEmpty);
    });

    test(
      'shows a creator that no work cites, and ignores a work of a stranger',
      () {
        final line = buildTimeline(
          file,
          const <TimelineWork>[
            TimelineWork(
              cardId: 'zz-0001',
              creatorIds: <String>['zz-unknown'],
              year: 1700,
            ),
          ],
          Level.a1,
          today: _today,
        );
        expect(line.spans, hasLength(2));
        expect(line.works, isEmpty);
      },
    );
  });
}
