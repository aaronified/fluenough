// The web build's downloaded decks and fonts survive a reload (#1012): kept
// in a BlobStore (IndexedDB in the browser, a map here), read back whole,
// checked against the index's hashes, bounded, versioned, and never able to
// break the app when the storage is denied, full or damaged. A reload
// downloads only the files GitHub changed.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/stored_downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/memory_blob_store.dart';

const String _family = 'decks/es/es-family.yaml';
const String _food = 'decks/es/es-food.yaml';
const String _travel = 'decks/es/es-travel.yaml';
const String _fontPath = 'decks/fonts/telugu/NotoSansTelugu.ttf';

/// [text] as the index would list it.
IndexFile _file(String path, String text) => IndexFile(
  path: path,
  size: utf8.encode(text).length,
  sha256: sha256Hex(utf8.encode(text)),
);

IndexFont _font(String text) => IndexFont(
  path: _fontPath,
  size: utf8.encode(text).length,
  sha256: sha256Hex(utf8.encode(text)),
  script: 'telugu',
  family: 'Noto Sans Telugu',
);

Map<IndexFile, List<int>> _one(String path, String text) =>
    <IndexFile, List<int>>{_file(path, text): utf8.encode(text)};

/// Opens what [store] holds, as a reload does, and waits for its writes.
Future<StoredDownloadedDecks> _open(
  MemoryBlobStore? store, {
  int maxBytes = StoredDownloadedDecks.defaultMaxBytes,
  List<String>? problems,
}) => StoredDownloadedDecks.load(
  store,
  maxBytes: maxBytes,
  onProblem: problems?.add,
);

void main() {
  group('kept across a reload', () {
    test('files, fonts and notes come back as they were', () async {
      final store = MemoryBlobStore();
      final first = await _open(store);
      await first.putAll(_one(_family, 'family deck'));
      await first.putAll(_one(_food, 'food deck'));
      await first.putFonts(<IndexFont, List<int>>{
        _font('telugu font'): utf8.encode('telugu font'),
      });
      await first.writeNote('index.json', '{"index": 1}');
      await first.flush();

      final second = await _open(store);
      expect(second.persisting, isTrue);
      expect(await second.list(), <String>[_family, _food]);
      expect(await second.read(_family), 'family deck');
      expect(
        (await second.manifest())[_food]!.sha256,
        sha256Hex(utf8.encode('food deck')),
      );
      expect((await second.fontManifest())[_fontPath]!.script, 'telugu');
      expect(utf8.decode((await second.readFont(_fontPath))!), 'telugu font');
      expect(await second.readNote('index.json'), '{"index": 1}');
      expect(await second.readNote('state.json'), isNull);
    });

    test('a replaced file is the new one, and a removed file or language '
        'stays removed', () async {
      final store = MemoryBlobStore();
      final first = await _open(store);
      await first.putAll(_one(_family, 'family deck'));
      await first.putAll(_one(_food, 'food deck'));
      await first.putAll(_one('decks/hi/hi-family.yaml', 'hindi deck'));
      await first.putAll(_one(_family, 'family deck, fixed'));
      await first.putAll(
        const <IndexFile, List<int>>{},
        remove: const <String>[_food],
      );
      await first.removeLanguage('hi');
      await first.flush();

      final second = await _open(store);
      expect(await second.list(), <String>[_family]);
      expect(await second.read(_family), 'family deck, fixed');
      expect(store.data.keys.where((k) => k.startsWith('file/')), <String>[
        'file/$_family',
      ]);
    });

    test('a removed font stays removed', () async {
      final store = MemoryBlobStore();
      final first = await _open(store);
      await first.putFonts(<IndexFont, List<int>>{
        _font('telugu font'): utf8.encode('telugu font'),
      });
      await first.removeFonts(const <String>[_fontPath]);
      await first.flush();

      final second = await _open(store);
      expect(await second.fontManifest(), isEmpty);
      expect(await second.readFont(_fontPath), isNull);
    });
  });

  group('storage that fails', () {
    test('with no storage at all the decks are kept in memory', () async {
      final decks = await _open(null);
      await decks.putAll(_one(_family, 'family deck'));
      await decks.writeNote('state.json', '{}');
      expect(decks.persisting, isFalse);
      expect(await decks.read(_family), 'family deck');
      expect(await decks.readNote('state.json'), '{}');
    });

    test('a write that fails (storage full) leaves the decks in memory and '
        'stops writing', () async {
      final store = MemoryBlobStore()..failWrites = true;
      final problems = <String>[];
      final decks = await _open(store, problems: problems);
      await decks.putAll(_one(_family, 'family deck'));
      await decks.flush();
      expect(decks.persisting, isFalse);
      expect(problems, hasLength(1));
      expect(await decks.read(_family), 'family deck');

      // No more attempts, and nothing half written.
      store.failWrites = false;
      await decks.putAll(_one(_food, 'food deck'));
      await decks.flush();
      expect(store.writes, 1);
      expect(store.data, isEmpty);
      expect(await decks.list(), <String>[_family, _food]);
      expect(await (await _open(store)).list(), isEmpty);
    });

    test(
      'storage that cannot be read starts with no decks, in memory',
      () async {
        final store = MemoryBlobStore();
        final first = await _open(store);
        await first.putAll(_one(_family, 'family deck'));
        await first.flush();

        store.failReads = true;
        final problems = <String>[];
        final second = await _open(store, problems: problems);
        expect(second.persisting, isFalse);
        expect(problems, hasLength(1));
        expect(await second.list(), isEmpty);
        await second.putAll(_one(_food, 'food deck'));
        expect(await second.read(_food), 'food deck');
      },
    );
  });

  group('what is stored is checked', () {
    Future<MemoryBlobStore> stored() async {
      final store = MemoryBlobStore();
      final decks = await _open(store);
      await decks.putAll(_one(_family, 'family deck'));
      await decks.putAll(_one(_food, 'food deck'));
      await decks.putFonts(<IndexFont, List<int>>{
        _font('telugu font'): utf8.encode('telugu font'),
      });
      await decks.writeNote('index.json', '{}');
      await decks.flush();
      return store;
    }

    test('data of another schema version is dropped, not read', () async {
      final store = await stored();
      store.data['schema'] = Uint8List.fromList(utf8.encode('99'));
      final problems = <String>[];
      final decks = await _open(store, problems: problems);
      expect(await decks.list(), isEmpty);
      expect(await decks.readNote('index.json'), isNull);
      expect(store.data, isEmpty);
      expect(problems, hasLength(1));

      // The store is usable again, under the current version.
      await decks.putAll(_one(_travel, 'travel deck'));
      await decks.flush();
      expect(
        utf8.decode(store.data['schema']!),
        '${StoredDownloadedDecks.schemaVersion}',
      );
      expect(await (await _open(store)).list(), <String>[_travel]);
    });

    test('data with no schema version is dropped', () async {
      final store = await stored();
      store.data.remove('schema');
      expect(await (await _open(store)).list(), isEmpty);
      expect(store.data, isEmpty);
    });

    test('a file whose bytes changed or are cut short is dropped and '
        'downloaded again, the rest is kept', () async {
      final store = await stored();
      // Same length, other bytes; and a font cut short.
      store.data['file/$_family'] = Uint8List.fromList(
        utf8.encode('FAMILY DECK'),
      );
      store.data['font/$_fontPath'] = Uint8List.fromList(utf8.encode('telugu'));
      final decks = await _open(store);
      await decks.flush();
      expect(await decks.list(), <String>[_food]);
      expect(await decks.manifest(), hasLength(1));
      expect(await decks.fontManifest(), isEmpty);
      expect(await decks.readFont(_fontPath), isNull);
      expect(store.data.containsKey('file/$_family'), isFalse);
      expect(store.data.containsKey('font/$_fontPath'), isFalse);
      expect(await decks.readNote('index.json'), '{}');
      // It stays gone after another reload.
      expect(await (await _open(store)).list(), <String>[_food]);
    });

    test('a file whose bytes are missing is dropped', () async {
      final store = await stored();
      store.data.remove('file/$_food');
      final decks = await _open(store);
      expect(await decks.list(), <String>[_family]);
    });

    test('a manifest that cannot be read drops every file, and the bytes '
        'it no longer lists are removed', () async {
      final store = await stored();
      store.data['manifest'] = Uint8List.fromList(utf8.encode('not json {'));
      final decks = await _open(store);
      await decks.flush();
      expect(await decks.list(), isEmpty);
      expect(await decks.fontManifest(), isEmpty);
      expect(store.data.keys.where((k) => k.startsWith('file/')), isEmpty);
      expect(store.data.keys.where((k) => k.startsWith('font/')), isEmpty);
    });
  });

  group('the bound on what is kept', () {
    test('the oldest written files are removed from the store first, and '
        'stay in memory for the visit', () async {
      final store = MemoryBlobStore();
      // Three files of ten bytes against a bound of twenty-five.
      final first = await _open(store, maxBytes: 25);
      await first.putAll(_one(_family, '1111111111'));
      await first.putAll(_one(_food, '2222222222'));
      await first.putAll(_one(_travel, '3333333333'));
      await first.flush();
      expect(await first.list(), <String>[_family, _food, _travel]);
      expect(
        store.data.keys.where((k) => k.startsWith('file/')).toList()..sort(),
        <String>['file/$_food', 'file/$_travel'],
      );

      final second = await _open(store, maxBytes: 25);
      expect(await second.list(), <String>[_food, _travel]);

      // A file written after the reload is newer than both.
      await second.putAll(_one(_family, '4444444444'));
      await second.flush();
      final third = await _open(store, maxBytes: 25);
      expect(await third.list(), <String>[_family, _travel]);
    });

    test('fonts count against the bound too', () async {
      final store = MemoryBlobStore();
      final decks = await _open(store, maxBytes: 15);
      await decks.putAll(_one(_family, '1111111111'));
      await decks.putFonts(<IndexFont, List<int>>{
        _font('222222222'): utf8.encode('222222222'),
      });
      await decks.flush();
      expect(
        store.data.keys.where(
          (k) => k.startsWith('file/') || k.startsWith('font/'),
        ),
        <String>['font/$_fontPath'],
      );
    });

    test(
      'a smaller bound than before trims the store on the next open',
      () async {
        final store = MemoryBlobStore();
        final first = await _open(store);
        await first.putAll(_one(_family, '1111111111'));
        await first.putAll(_one(_food, '2222222222'));
        await first.flush();
        final second = await _open(store, maxBytes: 10);
        await second.flush();
        expect(await second.list(), <String>[_food]);
        expect(await (await _open(store, maxBytes: 10)).list(), <String>[
          _food,
        ]);
      },
    );
  });

  group('after a reload the downloads', () {
    final now = DateTime(2026, 11, 4, 9);
    const english = <String>['en'];

    DeckDownloads downloads(
      FakeDeckRemote remote,
      StoredDownloadedDecks files,
    ) => DeckDownloads(fetcher: remote, files: files, clock: () => now);

    test('open offline with the language ready, and then fetch only the '
        'file whose hash changed', () async {
      final remote = FakeDeckRemote(repoFiles(const <String>['es']));
      final store = MemoryBlobStore();
      final first = await _open(store);
      final before = downloads(remote, first);
      await before.open();
      await before.download('es', english);
      await before.downloadRest('es', english);
      await first.flush();
      expect(before.isReady('es', english), isTrue);

      // A reload with no network: the decks and the index are still there.
      remote.failAll = FetchFailure.offline;
      final second = await _open(store);
      final offline = downloads(remote, second);
      await offline.open();
      expect(offline.indexStatus, IndexStatus.ready);
      expect(offline.isReady('es', english), isTrue);
      expect(offline.hasDecks('es'), isTrue);
      expect(await second.list(), await first.list());

      // Online again, with one deck changed on GitHub.
      remote.failAll = null;
      remote.asked.clear();
      final deck = (await second.list()).firstWhere(
        (path) => path.startsWith('decks/es/en/'),
      );
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      await offline.checkForUpdates(english, force: true);
      expect(await offline.update(), isNull);
      expect(await second.read(deck), endsWith('# a fix\n'));
      expect(remote.asked.where((p) => p != 'decks/index.json'), <String>[
        deck,
      ]);
    });

    test('with an index checked today make no request on a reload', () async {
      final remote = FakeDeckRemote(repoFiles(const <String>['es']));
      final store = MemoryBlobStore();
      final first = await _open(store);
      final before = downloads(remote, first);
      await before.open();
      await before.download('es', english);
      await before.downloadRest('es', english);
      await first.flush();

      remote.asked.clear();
      final offline = downloads(remote, await _open(store));
      await offline.open();
      await offline.checkForUpdates(english);
      expect(remote.asked, isEmpty);
      expect(offline.updates, isEmpty);
    });
  });
}
