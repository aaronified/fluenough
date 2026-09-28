import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/stats/gallery_entries.dart';

import '../../support/harness.dart';

/// Every Progress and Leeches state, drawn and scrolled to the end at text
/// scale 2.0, in light and dark: no overflow, no exception.
void main() {
  final entries = <GalleryEntry>[...statsGalleryEntries, ...statsGalleryStates];

  for (final entry in entries) {
    for (final dark in <bool>[false, true]) {
      testWidgets('${entry.id} at text scale 2.0${dark ? ', dark' : ''}', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final app = AppState.test();
        await app.load();
        await pumpScreen(
          tester,
          GalleryPreview(entry: entry, dark: dark),
          state: app,
        );
        expect(tester.takeException(), isNull);

        final lists = find.byType(Scrollable);
        if (lists.evaluate().isEmpty) return;
        for (var i = 0; i < 8; i++) {
          await tester.drag(lists.last, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'scrolled $i');
        }
      });
    }
  }
}
