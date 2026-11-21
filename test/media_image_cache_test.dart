// The culture pictures' cache (wiki/Plan-Culture-Media.md, work package 4a):
// binary entries in a store, a bounded least-recently-used memory, every
// picture checked against its hash, overlapping requests shared.

import 'dart:async';
import 'dart:typed_data';

import 'package:fluenough/app/media_image_cache.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_blob_store.dart';

Uint8List _bytes(int n, [int seed = 0]) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 7 + seed) % 251));

/// A picture, its hash and a fetch that counts its calls.
class _Pic {
  _Pic(int n, [int seed = 0]) : bytes = _bytes(n, seed) {
    sha = sha256Hex(bytes);
  }

  final Uint8List bytes;
  late final String sha;
  int fetches = 0;

  Future<Uint8List?> fetch() async {
    fetches++;
    return bytes;
  }

  Future<Uint8List?> load(MediaImageCache cache) =>
      cache.load(sha, bytes.length, fetch);
}

void main() {
  group('the memory', () {
    test('keeps the most recently used pictures within the count', () async {
      final cache = MediaImageCache(maxEntries: 2);
      final a = _Pic(10, 1), b = _Pic(10, 2), c = _Pic(10, 3);
      await a.load(cache);
      await b.load(cache);
      await a.load(cache); // a is now newer than b
      await c.load(cache); // b, the least recently used, goes
      expect(cache.entries, 2);
      expect(cache.holds(a.sha), isTrue);
      expect(cache.holds(b.sha), isFalse);
      expect(cache.holds(c.sha), isTrue);
    });

    test('keeps no more than its bytes, dropping the oldest first', () async {
      final cache = MediaImageCache(maxBytes: 100);
      final a = _Pic(40, 1), b = _Pic(40, 2), c = _Pic(40, 3);
      await a.load(cache);
      await b.load(cache);
      await c.load(cache);
      expect(cache.bytes, lessThanOrEqualTo(100));
      expect(cache.holds(a.sha), isFalse);
      expect(cache.holds(b.sha), isTrue);
      expect(cache.holds(c.sha), isTrue);
    });

    test(
      'returns a picture larger than its bytes without keeping it',
      () async {
        final cache = MediaImageCache(maxBytes: 50);
        final big = _Pic(80);
        expect(await big.load(cache), big.bytes);
        expect(cache.entries, 0);
        expect(cache.bytes, 0);
      },
    );

    test(
      'is read again from the store after an eviction, not fetched',
      () async {
        final store = MemoryBlobStore();
        final cache = MediaImageCache(store: store, maxEntries: 1);
        final a = _Pic(10, 1), b = _Pic(10, 2);
        await a.load(cache);
        await b.load(cache); // evicts a from memory
        expect(cache.holds(a.sha), isFalse);
        expect(await a.load(cache), a.bytes);
        expect(a.fetches, 1);
      },
    );
  });

  group('requests for one picture', () {
    test('that overlap share one fetch', () async {
      final cache = MediaImageCache();
      final gate = Completer<void>();
      var fetches = 0;
      final pic = _Pic(20);
      Future<Uint8List?> slow() async {
        fetches++;
        await gate.future;
        return pic.bytes;
      }

      final first = cache.load(pic.sha, 20, slow);
      final second = cache.load(pic.sha, 20, slow);
      gate.complete();
      expect(await first, pic.bytes);
      expect(await second, pic.bytes);
      expect(fetches, 1);
    });

    test('after a failure start afresh', () async {
      final cache = MediaImageCache();
      final pic = _Pic(20);
      expect(await cache.load(pic.sha, 20, () async => null), isNull);
      expect(await pic.load(cache), pic.bytes);
    });
  });

  group('the checks', () {
    test('refuse a fetched picture whose hash is not the index\'s', () async {
      final store = MemoryBlobStore();
      final problems = <String>[];
      final cache = MediaImageCache(store: store, onProblem: problems.add);
      final pic = _Pic(20, 1);
      final other = _bytes(20, 2);
      expect(await cache.load(pic.sha, 20, () async => other), isNull);
      expect(store.data, isEmpty);
      expect(cache.entries, 0);
      expect(problems, isNotEmpty);
    });

    test('refuse a fetched picture of the wrong size', () async {
      final cache = MediaImageCache();
      final pic = _Pic(20);
      expect(await cache.load(pic.sha, 21, () async => pic.bytes), isNull);
    });

    test(
      'delete a kept entry that no longer matches, and fetch again',
      () async {
        final store = MemoryBlobStore();
        final pic = _Pic(20);
        store.data[MediaImageCache.keyOf(pic.sha)] = _bytes(20, 9); // damaged
        final cache = MediaImageCache(store: store);
        expect(await pic.load(cache), pic.bytes);
        expect(pic.fetches, 1);
        expect(store.data[MediaImageCache.keyOf(pic.sha)], pic.bytes);
      },
    );

    test('are not repeated once the picture is in memory', () async {
      final store = MemoryBlobStore();
      final pic = _Pic(20);
      final cache = MediaImageCache(store: store);
      await pic.load(cache);
      store.failReads = true; // a read now would fail
      expect(await pic.load(cache), pic.bytes);
    });
  });

  group('the store', () {
    test('keeps a picture as binary, for the next session, offline', () async {
      final store = MemoryBlobStore();
      final pic = _Pic(64);
      await pic.load(MediaImageCache(store: store));
      expect(store.data[MediaImageCache.keyOf(pic.sha)], pic.bytes);
      final later = MediaImageCache(store: store);
      var asked = 0;
      final got = await later.load(pic.sha, 64, () async {
        asked++;
        return null; // offline
      });
      expect(got, pic.bytes);
      expect(asked, 0);
    });

    test(
      'that fails to read once is read again, and given up after three',
      () async {
        final store = MemoryBlobStore();
        final pics = <_Pic>[for (var i = 0; i < 5; i++) _Pic(10, i)];
        final cache = MediaImageCache(store: store, maxEntries: 1);
        await pics[0].load(cache);
        await pics[1].load(cache); // pics[0] now only in the store
        store.failReads = true;
        expect(await pics[0].load(cache), pics[0].bytes); // fetched, 1 failure
        store.failReads = false;
        // One failure did not stop reading: pics[1] is read from the store.
        await pics[2].load(cache);
        expect(await pics[1].load(cache), pics[1].bytes);
        expect(pics[1].fetches, 1);
        // Three in a row do.
        store.failReads = true;
        for (final pic in pics.skip(2)) {
          await pic.load(cache);
        }
        store.failReads = false;
        final before = pics[3].fetches;
        await pics[4].load(cache);
        await pics[3].load(cache);
        expect(pics[3].fetches, before + 1);
      },
    );

    test('that is full still shows the picture, and stops writing', () async {
      final store = MemoryBlobStore()..failWrites = true;
      final problems = <String>[];
      final cache = MediaImageCache(store: store, onProblem: problems.add);
      final a = _Pic(10, 1), b = _Pic(10, 2);
      expect(await a.load(cache), a.bytes);
      expect(await b.load(cache), b.bytes);
      expect(store.writes, 1);
      expect(problems, hasLength(1));
    });

    test('that is denied is left alone and the picture fetched', () async {
      final store = MemoryBlobStore()..failReads = true;
      final cache = MediaImageCache(store: store);
      final pic = _Pic(10);
      expect(await pic.load(cache), pic.bytes);
    });

    test(
      'does not keep a picture whose course is removed while it loads',
      () async {
        final store = MemoryBlobStore();
        final cache = MediaImageCache(store: store);
        final pic = _Pic(10);
        final gate = Completer<void>();
        final loading = cache.load(pic.sha, 10, () async {
          await gate.future;
          return pic.bytes;
        });
        await Future<void>.delayed(Duration.zero);
        await cache.remove(<String>[pic.sha]);
        gate.complete();
        expect(await loading, pic.bytes); // shown
        expect(cache.holds(pic.sha), isFalse);
        expect(store.data, isEmpty);
      },
    );

    test('prunes kept pictures the index does not list', () async {
      final store = MemoryBlobStore();
      final cache = MediaImageCache(store: store);
      final a = _Pic(10, 1), b = _Pic(10, 2);
      await a.load(cache);
      await b.load(cache);
      store.data['other-thing'] = _bytes(3);
      await cache.prune(<String>{a.sha});
      expect(store.data.keys.toSet(), <String>{
        MediaImageCache.keyOf(a.sha),
        'other-thing',
      });
    });

    test('loses a picture when its course is removed', () async {
      final store = MemoryBlobStore();
      final cache = MediaImageCache(store: store);
      final a = _Pic(10, 1), b = _Pic(10, 2);
      await a.load(cache);
      await b.load(cache);
      await cache.remove(<String>[a.sha]);
      expect(cache.holds(a.sha), isFalse);
      expect(cache.holds(b.sha), isTrue);
      expect(store.data.keys, <String>[MediaImageCache.keyOf(b.sha)]);
      expect(cache.bytes, 10);
    });
  });
}
