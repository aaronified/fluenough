// A card's own image (#523): read from its deck, listed in the index under
// `media`, downloaded with the decks, shown where its emoji picture shows,
// and credited.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/card_media.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/ui/widgets/card_picture.dart';

import '../support/deck_remote.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const image = 'decks/zz/images/zz-9001.webp';

const credit =
    '{ source: "https://openmoji.org/library/emoji-1F3E0/", '
    'license: "CC-BY-SA-4.0", credit: "OpenMoji" }';

/// The B1 fixture's files, its home core's ఇల్లు (illu) with an image.
Map<String, String> withImage() => <String, String>{
  for (final file in Directory(appendix).listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/zz/${file.path.substring('$appendix/'.length)}': file
          .readAsStringSync()
          .replaceFirst(
            '    reading: "illu"\n',
            '    reading: "illu"\n    image: "$image"\n'
                '    image_credit: $credit\n',
          ),
  image: 'RIFF, as it were',
};

Catalog catalogOf(Map<String, String> files) =>
    DeckCatalog.parseAll(<String, String>{
      for (final MapEntry(:key, :value) in files.entries)
        if (key.endsWith('.yaml')) key: value,
    });

/// Finds every file under [root].
class _At implements CardMedia {
  const _At(this.root);

  final String root;

  @override
  String? localPath(String path) => '$root/$path';
}

void main() {
  test('a core card\'s image and its credit are read', () {
    final catalog = catalogOf(withImage());
    expect(catalog.broken, isEmpty);
    final house = catalog.decks
        .expand((d) => d.cards)
        .firstWhere((c) => c.id == 'zz-9001');
    expect(house.image, image);
    expect(house.imageCredit?.credit, 'OpenMoji');
    expect(house.imageCredit?.license, 'CC-BY-SA-4.0');
    expect(house.hasPicture, isTrue);
  });

  test('the index lists images under media, which download after the '
      'decks', () async {
    final index = DeckIndex.parse(indexFor(withImage()));
    final zz = index.language('zz')!;
    expect(zz.media.single.path, image);
    expect(zz.media.single.kind, 'image');
    expect(zz.files.map((f) => f.path), isNot(contains(image)));

    final phone = MemoryDownloadedDecks();
    final d = DeckDownloads(
      fetcher: FakeDeckRemote(withImage()),
      files: phone,
      clock: () => DateTime(2026, 10, 16),
    );
    await d.open();
    expect(await d.downloadFirst('zz', const <String>['en']), isNull);
    expect(await d.downloadRest('zz', const <String>['en']), isNull);
    expect(utf8.decode(phone.files[image]!), 'RIFF, as it were');
    expect(await phone.list(), isNot(contains(image)));
  });

  test('an image credits OpenMoji, and its maker by language', () {
    final catalog = catalogOf(withImage());
    expect(creditsOf(catalog.decks), contains(ContentCredit.openmoji));
    expect(mediaCreditsOf(catalog.decks).single.lines, <MediaCreditLine>[
      (credit: 'OpenMoji', license: 'CC-BY-SA-4.0'),
    ]);
  });

  group('the picture', () {
    Card house({String? picture = '🏠', String? img = image}) => Card(
      id: 'zz-9001',
      deckId: 'zz-en-home',
      target: 'ఇల్లు',
      native: 'home',
      picture: picture,
      image: img,
    );

    Future<void> show(WidgetTester tester, AppState state, Card card) =>
        tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(home: Center(child: CardPicture(card))),
          ),
        );

    testWidgets('is the card\'s image where it is on the phone', (
      tester,
    ) async {
      final state = AppState.test(media: const _At('/phone'));
      addTearDown(state.dispose);
      await show(tester, state, house());
      expect(find.byKey(const ValueKey<String>('image')), findsOneWidget);
    });

    testWidgets('is its emoji without the image on the phone', (tester) async {
      final state = AppState.test();
      addTearDown(state.dispose);
      await show(tester, state, house());
      expect(find.byKey(const ValueKey<String>('image')), findsNothing);
      expect(find.byKey(const ValueKey<String>('picture')), findsOneWidget);
    });

    testWidgets('is nothing with neither', (tester) async {
      final state = AppState.test();
      addTearDown(state.dispose);
      await show(tester, state, house(picture: null));
      expect(find.byType(Image), findsNothing);
      expect(house(picture: null, img: null).hasPicture, isFalse);
    });
  });
}
