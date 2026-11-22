// A change to the deck-owned files (creators, recommendations, sections) is
// patched into the catalog instead of a second full load (#1699): the small
// files are read again, the decks are not, the result equals a full load, and
// a change the patch cannot make safely says so, for a full load.

import 'dart:convert';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/kinds_fixture.dart';

const String _creators = 'decks/creators/zz.yaml';
const String _sections = 'decks/sections.yaml';
const String _poet = 'A made-up poet, who exists only for the tests.';

Map<String, Object?> _entry(String path, String kind, String text) {
  final bytes = utf8.encode(text);
  return <String, Object?>{
    'path': path,
    'size': bytes.length,
    'sha256': sha256Hex(bytes),
    'schema': 1,
    'kind': kind,
  };
}

String _index(List<Object?> shared) => jsonEncode(<String, Object?>{
  'version': 1,
  'schema': 1,
  'bundled': <String>[],
  'shared': shared,
  'languages': <Object?>[],
});

void main() {
  group('patching the shared files into a loaded catalog', () {
    late Map<String, String> files;
    late DeckCatalog catalog;
    late Catalog current;
    late String changed;

    setUp(() async {
      files = kindsFixtureFiles();
      catalog = DeckCatalog(MemoryDeckSource(files));
      current = await catalog.load();
      changed = files[_creators]!.replaceFirst(_poet, 'A changed bio.');
      expect(changed, isNot(files[_creators]), reason: 'the fixture changed');
    });

    List<String?> bios(Catalog c) => <String?>[
      for (final creator in c.creators['zz']!.creators) creator.bio['en'],
    ];

    test('equals a full load of the changed files, with no deck read '
        'again', () async {
      final patched = catalog.patchShared(current, <String, String>{
        _creators: changed,
      });
      expect(patched, isNotNull);
      final full = await DeckCatalog(
        MemoryDeckSource(<String, String>{...files, _creators: changed}),
      ).load();
      expect(bios(patched!), bios(full));
      expect(bios(patched), isNot(bios(current)));
      expect(patched.dataProblems, full.dataProblems);
      expect(patched.decks.map((d) => d.path), full.decks.map((d) => d.path));
      // The decks are the very ones loaded before: nothing was parsed again.
      for (final (i, entry) in current.decks.indexed) {
        expect(identical(patched.decks[i].deck, entry.deck), isTrue);
      }
      expect(identical(patched.sections, current.sections), isTrue);
      expect(patched.recommendations.keys, current.recommendations.keys);
    });

    test('patches the sections file too', () {
      final patched = catalog.patchShared(current, <String, String>{
        _sections: files[_sections]!,
      });
      expect(patched, isNotNull);
      expect(identical(patched!.creators, current.creators), isFalse);
      expect(bios(patched), bios(current));
    });

    test('is the whole catalog after replaceLoaded', () async {
      final patched = catalog.patchShared(current, <String, String>{
        _creators: changed,
      })!;
      catalog.replaceLoaded(patched);
      expect(identical(await catalog.load(), patched), isTrue);
    });

    test('gives up, for a full load, on a file it cannot patch', () {
      expect(
        catalog.patchShared(current, <String, String>{
          'decks/themes.yaml': files[_sections]!,
        }),
        isNull,
        reason: 'themes order the decks',
      );
      expect(
        catalog.patchShared(current, <String, String>{
          _creators: changed,
          'decks/zz/zz-words.yaml': 'x',
        }),
        isNull,
      );
      expect(catalog.patchShared(current, const <String, String>{}), isNull);
    });

    test('gives up on a file that does not parse', () {
      expect(
        catalog.patchShared(current, <String, String>{_creators: 'not: [yaml'}),
        isNull,
      );
    });
  });

  group('the downloads tell the app once', () {
    test('every shared file the index changed is one call with all the '
        'paths, and no full-files call', () async {
      final creators = kindsFixtureFiles()[_creators]!;
      final sections = kindsFixtureFiles()[_sections]!;
      final remote =
          FakeDeckRemote(<String, String>{
              _creators: creators,
              _sections: sections,
            })
            ..index = _index(<Object?>[
              _entry(_creators, 'creators', creators),
              _entry(_sections, 'sections', sections),
            ]);
      final d = DeckDownloads(
        fetcher: remote,
        files: MemoryDownloadedDecks(),
        clock: () => DateTime(2026, 11, 22),
        appVersion: '0.10.2',
      );
      addTearDown(d.dispose);
      final shared = <Set<String>>[];
      var full = 0;
      d.onFilesChanged = () async {
        full++;
      };
      d.onSharedChanged = (paths) async {
        shared.add(paths);
      };
      expect(await d.refreshIndex(), isTrue);
      expect(shared, hasLength(1));
      expect(shared.single, <String>{_creators, _sections});
      expect(full, 0);
      expect(d.changeCause, 'shared-file');
    });
  });
}
