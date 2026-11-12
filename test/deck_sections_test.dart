// The sections file (wiki/Plan-Deck-Kinds-And-Topics.md, D8, T11):
// `decks/sections.yaml` holds the Decks tab's sections, the deck genres, the
// professions and the search kinds as data. It is read tolerantly (a bad entry
// costs itself), kept like the theme list, and falls back to the copy bundled
// in the app.

import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/shared_deck_source.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/sections.dart';
import 'package:fluenough/core/decks/shared_data.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture() =>
    File('test/fixtures/deck-kinds/decks/sections.yaml').readAsStringSync();

String _bundled() => File('decks/sections.yaml').readAsStringSync();

Deck _deck({String? genre, String? section, bool? weave}) => Deck(
  id: 'zz-en-x',
  name: 'X',
  kind: DeckKind.vocab,
  language: const LanguageInfo(code: 'zz', iso639_3: 'zzz', name: 'Test'),
  native: const LanguageInfo(code: 'en', iso639_3: 'eng', name: 'English'),
  license: 'CC0-1.0',
  cards: const [],
  genre: genre,
  section: section,
  weave: weave,
);

void main() {
  group('parseSections', () {
    final sections = parseSections(_fixture());

    test('reads the sections, genres, professions and search kinds', () {
      expect(sections.sections.map((s) => s.id), <String>[
        'path',
        'beyond-basics',
        'professional',
      ]);
      expect(sections.genres.map((g) => g.id), <String>[
        'culture',
        'proverbs',
        'multiword',
        'professional',
      ]);
      expect(sections.professions.map((p) => p.id), <String>['medicine']);
      expect(sections.searchKinds, hasLength(9));
      expect(sections.problems, isEmpty);
    });

    test('keeps the names by language and whether a section is listed', () {
      expect(sections.section('path')!.names['en'], 'Course');
      expect(sections.section('professional')!.listed, isFalse);
      expect(sections.section('beyond-basics')!.listed, isTrue);
    });

    test('keeps a genre\'s section, search kind and weave default', () {
      final culture = sections.genre('culture')!;
      expect(culture.section, 'beyond-basics');
      expect(culture.searchKind, 'culture');
      expect(culture.weave, isTrue);
      expect(sections.genre('professional')!.weave, isFalse);
    });

    test('puts the search kinds in order, with their row template', () {
      expect(sections.searchKinds.first.id, 'situations');
      expect(sections.searchKinds.first.row, 'scene');
      expect(sections.searchKinds.last.id, 'multiword');
      expect(sections.searchKinds.map((k) => k.order).toList(), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
      expect(sections.searchKind('topics')!.row, 'topic');
    });

    test('reads the copy bundled in the app', () {
      final bundled = parseSections(_bundled());
      expect(bundled.genres.map((g) => g.id), contains('culture'));
      expect(bundled.professions, isEmpty);
      expect(bundled.problems, isEmpty);
    });
  });

  group('a section for a deck', () {
    final sections = parseSections(_fixture());

    test('is path for a deck with no genre', () {
      expect(sections.sectionIdOf(_deck()), 'path');
    });

    test('is its genre\'s', () {
      expect(sections.sectionIdOf(_deck(genre: 'culture')), 'beyond-basics');
      expect(
        sections.sectionIdOf(_deck(genre: 'professional')),
        'professional',
      );
    });

    test('is its own when it names one the file lists', () {
      expect(
        sections.sectionIdOf(_deck(genre: 'culture', section: 'path')),
        'path',
      );
    });

    test('is beyond the basics for a genre or a section the file lacks', () {
      expect(sections.sectionIdOf(_deck(genre: 'later')), 'beyond-basics');
      expect(
        sections.sectionIdOf(_deck(genre: 'culture', section: 'later')),
        'beyond-basics',
      );
      expect(sections.sectionIdOf(_deck(section: 'later')), 'beyond-basics');
    });

    test('is path for every deck while no file is read', () {
      expect(DeckSections.empty.sectionIdOf(_deck()), 'path');
      expect(
        DeckSections.empty.sectionIdOf(_deck(genre: 'culture')),
        'beyond-basics',
      );
    });

    test('weaves by its own flag, else its genre\'s, else not', () {
      expect(sections.weaves(_deck(genre: 'culture')), isTrue);
      expect(sections.weaves(_deck(genre: 'professional')), isFalse);
      expect(sections.weaves(_deck(genre: 'culture', weave: false)), isFalse);
      expect(sections.weaves(_deck()), isFalse);
      expect(sections.weaves(_deck(genre: 'later')), isFalse);
    });

    test('has the search kind of its genre', () {
      expect(sections.searchKindOf(_deck(genre: 'proverbs')), 'proverbs');
      expect(sections.searchKindOf(_deck()), isNull);
      expect(sections.searchKindOf(_deck(genre: 'later')), isNull);
    });
  });

  group('names', () {
    test('are the first spoken language that has one, else English', () {
      final names = <String, String>{'en': 'Course', 'hi': 'पाठ्यक्रम'};
      expect(nameIn(names, <String>['bn', 'hi']), 'पाठ्यक्रम');
      expect(nameIn(names, <String>['bn']), 'Course');
      expect(nameIn(<String, String>{'hi': 'x'}, <String>['bn']), 'x');
      expect(nameIn(const <String, String>{}, <String>['en']), '');
    });
  });

  group('tolerance', () {
    const header = 'schema: 1\nkind: "sections"\n';

    test('an entry that cannot be read costs itself, and is named', () {
      final read = parseSections('''
${header}sections:
  - { id: "path", name: { en: "Course" } }
  - { id: "Bad Id", name: { en: "x" } }
  - "not a mapping"
  - { id: "path", name: { en: "again" } }
genres:
  - { id: "culture", name: { en: "Culture" }, section: "path" }
search_kinds:
  - { id: "weird", name: { en: "W" }, row: "carousel", order: 1 }
  - { id: "cards", name: { en: "Words" }, row: "card", order: 2 }
''');
      expect(read.sections.map((s) => s.id), <String>['path']);
      expect(read.sections.single.names['en'], 'Course');
      expect(read.genres.single.id, 'culture');
      expect(read.searchKinds.map((k) => k.id), <String>['cards']);
      expect(read.problems.length, greaterThanOrEqualTo(4));
    });

    test('an entry with no English name is kept and named', () {
      final read = parseSections('''
${header}genres:
  - { id: "culture", name: { hi: "संस्कृति" } }
''');
      expect(read.genres.single.names, <String, String>{'hi': 'संस्कृति'});
      expect(read.problems, hasLength(1));
    });

    test('a list that is not a list costs itself', () {
      final read = parseSections('${header}genres: 5\nprofessions: []\n');
      expect(read.genres, isEmpty);
      expect(read.problems, hasLength(1));
    });

    test('unknown keys and a missing order are tolerated', () {
      final read = parseSections('''
${header}extra: true
search_kinds:
  - { id: "b", name: { en: "B" }, row: "deck" }
  - { id: "a", name: { en: "A" }, row: "deck", order: 1, more: 1 }
''');
      expect(read.searchKinds.map((k) => k.id), <String>['a', 'b']);
      expect(read.problems, isEmpty);
    });

    test('a file with no kind or of a later schema is refused whole', () {
      expect(
        () => parseSections('schema: 1\nthemes: []\n'),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => parseSections('schema: 2\nkind: "sections"\n'),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('newer'),
          ),
        ),
      );
      expect(() => parseSections(': : :'), throwsA(isA<Exception>()));
    });
  });

  group('as a shared file', () {
    test('is one the app reads, of schema 1', () {
      expect(sharedKinds['decks/sections.yaml'], 'sections');
      expect(supportedSharedSchemas['sections'], 1);
    });

    test('is checked as the catalog reads it', () {
      expect(checkSharedText('decks/sections.yaml', _fixture()), isNull);
      expect(
        checkSharedText('decks/sections.yaml', 'kind: themes\nschema: 1\n'),
        isNotNull,
      );
      expect(sharedNoteName('decks/sections.yaml'), 'shared-sections.yaml');
    });

    test('is checked by the downloader before it is kept', () {
      expect(DeckCatalog.checkFile('decks/sections.yaml', _fixture()), isNull);
      expect(
        DeckCatalog.checkFile(
          'decks/sections.yaml',
          'kind: sections\nschema: 9\n',
        ),
        isNotNull,
      );
    });
  });

  group('the catalog reads it before the bundled copy', () {
    const live = '''
schema: 1
kind: "sections"
sections:
  - { id: "path", name: { en: "Course" } }
genres:
  - { id: "later", name: { en: "Later" }, section: "path" }
''';

    Future<Catalog> load(Map<String, String> shared) => DeckCatalog(
      DeckSources(<DeckSource>[
        SharedDeckSource(() => shared),
        MemoryDeckSource(<String, String>{'decks/sections.yaml': _bundled()}),
      ]),
    ).load();

    test('a downloaded file replaces the bundled one', () async {
      final catalog = await load(<String, String>{'decks/sections.yaml': live});
      expect(catalog.sections.genres.map((g) => g.id), <String>['later']);
      expect(catalog.broken, isEmpty);
    });

    test('with none downloaded, the bundled file is used', () async {
      final catalog = await load(const <String, String>{});
      expect(catalog.sections.genres.map((g) => g.id), contains('culture'));
      expect(catalog.broken, isEmpty);
    });

    test(
      'a file that cannot be read is a broken file, and none is read',
      () async {
        final catalog = await load(<String, String>{
          'decks/sections.yaml': 'schema: 5\nkind: "sections"\n',
        });
        expect(catalog.sections.genres, isEmpty);
        expect(catalog.broken.single.path, 'decks/sections.yaml');
      },
    );

    test('a catalog with no file has the empty sections', () async {
      final catalog = await DeckCatalog(
        MemoryDeckSource(const <String, String>{}),
      ).load();
      expect(catalog.sections, same(DeckSections.empty));
    });
  });
}
