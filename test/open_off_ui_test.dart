// Opening the downloads walks the folders once and parses the index and the
// review queue off the UI isolate (#1699), with what opening gave before.

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/review/review_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

String _index(int languages) => jsonEncode(<String, Object?>{
  'version': 1,
  'languages': <Object?>[
    for (var i = 0; i < languages; i++)
      <String, Object?>{
        'code': const <String>['te', 'hi', 'es'][i],
        'name': 'L$i',
        'files': <Object?>[],
      },
  ],
});

String _queue() => jsonEncode(<String, Object?>{
  'format': 'fluenough-review-queue',
  'version': 1,
  'languages': <String, Object?>{
    'te': <String, Object?>{
      'cards': <String, Object?>{
        'te-0001': <Object?>[
          <String, Object?>{
            'question': 'Is this the usual word for water in everyday speech?',
          },
        ],
      },
    },
  },
});

void main() {
  group('the index and the review queue on an isolate', () {
    test('give what parsing here gives', () async {
      final here = DeckIndex.parse(_index(3));
      final there = await parseIndexInIsolate(_index(3));
      expect(there.languages.map((l) => l.code), <String>['te', 'hi', 'es']);
      expect(
        there.languages.map((l) => l.code),
        here.languages.map((l) => l.code),
      );
      final queue = await parseReviewQueueInIsolate(_queue());
      expect(
        queue.forCard('te', 'te-0001'),
        ReviewQueue.parse(_queue()).forCard('te', 'te-0001'),
      );
      expect(queue.isEmpty, isFalse);
      expect((await parseReviewQueueInIsolate('not json')).isEmpty, isTrue);
    });

    test('throw what parsing here throws', () async {
      await expectLater(
        parseIndexInIsolate('not json'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        parseIndexInIsolate(jsonEncode(<String, Object?>{'version': 99})),
        throwsA(isA<IndexTooNewException>()),
      );
    });

    test('are what a DeckDownloads opened off the UI isolate holds', () async {
      final phone = MemoryDownloadedDecks();
      phone.notes['index.json'] = _index(2);
      phone.notes['review-queue.json'] = _queue();
      final d = DeckDownloads(
        fetcher: FakeDeckRemote(const <String, String>{}),
        files: phone,
        clock: () => DateTime(2026, 11, 22),
        parseOffUi: true,
      );
      addTearDown(d.dispose);
      await d.open();
      expect(d.indexStatus, IndexStatus.ready);
      expect(d.index!.languages.map((l) => l.code), <String>['te', 'hi']);
      expect(d.reviewQueue.forCard('te', 'te-0001'), isNotEmpty);
    });
  });

  group('the folders are walked once', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fluenough'));
    tearDown(() => dir.deleteSync(recursive: true));

    const deck = 'decks/hi/hi-en-a.yaml';

    File put(String path, String text) => File('${dir.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    test('clean then manifest knows the files on disk, by hash, and '
        'removes what a download cut short left', () async {
      put(deck, 'schema: 1\n');
      final part = put('decks/hi/hi-en-b.yaml.part', 'half');
      for (final off in <bool>[false, true]) {
        final store = FileDownloadedDecks(dir, parseOffUi: off);
        await store.clean();
        final manifest = await store.manifest();
        expect(manifest.keys, <String>[deck]);
        expect(manifest[deck]!.sha256, sha256Hex(utf8.encode('schema: 1\n')));
        expect(manifest[deck]!.size, 10);
        expect(part.existsSync(), isFalse);
      }
    });

    test('is the manifest a walk of its own gives', () async {
      put(deck, 'schema: 1\n');
      put('decks/es/es-en-a.yaml', 'schema: 1\nid: x\n');
      final cleaned = FileDownloadedDecks(dir);
      await cleaned.clean();
      final withWalk = await cleaned.manifest();
      final alone = await FileDownloadedDecks(dir).manifest();
      expect(withWalk.keys, alone.keys);
      expect(
        <Object?>[for (final f in withWalk.values) (f.path, f.sha256)],
        <Object?>[for (final f in alone.values) (f.path, f.sha256)],
      );
    });

    test('a write after clean is seen by the manifest', () async {
      put(deck, 'schema: 1\n');
      final store = FileDownloadedDecks(dir);
      await store.clean();
      // Another file arrives after clean, as a download does: the cached
      // walk is dropped, and the file is known.
      put('decks/hi/hi-en-c.yaml', 'schema: 1\nid: c\n');
      await store.putAll(const {});
      final manifest = await store.manifest();
      expect(manifest.keys.toSet(), <String>{deck, 'decks/hi/hi-en-c.yaml'});
    });
  });
}
