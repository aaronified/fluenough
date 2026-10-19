import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';

/// Driving Languages I'm learning (#211, #626) in widget tests: its list is
/// built lazily, so a row is scrolled to before it is found, and a language
/// is chosen in its sheet.

/// The languages of `assets/languages.yaml`: their scripts and families,
/// which the page reads from the asset bundle, a read a widget test does not
/// wait for. Passed to [LanguagePickerPage] where a test needs them at once.
final List<SpokenLanguage> pickerSpokenList = parseSpokenLanguages(
  File('assets/languages.yaml').readAsStringSync(),
);

/// Lets the page's read of `assets/languages.yaml` finish, which takes real
/// time, not the test clock's.
Future<void> settleAssets(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// [code]'s row: keyed `language-` in Learning, `popular-` in Popular and
/// `listed-` under its family.
Finder languageCard(String code) => find.byWidgetPredicate(
  (w) =>
      w.key == ValueKey<String>('language-$code') ||
      w.key == ValueKey<String>('popular-$code') ||
      w.key == ValueKey<String>('listed-$code'),
);

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
  // Centred, clear of the search bar that stays at the top of the list.
  await Scrollable.ensureVisible(finder.first.evaluate().first, alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Opens [code]'s sheet: taps its row, opening the families first when it is
/// in none that is open.
Future<void> openSheet(WidgetTester tester, String code) async {
  await settleAssets(tester);
  if (languageCard(code).evaluate().isEmpty) {
    await openFamilies(tester);
  }
  await scrollToInPicker(tester, languageCard(code));
  // The row's own button: its middle can fall between it and the buttons
  // under it, on a language on the phone.
  await tester.tap(
    find
        .descendant(
          of: languageCard(code).first,
          matching: find.byType(InkWell),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// Opens every family under "All languages": from the top of the list, the
/// next closed one is scrolled to and opened, until none is left.
Future<void> openFamilies(WidgetTester tester) async {
  final closed = find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          ((w.key as ValueKey<String>?)?.value.startsWith('family-') ?? false),
    ),
    matching: find.byIcon(Icons.expand_more),
  );
  for (var i = 0; i < 12; i++) {
    await tester.drag(pickerList().first, const Offset(0, 6000));
    await tester.pumpAndSettle();
    // Down a screen at a time until a closed family is built.
    for (var j = 0; j < 80 && closed.evaluate().isEmpty; j++) {
      await tester.drag(pickerList().first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    if (closed.evaluate().isEmpty) return;
    await Scrollable.ensureVisible(
      closed.first.evaluate().first,
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(closed.first);
    await tester.pumpAndSettle();
  }
}

/// Whether a language sheet is open.
bool sheetIsOpen() =>
    find.byKey(const ValueKey<String>('sheet-scroll')).evaluate().isNotEmpty;

/// Closes the open sheet without answering, as Back does.
Future<void> closeSheet(WidgetTester tester) async {
  Navigator.of(
    tester.element(find.byKey(const ValueKey<String>('sheet-scroll'))),
  ).pop();
  await tester.pumpAndSettle();
}

/// Taps [key] in the open sheet.
Future<void> tapSheet(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Chooses [code] to learn, as a learner does in its sheet: Learn this
/// language, its scripts (untick them all with [script] false), where to
/// start ("Start at the beginning" with [begin], else Find my level), then
/// Next and Done. Chosen already, it is stopped instead, confirming the dialog a
/// language learned asks.
Future<void> pickLanguage(
  WidgetTester tester,
  String code, {
  bool script = true,
  bool begin = false,
}) async {
  await openSheet(tester, code);
  final stop = find.byKey(const ValueKey<String>('sheet-stop'));
  if (stop.evaluate().isNotEmpty) {
    await tester.tap(stop);
    await tester.pumpAndSettle();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm.last);
      await tester.pumpAndSettle();
    }
    return;
  }
  await tapSheet(tester, 'sheet-learn');
  if (!script) {
    final boxes = find.byWidgetPredicate(
      (w) =>
          w is CheckboxListTile &&
          w.value == true &&
          ((w.key as ValueKey<String>?)?.value.startsWith('sheet-script-') ??
              false),
    );
    for (final box in boxes.evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
      await tester.pumpAndSettle();
    }
  }
  await finishSheet(tester, begin: begin);
}

/// Presses Next and Done through the sheet's remaining screens, choosing
/// "Start at the beginning" with [begin].
Future<void> finishSheet(WidgetTester tester, {bool begin = false}) async {
  while (sheetIsOpen()) {
    final start = find.byKey(const ValueKey<String>('sheet-begin-language'));
    if (begin && start.evaluate().isNotEmpty) {
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
    }
    final next = find.byKey(const ValueKey<String>('sheet-next'));
    await tapSheet(
      tester,
      next.evaluate().isNotEmpty ? 'sheet-next' : 'sheet-done',
    );
  }
}

/// Whether [code]'s row is ticked: a language learned or chosen.
bool isPicked(WidgetTester tester, String code) => find
    .descendant(
      of: languageCard(code),
      matching: find.byIcon(Icons.check_circle),
      skipOffstage: false,
    )
    .evaluate()
    .isNotEmpty;
