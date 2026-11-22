// A download's hashes and checks leave the UI isolate (#1699): a batch of
// files is checked in one job with the result of checking them one by one,
// a large file is hashed on an isolate with the same digest, and the
// downloads use the batch check, hash and notify as asked.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/kinds_fixture.dart';

DeckFileBytes _file(String path, String text) =>
    (path: path, bytes: Uint8List.fromList(utf8.encode(text)));

void main() {
  final all = kindsFixtureFiles();
  final good = <String, String>{
    'decks/creators/zz.yaml': all['decks/creators/zz.yaml']!,
    'decks/sections.yaml': all['decks/sections.yaml']!,
  };
  const broken = 'schema: 1\nid: es-en-core-100\n';

  group('checking a batch', () {
    test('passes files that pass one by one', () {
      final batch = <DeckFileBytes>[
        for (final e in good.entries) _file(e.key, e.value),
      ];
      expect(batch, isNotEmpty);
      for (final f in batch) {
        expect(
          DeckCatalog.checkFile(f.path, utf8.decode(f.bytes)),
          isNull,
          reason: f.path,
        );
      }
      expect(checkDeckBatch(batch), isNull);
    });

    test('names the first file with a problem, as the loop did', () {
      final first = good.entries.first;
      final problem = checkDeckBatch(<DeckFileBytes>[
        _file(first.key, first.value),
        _file('decks/es/en/es-en-core-100.yaml', broken),
        _file('decks/es/en/other.yaml', broken),
      ]);
      expect(problem, isNotNull);
      expect(problem!.path, 'decks/es/en/es-en-core-100.yaml');
      expect(problem.notUtf8, isFalse);
      expect(
        problem.message,
        DeckCatalog.checkFile('decks/es/en/es-en-core-100.yaml', broken),
      );
    });

    test('says a file that is not UTF-8 is not', () {
      final problem = checkDeckBatch(<DeckFileBytes>[
        (path: 'decks/x.yaml', bytes: Uint8List.fromList(<int>[0xff, 0xfe])),
      ]);
      expect(problem!.notUtf8, isTrue);
      expect(problem.path, 'decks/x.yaml');
    });

    test('on an isolate gives what in place gives', () async {
      final batch = <DeckFileBytes>[
        for (final e in good.entries) _file(e.key, e.value),
        _file('decks/es/en/es-en-core-100.yaml', broken),
      ];
      final here = checkDeckBatch(batch);
      final there = await checkBatchInIsolate(batch);
      expect(there, isNotNull);
      expect(there!.path, here!.path);
      expect(there.message, here.message);
      expect(there.notUtf8, here.notUtf8);
      expect(await checkBatchInIsolate(const <DeckFileBytes>[]), isNull);
    });
  });

  group('hashing on an isolate', () {
    test('gives the digest of hashing in place, small and large', () async {
      final small = Uint8List.fromList(List<int>.generate(100, (i) => i));
      final large = Uint8List.fromList(
        List<int>.generate(isolateHashBytes * 3 + 7, (i) => (i * 31) & 0xff),
      );
      expect(await sha256InIsolate(small), sha256Hex(small));
      expect(await sha256InIsolate(large), sha256Hex(large));
      expect(await sha256InIsolate(large.toList()), sha256Hex(large));
    });
  });

  group('the downloads', () {
    const english = <String>['en'];
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;
    late AppLog log;

    setUp(() {
      remote = FakeDeckRemote(repoFiles(const <String>['es']));
      phone = MemoryDownloadedDecks();
      log = AppLog(clock: () => DateTime.utc(2026, 11, 22));
    });

    DeckDownloads downloads({
      DeckBatchCheck? batchCheck,
      Future<String> Function(List<int>)? hasher,
      DeckFileCheck check = DeckCatalog.checkFile,
    }) {
      final d = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => DateTime(2026, 11, 22),
        log: log,
        check: check,
        batchCheck: batchCheck,
        hasher: hasher,
      );
      addTearDown(d.dispose);
      return d;
    }

    test('check the batch in one call and never file by file', () async {
      final batches = <List<String>>[];
      var oneByOne = 0;
      var hashed = 0;
      final d = downloads(
        batchCheck: (files) async {
          batches.add(<String>[for (final f in files) f.path]);
          return checkDeckBatch(files);
        },
        hasher: (bytes) async {
          hashed++;
          return sha256Hex(bytes);
        },
        check: (path, text) {
          oneByOne++;
          return DeckCatalog.checkFile(path, text);
        },
      );
      await d.open();
      expect(await d.downloadFirst('es', english), isNull);
      expect(oneByOne, 0);
      expect(batches, isNotEmpty);
      expect(batches.expand((b) => b).toSet(), phone.files.keys.toSet());
      expect(hashed, greaterThanOrEqualTo(phone.files.length));
    });

    test('a batch with a problem keeps nothing and says which file', () async {
      final d = downloads(
        batchCheck: (files) async => (
          path: files.first.path,
          message: 'broken on purpose',
          notUtf8: false,
        ),
      );
      await d.open();
      expect(await d.downloadFirst('es', english), DeckDownloadFailure.invalid);
      expect(phone.files, isEmpty);
      expect(
        log.entries.any(
          (e) =>
              e.message ==
              'Downloaded deck failed its check: broken on purpose',
        ),
        isTrue,
      );
    });
  });
}
