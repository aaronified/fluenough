import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import 'support/harness.dart';

/// Every screen and state the design's Gallery.dc.html lists, by its `start`
/// id. The gallery must keep offering each one; it lists other states too.
const List<String> designIds = <String>[
  'profiles',
  'pin',
  'pin-error',
  'new-profile',
  'today',
  'decks',
  'deck',
  'deck-novoice',
  'import',
  'import-error',
  'drill-recognition',
  'drill-recognition-revealed',
  'drill-production-accent',
  'drill-production-typo',
  'drill-production-script',
  'drill-production-translit',
  'drill-listening',
  'drill-grammar',
  'drill-pair',
  'drill-rtl',
  'summary',
  'stats',
  'leeches',
  'settings',
  'appearance',
  'voices',
];

/// Gallery entries that are part of a screen rather than one: they show on
/// a screen that has the bug icon.
const Set<String> notScreens = <String>{
  'drill-reading-glossary', // a sheet over the reading drill
  'settings-backup', // a section of Settings
};

void main() {
  test('the gallery lists every design screen, and no id twice', () {
    final ids = allGalleryEntries.map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate ids');
    expect(ids, containsAll(designIds));
    expect(ids, containsAll(darkGalleryIds));
  });

  testWidgets('every entry builds on its fixture state, and every screen '
      'has the bug icon (ADR-0021)', (tester) async {
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    final noReportButton = <String>[];
    for (final entry in <GalleryEntry>[fullAppEntry, ...allGalleryEntries]) {
      for (final dark in <bool>[false, true]) {
        await pumpScreen(
          tester,
          GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
          state: app,
        );
        expect(tester.takeException(), isNull, reason: '${entry.id} $dark');
        expect(find.byType(GalleryPreview), findsOneWidget);
        final reportButtons = find.descendant(
          of: find.byType(GalleryPreview),
          matching: find.byType(ReportButton, skipOffstage: false),
        );
        if (!dark &&
            !notScreens.contains(entry.id) &&
            reportButtons.evaluate().isEmpty) {
          noReportButton.add(entry.id);
        }
      }
    }
    expect(noReportButton, isEmpty);
  });

  testWidgets('the gallery page lists sections and opens a preview', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const GalleryPage());
    expect(find.text(GallerySection.profiles.title), findsOneWidget);
    await tester.tap(find.text(fullAppEntry.label));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPreview), findsOneWidget);
  });
}
