import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/ui/theme.dart';

import 'harness.dart';

/// The bottom of the phone's usable screen: above the navigation bar.
const double clearLine = 844 - navBarHeight;

/// Whether [rect] reaches into the strip the three-button bar covers.
bool underBar(Rect rect) => rect.bottom > clearLine + 0.5 && rect.top < 844;

/// Scrolls every vertical list on the screen to its end, then names each
/// text and button that sits under the three-button bar.
Future<List<String>> underBarAtEnd(WidgetTester tester) async {
  final scrollables = find.descendant(
    of: find.byType(GalleryPreview),
    matching: find.byType(Scrollable),
  );
  for (final element in scrollables.evaluate().toList()) {
    if (!element.mounted) continue;
    final scrollable = (element as StatefulElement).state as ScrollableState;
    final position = scrollable.position;
    if (position.axis != Axis.vertical) continue;
    // A lazy list learns its full length only as it builds its end, so
    // jump until the end stops moving.
    for (var i = 0; i < 20; i++) {
      final end = position.maxScrollExtent;
      position.jumpTo(end);
      await tester.pumpAndSettle();
      if (!element.mounted || position.maxScrollExtent == end) break;
    }
  }
  final found = <String>[];
  final texts = find.descendant(
    of: find.byType(GalleryPreview),
    matching: find.byType(RichText),
  );
  final tabLabels = find
      .descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(RichText),
      )
      .evaluate()
      .toSet();
  for (final element in texts.evaluate()) {
    // In the test font every letter is a full square, so "Progress" and
    // "Settings" wrap where Roboto keeps them on one line: the tab labels
    // are checked in Roboto by nav_bar_labels_test.dart instead.
    if (tabLabels.contains(element)) continue;
    final box = element.renderObject! as RenderParagraph;
    if (!box.hasSize || !box.attached) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (underBar(rect)) found.add('text "${box.text.toPlainText()}"');
  }
  final buttons = find.descendant(
    of: find.byType(GalleryPreview),
    matching: find.byWidgetPredicate(
      (w) =>
          w is ButtonStyleButton ||
          w is IconButton ||
          w is FloatingActionButton ||
          w is ListTile,
    ),
  );
  for (final element in buttons.hitTestable().evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == element));
    if (underBar(rect)) found.add('${element.widget.runtimeType}');
  }
  return found;
}

/// Walks every gallery screen on a phone with the three-button bar, its
/// text set to [scale], and expects none to leave text or a button under
/// the bar once scrolled to its end (#501). The screens draw through the
/// app's own cap (`capTextScale` in app.dart), so a phone at 2x shows them at
/// [AppSizes.maxTextScale], and the walk checks that it does (#505).
///
/// Each scale runs in a test file of its own: run one after the other in
/// one file, the second walk's language list never settles.
Future<void> expectNothingUnderBar(WidgetTester tester, double scale) async {
  usePhone(tester, navBar: true, textScale: scale);
  final app = AppState.test();
  await app.load();
  final under = <String, List<String>>{};
  for (final entry in <GalleryEntry>[fullAppEntry, ...allGalleryEntries]) {
    await pumpScreen(
      tester,
      GalleryPreview(key: UniqueKey(), entry: entry),
      state: app,
    );
    final drawn = MediaQuery.textScalerOf(
      tester.element(find.byType(GalleryPreview)),
    ).scale(1);
    expect(
      drawn,
      closeTo(math.min(scale, AppSizes.maxTextScale), 0.001),
      reason: entry.id,
    );
    // Overflows at large text are the accessibility tests' to catch.
    tester.takeException();
    final found = await underBarAtEnd(tester);
    if (found.isNotEmpty) under[entry.id] = found;
  }
  expect(under, isEmpty);
}
