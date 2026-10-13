import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/ui/theme.dart';

import '../support/harness.dart';
import '../support/nav_bar_walk.dart';

/// The Decks screen's floating buttons, Add deck and Where I am, clear
/// both the three-button bar and the app's own navigation bar (#501; owner,
/// 2026-10-13, on #504: "Add the tests in this PR"). At 1x, and with the
/// phone at 2x, which the app draws at its 1.4x cap (#505).
void main() {
  for (final scale in <double>[1.0, 2.0]) {
    testWidgets('phone text at ${scale}x: Add deck and Where I am sit above '
        'both bars', (tester) async {
      usePhone(tester, navBar: true, textScale: scale);
      await pumpApp(tester);
      final l10n = l10nOf(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(l10n.navDecks),
        ),
      );
      await tester.pumpAndSettle();
      // Overflows at large text are the accessibility tests' to catch.
      tester.takeException();
      final decks = find.byType(DecksPage).hitTestable();
      expect(decks, findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(decks)).scale(1),
        closeTo(math.min(scale, AppSizes.maxTextScale), 0.001),
      );

      // The bar's own box reaches down behind the system bar; its top is
      // what the buttons must stay above.
      final bar = tester.getRect(find.byType(NavigationBar));
      final fabs = find.descendant(
        of: find.byType(DecksPage),
        matching: find.byType(FloatingActionButton),
      );
      final heroTags = <Object?>[
        for (final fab in tester.widgetList<FloatingActionButton>(fabs))
          fab.heroTag,
      ];
      expect(heroTags, containsAll(<String>['where-i-am', 'add-deck']));
      for (final element in fabs.hitTestable().evaluate()) {
        final fab = element.widget as FloatingActionButton;
        final rect = tester.getRect(
          find.byElementPredicate((e) => e == element),
        );
        expect(
          underBar(rect),
          isFalse,
          reason: '${fab.heroTag} under the three-button bar',
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(bar.top + 0.5),
          reason: '${fab.heroTag} over the navigation bar',
        );
      }
      expect(fabs.hitTestable(), findsNWidgets(2));
    });
  }
}
