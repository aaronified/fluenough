import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import 'private_screens_test.dart' as p;
import 'support/harness.dart';
import 'support/nav_bar_walk.dart';

void main() {
  testWidgets('diag', (tester) async {
    usePhone(tester, textScale: 1.4, navBar: true);
    final world = await p.worldForDiag();
    await pumpScreen(tester, const YourDecksPage(), state: world);
    for (final e in find.byType(Scrollable).evaluate()) {
      final st = (e as StatefulElement).state as ScrollableState;
      // ignore: avoid_print
      print(
        'SCROLLABLE ${st.position.axis} max=${st.position.maxScrollExtent} pix=${st.position.pixels}',
      );
    }
    final found = await underBarAtEnd(tester, within: find.byType(MaterialApp));
    // ignore: avoid_print
    print('FOUND $found');
    for (final e in find.byType(RichText).evaluate()) {
      final b = e.renderObject! as RenderParagraph;
      final r = b.localToGlobal(Offset.zero) & b.size;
      if (r.bottom > 700) {
        // ignore: avoid_print
        print('TEXT ${b.text.toPlainText()} $r');
      }
    }
  });
}
