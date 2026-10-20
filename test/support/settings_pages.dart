import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/widgets/snack.dart';

/// Scrolls the page's list until [finder] is built and on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Scrolls the page's list from top to bottom, failing on any exception on
/// the way, such as an overflow in a row that starts off screen.
Future<void> scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 40; i++) {
    expect(tester.takeException(), isNull);
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) return;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

/// Taps a slider at [fraction] of its width, from the start edge.
Future<void> tapSlider(WidgetTester tester, Finder slider, double fraction) {
  final rect = tester.getRect(slider);
  final x = rect.left + (rect.width - 1) * fraction.clamp(0.0, 1.0);
  return tester.tapAt(
    Offset(x < rect.left + 1 ? rect.left + 1 : x, rect.center.dy),
  );
}

/// Hides the toast, so that it covers nothing the next tap aims at.
Future<void> clearSnackBars(WidgetTester tester) async {
  hideAppSnackBar();
  await tester.pumpAndSettle();
}
