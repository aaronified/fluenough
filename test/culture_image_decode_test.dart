// Culture pictures are decoded at the size they are shown (wiki/
// Plan-Culture-Media.md, work package 4a, ADR-0060): a 2048 px picture in a
// list of thirty must not be decoded thirty times at full size.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/media_image_cache.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/models/creator.dart';
import 'package:fluenough/features/culture/creator_sheet.dart';
import 'package:fluenough/features/culture/culture_image_size.dart';
import 'package:fluenough/features/culture/culture_parts.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';
import 'support/harness.dart';
import 'support/memory_blob_store.dart';
import 'support/png_fixture.dart';

const String _path = 'decks/creators/images/zz-cervantes.png';

class _Fetcher implements DeckFetcher {
  _Fetcher(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Fetched> fetch(String path, {bool fresh = false}) async {
    final bytes = files[path];
    return bytes == null
        ? const Fetched.failed(FetchFailure.notFound)
        : Fetched(bytes);
  }
}

/// A culture world whose creator has a 2048 x 1448 picture on offer.
Future<(AppState, MediaImageCache)> _world(Uint8List image) async {
  final index = Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'version': 1,
        'languages': <Object?>[],
        'shared_media': <Object?>[
          <String, Object?>{
            'path': _path,
            'size': image.length,
            'sha256': sha256Hex(image),
            'kind': 'image',
            'language': 'zz',
          },
        ],
      }),
    ),
  );
  final cache = MediaImageCache(store: MemoryBlobStore());
  final state = AppState.test(
    decks: MemoryDeckSource(cultureWorld()),
    deckDownloads: DeckDownloads(
      fetcher: _Fetcher(<String, Uint8List>{
        'decks/index.json': index,
        _path: image,
      }),
      files: MemoryDownloadedDecks(),
      clock: () => DateTime(2026, 11, 12),
      images: cache,
    ),
  );
  await state.load();
  return (state, cache);
}

Creator _cervantes(AppState state) =>
    state.creatorsOf('zz')!.creators.firstWhere((c) => c.id == 'zz-cervantes');

/// Thirty creator rows in a list, as the culture deck lists its people.
Widget _list(AppState state) {
  final creator = _cervantes(state);
  final info = cultureLanguage(state, 'zz');
  final file = state.creatorsOf('zz');
  return Scaffold(
    body: ListView.builder(
      itemCount: 30,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.all(8),
        child: CreatorSummary(creator: creator, language: info, file: file),
      ),
    ),
  );
}

List<ResizeImage> _decoded(WidgetTester tester) => <ResizeImage>[
  for (final image in tester.widgetList<Image>(find.byType(Image)))
    image.image as ResizeImage,
];

void main() {
  final big = pngOf(2048, 1448);

  group('the decode size', () {
    test('is the box in physical pixels with headroom, capped', () {
      expect(cultureDecodeWidth(48, 3), 216);
      expect(cultureDecodeWidth(96, 3), 432);
      expect(cultureDecodeWidth(48, 1), 72);
      // A huge box or ratio never decodes past the cap.
      expect(cultureDecodeWidth(2000, 4), cultureDecodeCap);
      expect(cultureDecodeWidth(0, 3), 1);
    });
  });

  group('a 2048 px picture', () {
    testWidgets('is decoded at the size shown in a list of thirty', (
      tester,
    ) async {
      usePhone(tester);
      final (state, cache) = await _world(big);
      await pumpScreen(tester, _list(state), state: state);
      final shown = _decoded(tester);
      expect(shown, isNotEmpty);
      for (final image in shown) {
        expect(image.imageProvider, isA<MemoryImage>());
        // 56 dp at 3x with headroom: a few hundred pixels, never 2048.
        expect(image.width, cultureDecodeWidth(56, 3));
        expect(image.width, lessThan(cultureDecodeCap));
        expect(image.height, isNull);
      }
      // One kept picture serves every row.
      expect(cache.entries, 1);
      expect(cache.bytes, big.length);
    });

    testWidgets('is decoded at the card\'s size in the creator card', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _world(big);
      await pumpScreen(
        tester,
        Scaffold(
          body: CreatorCard(language: 'zz', creator: _cervantes(state)),
        ),
        state: state,
      );
      expect(_decoded(tester).single.width, cultureDecodeWidth(96, 3));
    });

    testWidgets('keeps its credit line and licence link', (tester) async {
      usePhone(tester);
      final (state, _) = await _world(big);
      await pumpScreen(
        tester,
        Scaffold(
          body: CreatorCard(language: 'zz', creator: _cervantes(state)),
        ),
        state: state,
      );
      final l10n = AppLocalizationsEn();
      expect(
        find.text(
          l10n.cultureImageCredit(
            'Test fixture · The Fluenough tests · CC-BY-4.0',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.cultureImageLicenceLink), findsOneWidget);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('at 1.4x text on 360 dp does not overflow, ${mode.name}', (
        tester,
      ) async {
        usePhone(tester, textScale: 1.4);
        tester.view.physicalSize = const Size(360 * 3, 800 * 3);
        final (state, _) = await _world(big);
        await pumpScreen(tester, _list(state), state: state, themeMode: mode);
        expect(tester.takeException(), isNull);
        await pumpScreen(
          tester,
          Scaffold(
            body: CreatorCard(language: 'zz', creator: _cervantes(state)),
          ),
          state: state,
          themeMode: mode,
        );
        expect(tester.takeException(), isNull);
        expect(_decoded(tester), isNotEmpty);
      });
    }
  });
}
