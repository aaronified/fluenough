// Settings' Sources page credits Wiktionary for the narrow IPA in [ ]
// (owner, 2026-10-30): the line is on the page, tapping it opens
// en.wiktionary.org, and the licence row opens the CC BY-SA 4.0 text.

import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';

const _items = <String>[
  'wikimedia',
  'tatoeba',
  'wordnet',
  'fonts',
  'signwriting',
  'pictures',
  'listener',
  'packages',
  'writers',
  'people',
];

/// A phone as wide as the design's but tall enough to draw the whole page, so
/// that no row is left unbuilt below the fold.
void _useTallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390 * 3, 6000 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Finder _thanks(String id) => find.byKey(ValueKey<String>('thanks-$id'));

Future<AppState> _withSignWritingFont() async {
  final downloads = DeckDownloads(
    fetcher: FakeDeckRemote(const <String, String>{}),
    files: MemoryDownloadedDecks(),
    clock: () => DateTime(2026, 11, 21),
    scriptFonts: ScriptFonts(register: (family, bytes) async {}),
  );
  await downloads.fonts.load(
    IndexFont(
      path: 'decks/fonts/signwriting/Noto.ttf',
      size: 4,
      sha256: 'signwriting'.padRight(64, '0'),
      script: 'signwriting',
    ),
    Uint8List(4),
  );
  return AppState.test(deckDownloads: downloads);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Sources page credits Wiktionary for pronunciations', () {
    testWidgets('it says the IPA in [ ] is adapted from Wiktionary, '
        'CC BY-SA 4.0, and the links open', (tester) async {
      _useTallPhone(tester);
      final links = FixedLinks();
      await pumpScreen(
        tester,
        const SourcesPage(),
        state: AppState.test(links: links),
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(
          'Pronunciations in [ ] adapted from Wiktionary, '
          'licensed CC BY-SA 4.0.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.sourcesPhonetic));
      await tester.tap(
        find.ancestor(
          of: find.text(l10n.sourcesPhonetic),
          matching: find.byType(GroupedTile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.sourcesLicence));
      await tester.tap(
        find.ancestor(
          of: find.text(l10n.sourcesLicence),
          matching: find.byType(GroupedTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(links.asked, <String>[AppLinks.wiktionary, AppLinks.ccBySa]);
    });
  });

  test('a source naming a Sutton book is not a SignWriting credit', () {
    expect(ContentCredit.signwriting.namedIn('Sutton, A Book'), isFalse);
    expect(ContentCredit.signwriting.namedIn('SignWriting 2010'), isTrue);
  });

  group('the Sources page thanks everyone the app stands on', () {
    testWidgets('Thank you comes first, above Deck content, and shows the '
        'nine acknowledgements without a SignWriting font', (tester) async {
      _useTallPhone(tester);
      await pumpScreen(tester, const SourcesPage());
      final l10n = l10nOf(tester);
      final heading = find.text(l10n.sourcesThanks);
      expect(heading, findsOneWidget);
      expect(
        tester.getTopLeft(heading).dy,
        lessThan(tester.getTopLeft(find.text(l10n.sourcesDeckContent)).dy),
      );
      expect(find.text(l10n.sourcesThanksIntro), findsOneWidget);
      for (final id in _items.where((id) => id != 'signwriting')) {
        await tester.ensureVisible(_thanks(id));
        expect(_thanks(id), findsOneWidget, reason: id);
      }
      expect(_thanks('signwriting'), findsNothing);
      expect(find.text(l10n.sourcesThanksSignWritingLicence), findsNothing);
    });

    testWidgets('a SignWriting font on the phone adds its thanks, licence '
        'and copyright, making ten', (tester) async {
      _useTallPhone(tester);
      await pumpScreen(
        tester,
        const SourcesPage(),
        state: await _withSignWritingFont(),
      );
      final l10n = l10nOf(tester);
      for (final id in _items) {
        await tester.ensureVisible(_thanks(id));
        expect(_thanks(id), findsOneWidget, reason: id);
      }
      expect(
        find.text(
          'Sign pictures drawn with the Sutton SignWriting fonts, SIL OFL 1.1',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Copyright 1974-2014 Center for Sutton Movement Writing, Inc.',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.sourcesThanksSignWriting), findsOneWidget);
    });

    testWidgets('Open-source licences opens Flutter\'s licence page', (
      tester,
    ) async {
      _useTallPhone(tester);
      await pumpScreen(tester, const SourcesPage());
      final row = find.byKey(const ValueKey<String>('thanks-licences'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LicensePage), findsOneWidget);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('at 1.4x text on a 360 dp phone nothing overflows, in '
          '${mode.name}, and each row reads as one node', (tester) async {
        tester.view
          ..physicalSize = const Size(360 * 3, 8000 * 3)
          ..devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final handle = tester.ensureSemantics();
        addTearDown(handle.dispose);
        await pumpScreen(
          tester,
          const SourcesPage(),
          state: await _withSignWritingFont(),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        for (final id in _items) {
          await tester.ensureVisible(_thanks(id));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(_thanks('tatoeba')).label,
          allOf(
            contains(l10n.sourcesThanksTatoeba),
            contains(l10n.sourcesThanksTatoebaLine),
          ),
        );
      });
    }
  });
}
