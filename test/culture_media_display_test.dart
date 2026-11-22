// Pictures on works and people (wiki/Plan-Culture-Media.md, work package 4b,
// ADR-0060; approved mockup `culture-media`): a work's poster and its page,
// the list thumb, the full-screen viewer, the creator card's portrait, the
// "Show pictures" switch and "Download pictures" row, and the index entries
// that carry them. Hindi and Bengali titles stand for scripts the card and
// page must hold at 1.4x text, light and dark. The pictures are small PNGs
// built in memory; nothing is fetched from the network.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/culture.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/media_image_cache.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/recommendations.dart';
import 'package:fluenough/core/decks/culture_options.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/models/creator.dart';
import 'package:fluenough/features/culture/creator_sheet.dart';
import 'package:fluenough/features/culture/culture_image_size.dart';
import 'package:fluenough/features/culture/culture_picture.dart';
import 'package:fluenough/features/culture/culture_works.dart';
import 'package:fluenough/features/culture/work_page.dart';
import 'package:fluenough/features/downloads/download_text.dart';
import 'package:fluenough/features/languages/pictures_download_tile.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';
import 'support/harness.dart';
import 'support/memory_blob_store.dart';
import 'support/png_fixture.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

const String _posterPath = 'decks/recommendations/images/zz-rec-camino.png';
const String _portraitPath = 'decks/creators/images/zz-cervantes.png';
const String _credit = 'Test fixture · The Fluenough tests · CC-BY-4.0';
const String _hindi = 'राजा हरिश्चंद्र';
const String _bengali = 'বিল্বমঙ্গল';

const ValueKey<String> _open = ValueKey<String>('culture-picture-open');

/// The recommendations file with a poster on the first work and a Hindi and
/// a Bengali title on the other two (which have none).
String _recommendations() => cultureRecommendations
    .replaceFirst(
      '    year: 1912\n',
      '    year: 1912\n'
          '    image: { file: "$_posterPath", credit: "Test fixture", '
          'author: "The Fluenough tests", licence: "CC-BY-4.0", '
          'licence_url: "https://creativecommons.org/licenses/by/4.0/", '
          'source_url: "https://commons.wikimedia.org/wiki/File:Test.png" }\n',
    )
    .replaceFirst(
      'title: { text: "Una película de prueba" }',
      'title: { text: "$_hindi" }',
    )
    .replaceFirst(
      'title: { text: "Una novela de prueba" }',
      'title: { text: "$_bengali" }',
    );

class _Fetcher implements DeckFetcher {
  _Fetcher(this.files);

  final Map<String, Uint8List> files;
  final List<String> asked = <String>[];

  /// The pictures asked for, by path.
  List<String> get pictures => <String>[
    for (final path in asked)
      if (path.contains('/images/')) path,
  ];

  @override
  Future<Fetched> fetch(String path, {bool fresh = false}) async {
    asked.add(path);
    final bytes = files[path];
    return bytes == null
        ? const Fetched.failed(FetchFailure.notFound)
        : Fetched(bytes);
  }
}

final Uint8List _poster = pngOf(600, 870);
final Uint8List _portrait = pngOf(400, 400);

Future<(AppState, _Fetcher)> _app({bool pictures = true}) async {
  Map<String, Object?> entry(String path, Uint8List bytes) {
    return <String, Object?>{
      'path': path,
      'size': bytes.length,
      'sha256': sha256Hex(bytes),
      'kind': 'image',
      'language': 'zz',
    };
  }

  final index = Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'version': 1,
        'languages': <Object?>[],
        'shared_media': <Object?>[
          entry(_posterPath, _poster),
          entry(_portraitPath, _portrait),
        ],
      }),
    ),
  );
  final fetcher = _Fetcher(<String, Uint8List>{
    'decks/index.json': index,
    _posterPath: _poster,
    _portraitPath: _portrait,
  });
  final settings = SettingsNotifier(spokenLanguages: const <String>['en']);
  if (!pictures) {
    settings.setCultureFor('zz', const CultureOptions(pictures: false));
  }
  final files = cultureWorld();
  files['decks/recommendations/zz.yaml'] = _recommendations();
  final state = AppState.test(
    decks: MemoryDeckSource(files),
    settings: settings,
    deckDownloads: DeckDownloads(
      fetcher: fetcher,
      files: MemoryDownloadedDecks(),
      clock: () => DateTime(2026, 11, 22),
      images: MediaImageCache(store: MemoryBlobStore()),
    ),
  );
  await state.load();
  return (state, fetcher);
}

List<ResizeImage> _decoded(WidgetTester tester, [Finder? within]) =>
    <ResizeImage>[
      for (final image in tester.widgetList<Image>(
        within == null
            ? find.byType(Image)
            : find.descendant(of: within, matching: find.byType(Image)),
      ))
        image.image as ResizeImage,
    ];

Creator _creator(AppState state, String id) =>
    state.creatorsOf('zz')!.creators.firstWhere((c) => c.id == id);

Widget _page(String id) => WorkPage(
  request: WorkRequest(language: 'zz', recommendationId: id),
);

void main() {
  group('the work page with a free poster', () {
    testWidgets('shows the poster at 200 x 290 dp, decoded at that size', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await pumpScreen(tester, _page('zz-rec-camino'), state: state);
      expect(find.byType(WorkPoster), findsOneWidget);
      expect(
        tester.getSize(find.byType(WorkPoster)),
        const Size(workPosterWidth, workPosterHeight),
      );
      final shown = _decoded(tester);
      expect(shown, hasLength(1));
      expect(shown.single.width, cultureDecodeWidth(workPosterWidth, 3));
      expect(shown.single.allowUpscaling, isFalse);
      expect(find.text('Campos de prueba'), findsOneWidget);
      // The medium icon sits beside the title only when there is no poster.
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    });

    testWidgets('credits the picture and links to its licence and source', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await pumpScreen(tester, _page('zz-rec-camino'), state: state);
      expect(find.text(_l10n.cultureImageCredit(_credit)), findsOneWidget);
      expect(find.text(_l10n.cultureImageLicenceLink), findsOneWidget);
      // The page keeps its briefing, the one primary action and no title in
      // the bar.
      expect(find.text(_l10n.recIComplete), findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    });

    testWidgets('opens the viewer at full size, with the credit, and closes', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await pumpScreen(tester, _page('zz-rec-camino'), state: state);
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      expect(find.byType(PictureViewer), findsOneWidget);
      final full = _decoded(tester, find.byType(PictureViewer));
      expect(full, hasLength(1));
      expect(full.single.width, cultureViewerCap);
      expect(find.text(_l10n.cultureImageCredit(_credit)), findsWidgets);
      expect(find.text(_l10n.cultureImageLicenceLink), findsWidgets);
      await tester.tap(find.byTooltip(_l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.byType(PictureViewer), findsNothing);
    });
  });

  group('the work page without a picture', () {
    testWidgets('keeps the medium icon beside the title, with no caption', (
      tester,
    ) async {
      usePhone(tester);
      final (state, fetcher) = await _app();
      await pumpScreen(tester, _page('zz-rec-pelicula'), state: state);
      expect(find.byType(WorkPoster), findsNothing);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.text(_hindi), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Image:'), findsNothing);
      expect(find.text(_l10n.cultureImageNone), findsNothing);
      expect(find.text(_l10n.cultureImageLicenceLink), findsNothing);
      expect(fetcher.pictures, isEmpty);
    });

    testWidgets('is the same with the Show pictures switch off', (
      tester,
    ) async {
      usePhone(tester);
      final (state, fetcher) = await _app(pictures: false);
      await pumpScreen(tester, _page('zz-rec-camino'), state: state);
      expect(find.byType(WorkPoster), findsNothing);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text(_l10n.cultureImageCredit(_credit)), findsNothing);
      // Nothing is downloaded for a picture that is not shown.
      expect(fetcher.pictures, isEmpty);
    });
  });

  group('the list thumb', () {
    Future<AppState> row(WidgetTester tester, {bool pictures = true}) async {
      final (state, _) = await _app(pictures: pictures);
      final works = state.catalogView.recommendations['zz']!;
      Widget of(String id) => CultureWorkRow(
        work: works.byId(id)!,
        language: 'zz',
        file: state.creatorsOf('zz'),
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[of('zz-rec-camino'), of('zz-rec-pelicula')],
          ),
        ),
        state: state,
      );
      return state;
    }

    testWidgets('is 48 x 68 dp with the poster, the icon for a work without', (
      tester,
    ) async {
      usePhone(tester);
      await row(tester);
      expect(find.byType(WorkThumb), findsOneWidget);
      expect(
        tester.getSize(find.byType(WorkThumb)),
        const Size(workThumbWidth, workThumbHeight),
      );
      final shown = _decoded(tester);
      expect(shown, hasLength(1));
      expect(shown.single.width, cultureDecodeWidth(workThumbWidth, 3));
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    });

    testWidgets('is the medium icon with the switch off', (tester) async {
      usePhone(tester);
      await row(tester, pictures: false);
      expect(find.byType(WorkThumb), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('a tap opens the work page', (tester) async {
      usePhone(tester);
      await row(tester);
      await tester.tap(find.text('Campos de prueba'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkPage), findsOneWidget);
      expect(find.text(_l10n.recIComplete), findsOneWidget);
    });
  });

  group('the creator card', () {
    Widget card(AppState state, String id) => Scaffold(
      body: CreatorCard(language: 'zz', creator: _creator(state, id)),
    );

    testWidgets('opens its portrait in the viewer, with the credit', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await pumpScreen(tester, card(state, 'zz-cervantes'), state: state);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.text(_l10n.cultureImageCredit(_credit)), findsOneWidget);
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      expect(find.byType(PictureViewer), findsOneWidget);
      expect(
        _decoded(tester, find.byType(PictureViewer)).single.width,
        cultureViewerCap,
      );
    });

    testWidgets('keeps the person icon and no caption without a picture', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await pumpScreen(tester, card(state, 'zz-machado'), state: state);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsNothing);
      expect(find.text(_l10n.cultureImageNone), findsNothing);
      expect(find.textContaining('Image:'), findsNothing);
    });

    testWidgets('shows neither picture nor caption with the switch off', (
      tester,
    ) async {
      usePhone(tester);
      final (state, fetcher) = await _app(pictures: false);
      await pumpScreen(tester, card(state, 'zz-cervantes'), state: state);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text(_l10n.cultureImageCredit(_credit)), findsNothing);
      expect(fetcher.pictures, isEmpty);
    });
  });

  group('Download pictures', () {
    testWidgets('shows the size, then downloads the language\'s pictures', (
      tester,
    ) async {
      usePhone(tester);
      final (state, fetcher) = await _app();
      await state.deckDownloads!.ensureIndex();
      await pumpScreen(
        tester,
        const Scaffold(body: PicturesDownloadTile(language: 'zz')),
        state: state,
      );
      expect(find.text(_l10n.culturePicturesDownload), findsOneWidget);
      expect(
        find.text(formatSize(_l10n, _poster.length + _portrait.length)),
        findsOneWidget,
      );
      await tester.tap(find.text(_l10n.culturePicturesDownload));
      await tester.pumpAndSettle();
      expect(
        fetcher.pictures,
        containsAll(<String>[_posterPath, _portraitPath]),
      );
      // The ring is a tick when it is done.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('is not drawn when the language lists no picture', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      await state.deckDownloads!.ensureIndex();
      await pumpScreen(
        tester,
        const Scaffold(body: PicturesDownloadTile(language: 'qq')),
        state: state,
      );
      expect(find.text(_l10n.culturePicturesDownload), findsNothing);
    });
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every picture screen at 1.4x text draws, ${mode.name}', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      final (state, _) = await _app();
      for (final id in <String>[
        'zz-rec-camino',
        'zz-rec-pelicula', // Hindi title
        'zz-rec-novela', // Bengali title
      ]) {
        await pumpScreen(tester, _page(id), state: state, themeMode: mode);
        expect(tester.takeException(), isNull, reason: '$id ${mode.name}');
      }
      final works = state.catalogView.recommendations['zz']!;
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: <Widget>[
              for (final work in works.recommendations)
                CultureWorkRow(
                  work: work,
                  language: 'zz',
                  file: state.creatorsOf('zz'),
                ),
            ],
          ),
        ),
        state: state,
        themeMode: mode,
      );
      expect(tester.takeException(), isNull, reason: 'list ${mode.name}');
      await pumpScreen(
        tester,
        Scaffold(
          body: CreatorCard(
            language: 'zz',
            creator: _creator(state, 'zz-cervantes'),
          ),
        ),
        state: state,
        themeMode: mode,
      );
      expect(tester.takeException(), isNull, reason: 'card ${mode.name}');
    });
  }

  group('Sources', () {
    testWidgets('credits of portraits and posters join the language row', (
      tester,
    ) async {
      usePhone(tester);
      final (state, _) = await _app();
      final lines = mediaCreditsOf(
        state.decks,
        pictures: pictureCreditsOf(state, _l10n),
      );
      final zz = lines.where((row) => row.language.code == 'zz').single;
      // The portrait and the poster share a credit: it is listed once.
      expect(zz.lines, <MediaCreditLine>[
        (credit: 'The Fluenough tests', license: 'CC-BY-4.0'),
      ]);
      await pumpScreen(tester, const SourcesPage(), state: state);
      await tester.scrollUntilVisible(
        find.text(_l10n.sourcesMedia),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(_l10n.sourcesMediaLine('The Fluenough tests', 'CC-BY-4.0')),
        findsOneWidget,
      );
    });
  });

  group('the data', () {
    test('a work reads its image block, one without has none', () {
      final file = parseRecommendations(_recommendations(), source: 'zz.yaml');
      final image = file.byId('zz-rec-camino')!.image!;
      expect(image.file, _posterPath);
      expect(image.licence, 'CC-BY-4.0');
      expect(image.author, 'The Fluenough tests');
      expect(image.sourceUrl, startsWith('https://commons.wikimedia.org/'));
      expect(file.byId('zz-rec-pelicula')!.image, isNull);
    });

    test('an image block with no file costs only the image', () {
      final file = parseRecommendations(
        cultureRecommendations.replaceFirst(
          '    year: 1912\n',
          '    year: 1912\n    image: { credit: "x" }\n',
        ),
        source: 'zz.yaml',
      );
      expect(file.byId('zz-rec-camino')!.image, isNull);
      expect(file.problems, isNotEmpty);
    });

    test('the pictures option is on by default and kept in the JSON', () {
      expect(CultureOptions.defaults.pictures, isTrue);
      const off = CultureOptions(pictures: false);
      expect(CultureOptions.fromJson(off.toJson()), off);
      expect(CultureOptions.fromJson(<String, Object?>{}).pictures, isTrue);
      expect(
        CultureOptions.fromJson(<String, Object?>{'pictures': 'no'}).pictures,
        isTrue,
      );
      expect(off.copyWith(items: false).pictures, isFalse);
      expect(off, isNot(CultureOptions.defaults));
    });
  });

  group('shared_media in the index', () {
    Map<String, Object?> entry(String path, {String? minApp}) =>
        <String, Object?>{
          'path': path,
          'size': 10,
          'sha256': 'a' * 64,
          'kind': 'image',
          'language': 'zz',
          'min_app': ?minApp,
        };

    String index(List<Map<String, Object?>> media) =>
        jsonEncode(<String, Object?>{
          'version': 1,
          'languages': <Object?>[],
          'shared_media': media,
        });

    final media = <Map<String, Object?>>[
      entry('decks/creators/images/zz-a.webp'),
      entry('decks/recommendations/images/zz-rec-b.webp', minApp: '0.12.1'),
    ];

    test('accepts a work image path and reads its min_app', () {
      final parsed = DeckIndex.parse(index(media));
      expect(parsed.sharedMedia, hasLength(2));
      expect(parsed.sharedMedia.first.minApp, isNull);
      expect(parsed.sharedMedia.last.minApp, '0.12.1');
      expect(parsed.sharedMedia.last.language, 'zz');
      expect(parsed.problems, isEmpty);
    });

    test('skips an entry above the app\'s version, with a log line', () {
      final old = DeckIndex.parse(index(media), appVersion: '0.12.0');
      expect(old.sharedMedia.map((m) => m.path), <String>[
        'decks/creators/images/zz-a.webp',
      ]);
      // Logged, not downloaded.
      expect(old.problems, hasLength(1));
      expect(old.problems.single, contains('needs a newer app'));
      final same = DeckIndex.parse(index(media), appVersion: '0.12.1');
      expect(same.sharedMedia, hasLength(2));
      final newer = DeckIndex.parse(index(media), appVersion: '0.13.0');
      expect(newer.sharedMedia, hasLength(2));
    });

    test('still passes by a path in no picture folder, with a problem', () {
      final parsed = DeckIndex.parse(
        index(<Map<String, Object?>>[
          entry('decks/other/images/zz-a.webp'),
          entry('decks/recommendations/images/../x.webp'),
        ]),
      );
      expect(parsed.sharedMedia, isEmpty);
      expect(parsed.problems, isNotEmpty);
    });
  });
}
