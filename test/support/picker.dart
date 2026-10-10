import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/features/placement/language_picker_page.dart';

/// Driving the language picker (#211) in widget tests: its list is built
/// lazily, so a card is scrolled to before it is found.

/// [code]'s card.
Finder languageCard(String code) =>
    find.byKey(ValueKey<String>('language-$code'));

/// The picker's list, which scrolls.
Finder pickerList() => find.descendant(
  of: find.byType(LanguagePickerPage),
  matching: find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
);

/// Scrolls the picker's list until [finder] is built and on screen.
Future<void> scrollToInPicker(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Back to the top first: the list may be scrolled past it.
    await tester.drag(pickerList().first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: pickerList().first,
      );
    }
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

/// Ticks or un-ticks [code]: taps its card's checkbox.
Future<void> pickLanguage(WidgetTester tester, String code) async {
  final box = find.descendant(
    of: languageCard(code),
    matching: find.byType(Checkbox),
  );
  await scrollToInPicker(tester, languageCard(code));
  await scrollToInPicker(tester, box);
  await tester.tap(box);
  await tester.pumpAndSettle();
}

/// Turns [code]'s "Learn the script" switch, in its opened card.
Future<void> flipScript(WidgetTester tester, String code) async {
  final toggle = find.descendant(
    of: languageCard(code),
    matching: find.byType(Switch),
  );
  await scrollToInPicker(tester, toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Whether [code]'s card is ticked.
bool isPicked(WidgetTester tester, String code) => tester
    .widget<Checkbox>(
      find.descendant(
        of: languageCard(code),
        matching: find.byType(Checkbox),
        skipOffstage: false,
      ),
    )
    .value!;
