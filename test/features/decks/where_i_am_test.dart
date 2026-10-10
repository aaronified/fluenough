import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/ui/theme.dart';

import '../../support/harness.dart';

/// "Where I am" stands apart from the path's cards, and the path leaves
/// room for the floating buttons (#466).

Future<AppState> _learner() async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app, upTo: PathFixtures.familyDeck);
}

Finder _fab(String heroTag) => find.byWidgetPredicate(
  (w) => w is FloatingActionButton && w.heroTag == heroTag,
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in <(String, ThemeData)>[
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
    ('pure black', AppTheme.dark(pureBlack: true)),
    ('light, high contrast', AppTheme.light(highContrast: true)),
    ('dark, high contrast', AppTheme.dark(highContrast: true)),
  ]) {
    test('in $name, its colour is none of the path cards\' and reads', () {
      final s = theme.colorScheme;
      // Done, up next, ahead, the current level, and the page behind.
      for (final card in <Color>[
        s.secondaryContainer,
        s.primary,
        s.primaryContainer,
        s.surfaceContainerHigh,
        s.surface,
      ]) {
        expect(s.tertiary, isNot(card));
      }
      expect(_contrast(s.tertiary, s.onTertiary), greaterThanOrEqualTo(4.5));
      expect(_contrast(s.tertiary, s.surface), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('"Where I am" is drawn in tertiary, apart from Add deck', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const DecksPage(), state: await _learner());
    final scheme = Theme.of(tester.element(_fab('where-i-am'))).colorScheme;
    final where = tester.widget<FloatingActionButton>(_fab('where-i-am'));
    expect(where.backgroundColor, scheme.tertiary);
    expect(where.foregroundColor, scheme.onTertiary);
    expect(
      tester.widget<FloatingActionButton>(_fab('add-deck')).backgroundColor,
      isNot(scheme.tertiary),
    );
  });

  testWidgets('scrolled to its end, the path\'s content clears both '
      'floating buttons', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DecksPage(planOf: PathFixtures.planOf),
      state: await _learner(),
    );
    final scroll = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    final position = tester.state<ScrollableState>(scroll.first).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final column = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Column),
    );
    final contentBottom = tester.getRect(column.first).bottom;
    for (final tag in <String>['where-i-am', 'add-deck']) {
      expect(
        contentBottom,
        lessThanOrEqualTo(tester.getRect(_fab(tag)).top),
        reason: tag,
      );
    }
  });
}
