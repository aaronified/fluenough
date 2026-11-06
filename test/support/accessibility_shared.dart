// Helpers and fixtures that more than one of the files split out of
// accessibility_test.dart use, moved here unchanged.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';

import 'harness.dart';
import 'nav_bar_walk.dart';
import 'paced_learner.dart';

/// Flutter's accessibility guidelines (#26): tap targets big enough for a
/// drill used fast, every tap target labelled, and text at WCAG AA contrast.
Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Taps [finder], scrolling the screen's list to it first.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Scrolls the screen's list, where a tap target is cut by the list's top
/// edge, until that target is whole at the top. A screen that opens part
/// way down a list, as the path opens at the unit up next, cuts the row
/// above wherever it stops; the tap-target guidelines skip a node cut by
/// the screen's edge for that reason, but not one cut by a list's edge
/// below the app bar. Every target on the screen is still checked.
Future<void> noTargetCutAtTop(WidgetTester tester) async {
  final list = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  if (list.evaluate().isEmpty) return;
  final top = tester.getTopLeft(list.first).dy;
  final targets = find.descendant(
    of: list.first,
    matching: find.byWidgetPredicate(
      (w) => w is InkWell || (w is Semantics && w.properties.button == true),
    ),
  );
  for (final element in targets.evaluate()) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.top < top - 0.5 && rect.bottom > top + 0.5) {
      await Scrollable.ensureVisible(element);
      await tester.pumpAndSettle();
      return;
    }
  }
}

/// Draws a screen in [mode]; returns nothing, leaving it on screen.
typedef DrawScreen = Future<void> Function(WidgetTester tester, ThemeMode mode);

/// One screen at 1.4x text on a phone with the three-button bar, in light
/// and in dark: nothing overflows, the guidelines hold, and once scrolled
/// to its end nothing is left under the bar (#489, #501). [onTop] is what
/// is checked for the bar when a sheet covers the page behind it.
void screen(String name, DrawScreen draw, {Finder? onTop}) {
  testWidgets('$name, at 1.4x text, light and dark', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      usePhone(tester, textScale: 1.4, navBar: true);
      await draw(tester, mode);
      expect(tester.takeException(), isNull, reason: mode.name);
      await noTargetCutAtTop(tester);
      await meetsEveryGuideline(tester);
      expect(
        await underBarAtEnd(tester, within: onTop ?? find.byType(MaterialApp)),
        isEmpty,
        reason: '${mode.name}: under the three-button bar',
      );
    }
    semantics.dispose();
  });
}

/// The gallery's screen [id], on the state it is drawn on there.
DrawScreen gallery(String id) => (tester, mode) async {
  final app = AppState.test();
  await app.load();
  final entry = allGalleryEntries.firstWhere((e) => e.id == id);
  final state = entry.state?.call(app) ?? GalleryFixtures.state(app);
  await pumpScreen(
    tester,
    Builder(builder: entry.builder),
    state: state,
    themeMode: mode,
  );
};

/// [page] on a fresh app, or on the state [state] makes.
DrawScreen page(Widget page, {Future<AppState> Function()? state}) =>
    (tester, mode) async {
      await pumpScreen(
        tester,
        page,
        state: state == null ? null : await state(),
        themeMode: mode,
      );
    };

/// The whole app on [tab], for a learner whose pace has been fitted.
DrawScreen tab(ShellTab tab) => (tester, mode) async {
  final state = await pacedLearner(
    Paced.fewer,
    also: <Paced>{Paced.more, Paced.same},
  );
  state.settings.themeMode = mode;
  await pumpApp(tester, state: state);
  state.shellTab.value = tab;
  await tester.pumpAndSettle();
};

final List<SpokenLanguage> choices = parseSpokenLanguages(
  File(spokenLanguagesAsset).readAsStringSync(),
);
