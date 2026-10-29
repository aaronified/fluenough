// The teach card's swipe chevrons (owner, 2026-10-29): clear on a tap, shown
// by a horizontal drag, and cleared 1 s after the drag ends.
import 'package:fluenough/ui/widgets/teach_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('chevrons show as the card appears and on a swipe only, clearing 1 s after', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: TeachSwipe(
          onNext: () {},
          onBack: () {},
          child: const SizedBox.expand(),
        ),
      ),
    );
    double opacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;

    // The intro: shown as the card first appears, clear 1 s later.
    expect(opacity(), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), 0);

    final drag = await tester.startGesture(const Offset(200, 300));
    await drag.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(opacity(), greaterThan(0));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 900));
    expect(opacity(), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });
}
