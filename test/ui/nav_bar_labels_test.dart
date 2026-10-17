// The tab labels in Roboto, the theme's font, rather than the test font,
// whose square letters wrap "Progress" and "Settings" where Roboto does
// not. Roboto comes from the Flutter SDK.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';

import '../support/harness.dart';
import '../support/nav_bar_walk.dart' show clearLine;
import '../support/roboto.dart';

void main() {
  setUpAll(loadRoboto);

  // 1x, and the phone's largest text, which the app draws at its 1.4x cap
  // and the bar's labels at Material's own 1.3x (#501, #505).
  for (final scale in <double>[1.0, 2.0]) {
    testWidgets('the tab labels keep to one line above the three-button '
        'bar with the phone at ${scale}x text', (tester) async {
      usePhone(tester, navBar: true, textScale: scale);
      await pumpScreen(
        tester,
        GalleryPreview(entry: fullAppEntry),
        state: AppState.test(),
      );
      Finder label(String text) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(text),
      );
      // "Today" is too short to wrap: one line's height.
      final line = tester.getSize(label('Today')).height;
      for (final text in <String>['Decks', 'Progress', 'Settings']) {
        final rect = tester.getRect(label(text));
        expect(rect.height, line, reason: '"$text" wraps');
        expect(rect.bottom, lessThanOrEqualTo(clearLine), reason: text);
      }
    });
  }
}
