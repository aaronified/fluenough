// The glue between the data layer and the screens (wiki
// Plan-Deck-Kinds-And-Topics.md, T16, T18, T24): the typed search is fed from
// the catalog, the recommendations gate from the learner's course and level,
// and a creator's image is downloaded on demand, checked by its hash alone and
// kept.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/item_search.dart';
import 'package:fluenough/app/recommendation_feed.dart';
import 'package:fluenough/app/topics.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/search/search_items.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_fixture.dart';
import 'support/kinds_world.dart';

/// Serves bytes by path and records what was asked.
class _Bytes implements DeckFetcher {
  _Bytes(this.files);

  final Map<String, Uint8List> files;
  final List<String> asked = <String>[];

  @override
  Future<Fetched> fetch(String path, {bool fresh = false}) async {
    asked.add(path);
    final bytes = files[path];
    return bytes == null
        ? const Fetched.failed(FetchFailure.notFound)
        : Fetched(bytes);
  }
}

const String _image = 'decks/creators/images/zz-autora.png';

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 7 + 3) % 251));

Uint8List _indexOf(Uint8List image, {String? sha}) => Uint8List.fromList(
  utf8.encode(
    jsonEncode(<String, Object?>{
      'version': 1,
      'languages': <Object?>[],
      'shared_media': <Object?>[
        <String, Object?>{
          'path': _image,
          'size': image.length,
          'sha256': sha ?? sha256Hex(image),
          'kind': 'image',
          'language': 'zz',
        },
      ],
    }),
  ),
);

DeckDownloads _downloads(_Bytes fetcher, MemoryDownloadedDecks phone) =>
    DeckDownloads(
      fetcher: fetcher,
      files: phone,
      clock: () => DateTime(2026, 11, 12),
    );

void main() {
  group('the typed search, fed from the catalog', () {
    test('finds items by kind, never the plain words', () async {
      final state = await kindsWorldApp();
      final found = state.searchItems('zz', 'house');
      expect(found.outcome.tabs.map((t) => t.kind), <String>[
        'situations',
        'topics',
      ]);
      expect(
        found.outcome.results.every((r) => r.row.kind != ResultKind.cards),
        isTrue,
      );
      expect(found.close, isFalse);
    });

    test('puts a typo right only when nothing is found exactly', () async {
      final state = await kindsWorldApp();
      final close = state.searchItems('zz', 'hose');
      expect(close.close, isTrue);
      expect(close.outcome.results, isNotEmpty);
      expect(
        state.searchItems('zz', 'hose', exact: true).outcome.results,
        isEmpty,
      );
      expect(state.searchItems('zz', 'house').close, isFalse);
    });

    test('lists what is above the level, which is never hidden', () async {
      final state = await kindsWorldApp();
      expect(state.searchItems('zz', 'library').outcome.results, hasLength(1));
    });

    test('is built once for a catalog, and topics with it', () async {
      final state = await kindsWorldApp();
      expect(
        identical(state.itemSearchFor('zz'), state.itemSearchFor('zz')),
        isTrue,
      );
      expect(identical(state.topicsOf('zz'), state.topicsOf('zz')), isTrue);
      expect(state.topicsOf('zz').resolved, hasLength(3));
    });

    test('reads the sections file of the downloaded decks', () async {
      final state = await kindsWorldApp();
      expect(
        state.catalogView.sections.searchKinds.map((k) => k.id),
        contains('topics'),
      );
    });
  });

  group('the recommendations, fed from the course', () {
    test('know a Latin-script course', () async {
      final fixture = kindsFixtureFiles();
      final state = await kindsWorldApp(
        files: <String, String>{
          ...kindsWorld(),
          'decks/recommendations/zz.yaml':
              fixture['decks/recommendations/zz.yaml']!,
          'decks/creators/zz.yaml': fixture['decks/creators/zz.yaml']!,
        },
      );
      final course = state.recommendationCourseOf('zz');
      expect(course.latinOnly, isTrue);
      expect(course.pathHasAlphabet, isFalse);
      expect(course.learnsScripts, isTrue);
      expect(
        state.catalogView.recommendations['zz']!.recommendations,
        hasLength(2),
      );
      // Every work is offered, whatever its level.
      expect(state.recommendationsFor('zz'), hasLength(2));
      expect(state.recommendationsFor('yy'), isEmpty);
    });
  });

  group('a creator image on demand', () {
    test(
      'is downloaded, checked, kept and read again from the phone',
      () async {
        final image = _bytes(64);
        final fetcher = _Bytes(<String, Uint8List>{
          'decks/index.json': _indexOf(image),
          _image: image,
        });
        final phone = MemoryDownloadedDecks();
        final first = _downloads(fetcher, phone);
        expect(await first.creatorImage(_image), image);
        expect(await first.creatorImage(_image), image);
        expect(fetcher.asked.where((p) => p == _image), hasLength(1));
        // Another run of the app finds it on the phone, not on the network.
        final again = _Bytes(<String, Uint8List>{
          'decks/index.json': _indexOf(image),
        });
        expect(await _downloads(again, phone).creatorImage(_image), image);
        expect(again.asked, isNot(contains(_image)));
      },
    );

    test('is nothing for an image the index does not list', () async {
      final image = _bytes(64);
      final fetcher = _Bytes(<String, Uint8List>{
        'decks/index.json': _indexOf(image),
      });
      final d = _downloads(fetcher, MemoryDownloadedDecks());
      expect(
        await d.creatorImage('decks/creators/images/zz-nadie.png'),
        isNull,
      );
      expect(
        fetcher.asked,
        isNot(contains('decks/creators/images/zz-nadie.png')),
      );
    });

    test(
      'is nothing for one that does not match its hash, and kept never',
      () async {
        final image = _bytes(64);
        final other = _bytes(65);
        final fetcher = _Bytes(<String, Uint8List>{
          'decks/index.json': _indexOf(image),
          _image: other,
        });
        final phone = MemoryDownloadedDecks();
        final d = _downloads(fetcher, phone);
        expect(await d.creatorImage(_image), isNull);
        expect(
          await phone.readNote('creator-image-${sha256Hex(image)}.b64'),
          isNull,
        );
      },
    );

    test('is nothing offline, and tried again next time', () async {
      final image = _bytes(64);
      final fetcher = _Bytes(<String, Uint8List>{
        'decks/index.json': _indexOf(image),
      });
      final d = _downloads(fetcher, MemoryDownloadedDecks());
      expect(await d.creatorImage(_image), isNull);
      fetcher.files[_image] = image;
      expect(await d.creatorImage(_image), image);
    });
  });
}
