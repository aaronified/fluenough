import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';

import '../support/harness.dart';

/// Lesson and review cards fit the screen without scrolling (#482): the
/// card is as tall as its content, and the body scrolls only when the
/// header, card and Continue truly do not fit.
void main() {
  /// The most any vertical scroll view under the drill can still scroll.
  double scrollable(WidgetTester tester) {
    var most = 0.0;
    for (final element
        in find
            .descendant(
              of: find.byType(DrillFrame),
              matching: find.byType(Scrollable),
            )
            .evaluate()) {
      final position =
          ((element as StatefulElement).state as ScrollableState).position;
      if (position.axis == Axis.vertical && position.maxScrollExtent > most) {
        most = position.maxScrollExtent;
      }
    }
    return most;
  }

  testWidgets('the card is as tall as its content, not stretched', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      DrillFrame(
        skill: Skill.recognition,
        deckName: 'Deck',
        position: 1,
        total: 3,
        onClose: () {},
        card: const <Widget>[Text('what')],
      ),
    );
    expect(tester.getSize(find.byType(DrillCard)).height, lessThan(200));
  });

  // The screens whose content is short enough to fit a phone, in the test
  // font, whose letters are all full squares. The longer ones (a grammar
  // table, a passage, a long note) truly do not fit and scroll.
  const short = <String>[
    'drill-recognition',
    'drill-choose-meaning',
    'drill-match',
    'drill-production-accent',
    'drill-production-script',
    'drill-listening',
    'drill-rtl',
  ];

  testWidgets('a drill whose content fits at 1x text does not scroll', (
    tester,
  ) async {
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    final scrolling = <String>[];
    for (final entry in allGalleryEntries) {
      if (!short.contains(entry.id)) continue;
      await pumpScreen(
        tester,
        GalleryPreview(key: UniqueKey(), entry: entry),
        state: app,
      );
      expect(find.byType(DrillFrame), findsOneWidget, reason: entry.id);
      if (scrollable(tester) > 0) scrolling.add(entry.id);
    }
    expect(scrolling, isEmpty);
  });

  testWidgets('a lesson card at 2x text scrolls, clips nothing, and keeps '
      'Continue in view', (tester) async {
    usePhone(tester, textScale: 2.0);
    final app = AppState.test();
    await app.load();
    final entry = allGalleryEntries.firstWhere((e) => e.id == 'drill-lesson');
    await pumpScreen(
      tester,
      GalleryPreview(key: UniqueKey(), entry: entry),
      state: app,
    );
    expect(tester.takeException(), isNull);
    expect(scrollable(tester), greaterThan(0));
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
  });
}
