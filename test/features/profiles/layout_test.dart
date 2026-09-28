import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/profiles/gallery_entries.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Every profile screen, as the gallery shows it and as this version ships
/// it, at a 2.0 text scale in both themes.
void main() {
  for (final entry in <GalleryEntry>[
    ...profilesGalleryEntries,
    ...profilesGalleryStates,
  ]) {
    for (final dark in <bool>[false, true]) {
      testWidgets('${entry.id} at text scale 2.0${dark ? ', dark' : ''}', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final app = AppState.test();
        await app.load();
        final make = entry.state ?? GalleryFixtures.state;
        await pumpScreen(
          tester,
          Builder(builder: entry.builder),
          state: make(app),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(Scaffold).first);
        expect(
          Theme.of(context).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the PIN field fits at 2.0 once it is switched on', (
    tester,
  ) async {
    final entry = profilesGalleryEntries.firstWhere(
      (e) => e.id == 'new-profile',
    );
    await pumpProfiles(tester, Builder(builder: entry.builder), textScale: 2.0);
    // A lazy list: at 2.0 the switch is not built until scrolled to.
    final tile = find.byType(SwitchListTile);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });
}
