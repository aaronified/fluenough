import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/lesson_card.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/ui/widgets/language_glyph.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';

import '../support/harness.dart';

/// The language bar at the top of Today, Decks and Progress (#528,
/// its approved mockup, in git history), on the design's Aro, who learns Hindi
/// and Spanish, with twelve days of Spanish (and Marathi, which Aro does
/// not learn) reviews.

Future<AppState> aro({String? choice}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: FeatureRegistry.all(),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      languageChoice: choice,
    ),
  );
}

/// A learner of [languages], in that order, with no reviews.
AppState learner(List<String> languages, {String? choice}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    learningChosen: true,
    languageChoice: choice,
  ),
);

/// Eight languages, as the mockup's edge mask draws them.
const List<String> eight = <String>[
  'hi',
  'bn',
  'te',
  'mr',
  'gu',
  'kn',
  'as',
  'es',
];

String nameOf(AppState state, String code) =>
    state.languages.singleWhere((l) => l.code == code).name;

/// The bar on screen: the tab's, where the shell holds all three.
Finder bar() => find.byType(LanguageBar).hitTestable();

Finder inBar(Finder matching) =>
    find.descendant(of: find.byType(LanguageBar), matching: matching);

/// The shown language's chip on the bar on screen.
Finder chip() => find
    .descendant(of: bar(), matching: find.byType(LanguageBarChip))
    .hitTestable();

/// The languages on the bar on screen, for a drag or a tap.
Finder zone() => find
    .descendant(
      of: find.byType(LanguageBar),
      matching: find.byType(GestureDetector),
    )
    .hitTestable()
    .first;

/// [glyph] in the bar's row on screen, not in the label under it.
Finder glyphOnBar(String glyph) => find
    .descendant(
      of: find.descendant(
        of: bar(),
        matching: find.byType(SingleChildScrollView),
      ),
      matching: find.text(glyph),
    )
    .hitTestable();

Finder allButton() =>
    find.descendant(of: bar(), matching: find.text('All')).hitTestable();

Finder statTile(String value, String label) => find.byWidgetPredicate(
  (w) => w is StatTile && w.value == value && w.label == label,
);

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(zone());
  await tester.pumpAndSettle();
}

Future<void> swipe(WidgetTester tester, double dx) async {
  await tester.drag(zone(), Offset(dx, 0));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('is on Today, Decks and Progress, and not on Settings, in '
      'place of the language menu', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro());
    Finder barIn(Type page) => find.descendant(
      of: find.byType(page, skipOffstage: false),
      matching: find.byType(LanguageBar, skipOffstage: false),
    );
    expect(barIn(TodayPage), findsOneWidget);
    expect(barIn(DecksPage), findsOneWidget);
    expect(barIn(StatsPage), findsOneWidget);
    expect(barIn(SettingsPage), findsNothing);
    for (final tab in ShellTab.values) {
      state.shellTab.value = tab;
      await tester.pumpAndSettle();
      expect(
        bar(),
        tab == ShellTab.settings ? findsNothing : findsOneWidget,
        reason: tab.name,
      );
      if (tab != ShellTab.settings) {
        expect(tester.getSize(bar()).height, 56, reason: tab.name);
      }
    }
  });

  testWidgets('shows the language as its chip, with no arrow, and the '
      'others as their bare glyphs, faded, in their places', (tester) async {
    usePhone(tester);
    final state = learner(const <String>['hi', 'bn', 'te', 'mr'], choice: 'bn');
    await pumpApp(tester, state: state);
    expect(chip(), findsOneWidget);
    expect(
      find.descendant(of: chip(), matching: find.text(nameOf(state, 'bn'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar(), matching: find.byIcon(Icons.arrow_drop_down)),
      findsNothing,
    );
    // The others: their glyphs alone, faded to 64%, Hindi before the chip
    // and Telugu and Marathi after it.
    final chipRect = tester.getRect(chip());
    for (final (code, glyph, before) in <(String, String, bool)>[
      ('hi', state.languages.singleWhere((l) => l.code == 'hi').icon!, true),
      ('te', state.languages.singleWhere((l) => l.code == 'te').icon!, false),
      ('mr', state.languages.singleWhere((l) => l.code == 'mr').icon!, false),
    ]) {
      final glyphText = glyphOnBar(glyph);
      expect(glyphText, findsOneWidget, reason: code);
      final text = tester.widget<Text>(glyphText);
      expect(text.style!.color!.a, closeTo(0.64, 0.01), reason: code);
      expect(text.textScaler, TextScaler.noScaling, reason: code);
      final rect = tester.getRect(glyphText);
      expect(
        before ? rect.right <= chipRect.left : rect.left >= chipRect.right,
        isTrue,
        reason: code,
      );
      expect(find.text(nameOf(state, code)).hitTestable(), findsNothing);
    }
  });

  testWidgets('a sideways swipe on the bar shows the next or previous '
      'language, and does not wrap round', (tester) async {
    usePhone(tester);
    final state = learner(const <String>['hi', 'bn', 'te'], choice: 'hi');
    await pumpApp(tester, state: state);

    // Left: the next language.
    await swipe(tester, -200);
    expect(state.shownLanguage, 'bn');
    await swipe(tester, -200);
    expect(state.shownLanguage, 'te');
    // At the last, it gives and springs back.
    await swipe(tester, -200);
    expect(state.shownLanguage, 'te');
    expect(tester.takeException(), isNull);

    // Right: the previous one.
    await swipe(tester, 200);
    expect(state.shownLanguage, 'bn');

    // A short, slow drag changes nothing.
    await tester.timedDrag(
      zone(),
      const Offset(-30, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(state.shownLanguage, 'bn');

    // Today follows it: Bengali's lesson alone.
    final lessons = tester.widget<LessonCard>(find.byType(LessonCard)).lessons;
    expect(lessons.map((l) => l.language.code), <String>['bn']);
  });

  testWidgets('a hard fling goes past several languages at once, and stops '
      'at the end (owner, 2026-10-19)', (tester) async {
    usePhone(tester);
    final state = learner(eight, choice: 'hi');
    await pumpApp(tester, state: state);
    final codes = <String>[for (final l in state.languageChoices) l.code];
    final start = codes.indexOf('hi');

    await tester.fling(zone(), const Offset(-200, 0), 4000);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final moved = codes.indexOf(state.shownLanguage!) - start;
    expect(moved, greaterThan(1));

    // Past the end it stops at the last language.
    await tester.fling(zone(), const Offset(-200, 0), 20000);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(state.shownLanguage, codes.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('while dragging, the next glyph rises and a label names it; '
      'after, it fades', (tester) async {
    usePhone(tester);
    final state = learner(const <String>['hi', 'bn'], choice: 'hi');
    await pumpApp(tester, state: state);
    final bengali = nameOf(state, 'bn');
    final glyph = state.languages.singleWhere((l) => l.code == 'bn').icon!;
    final gesture = await tester.startGesture(tester.getCenter(zone()));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    final label = find.byKey(const ValueKey<String>('language-bar-label'));
    expect(label, findsOneWidget);
    expect(
      find.descendant(of: label, matching: find.text(bengali)),
      findsOneWidget,
    );
    final rising = tester.widget<Text>(glyphOnBar(glyph));
    expect(rising.style!.color!.a, 1);
    await gesture.moveBy(const Offset(-100, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.shownLanguage, 'bn');
    // The label stays a second, then fades out.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(label, findsNothing);
  });

  testWidgets('the selection follows the finger toward the next language, '
      'and goes back when the swipe is let go short (owner, 2026-10-17)', (
    tester,
  ) async {
    usePhone(tester);
    final state = learner(const <String>['hi', 'bn'], choice: 'hi');
    await pumpApp(tester, state: state);
    final selection = find.byKey(
      const ValueKey<String>('language-bar-selection'),
    );
    final glyph = state.languages.singleWhere((l) => l.code == 'bn').icon!;
    final start = tester.getRect(selection);
    final gesture = await tester.startGesture(tester.getCenter(zone()));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    final early = tester.getRect(selection);
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    final later = tester.getRect(selection);
    final target = tester.getRect(glyphOnBar(glyph));
    // It moves with every step of the finger, toward the next glyph.
    expect(early.center.dx, greaterThan(start.center.dx));
    expect(later.center.dx, greaterThan(early.center.dx));
    expect(later.center.dx, lessThan(target.right));
    // Let go short of a third of the bar: it goes back, nothing changes.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.shownLanguage, 'hi');
    expect(tester.getRect(selection).center.dx, closeTo(start.center.dx, 1));
  });

  // The swipe works the same wherever it starts on the bar (owner,
  // 2026-10-17: "It should be consistent").
  for (final where in <String>['glyph', 'chip', 'between', 'edge', 'low']) {
    testWidgets('a swipe from the bar\'s $where shows the next language', (
      tester,
    ) async {
      usePhone(tester);
      final state = learner(const <String>['hi', 'bn', 'te'], choice: 'hi');
      await pumpApp(tester, state: state);
      final bar = tester.getRect(find.byType(LanguageBar).first);
      final glyph = state.languages.singleWhere((l) => l.code == 'bn').icon!;
      final at = switch (where) {
        'glyph' => tester.getCenter(glyphOnBar(glyph)),
        'chip' => tester.getCenter(find.byType(LanguageBarChip).first),
        'between' => Offset(bar.width * 0.6, bar.center.dy),
        'edge' => Offset(bar.left + 2, bar.center.dy),
        _ => Offset(bar.width * 0.6, bar.bottom - 2),
      };
      final gesture = await tester.startGesture(at);
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(state.shownLanguage, 'bn');
    });
  }

  testWidgets('a glyph is a rounded square on the chip and in the label, '
      'never stretched (owner, 2026-10-17)', (tester) async {
    usePhone(tester);
    final state = learner(const <String>['hi', 'bn'], choice: 'hi');
    await pumpApp(tester, state: state);
    final onBar = find.descendant(
      of: find.byType(LanguageBar),
      matching: find.byType(LanguageGlyphTile),
    );
    expect(tester.getSize(onBar.first).height, 24);
    final gesture = await tester.startGesture(tester.getCenter(zone()));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    final label = find.byKey(const ValueKey<String>('language-bar-label'));
    final tile = find.descendant(
      of: label,
      matching: find.byType(LanguageGlyphTile),
    );
    expect(tester.getSize(tile).height, 24);
    // The label is one line high, not the screen's height.
    expect(tester.getSize(label).height, lessThan(48));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap opens the menu of every language with its chip, the '
      'shown one ticked, no All', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro(choice: 'hi'));
    final hindi = nameOf(state, 'hi');
    final spanish = nameOf(state, 'es');
    await openMenu(tester);
    final items = find.byType(MenuItemButton);
    expect(items, findsNWidgets(2));
    for (final name in <String>[hindi, spanish]) {
      expect(
        find.descendant(
          of: items,
          matching: find.byWidgetPredicate(
            (w) => w is LanguageBarChip && w.language.name == name,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: items, matching: find.text('All')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, hindi),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, spanish),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    await tester.tap(find.descendant(of: items, matching: find.text(spanish)));
    await tester.pumpAndSettle();
    expect(state.shownLanguage, 'es');
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('All is on Progress only: it counts every language there, '
      'and Today and Decks keep the one language', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro(choice: 'es'));
    final l10n = l10nOf(tester);
    for (final tab in <ShellTab>[ShellTab.today, ShellTab.decks]) {
      state.shellTab.value = tab;
      await tester.pumpAndSettle();
      expect(allButton(), findsNothing, reason: tab.name);
    }
    state.shellTab.value = ShellTab.progress;
    await tester.pumpAndSettle();
    // Spanish's 22 reviews.
    expect(statTile('22', l10n.statsReviews), findsOneWidget);
    await tester.tap(allButton());
    await tester.pumpAndSettle();
    expect(state.settings.progressAll, isTrue);
    // Every review, Marathi's too.
    expect(statTile('44', l10n.statsReviews), findsOneWidget);
    // The chip keeps its place, its outline only.
    final chipWidget = tester.widget<LanguageBarChip>(chip());
    expect(chipWidget.selected, isFalse);
    expect(chipWidget.language.code, 'es');

    // Today and Decks still show Spanish alone.
    state.shellTab.value = ShellTab.today;
    await tester.pumpAndSettle();
    final lessons = tester.widget<LessonCard>(find.byType(LessonCard)).lessons;
    expect(lessons.map((l) => l.language.code), <String>['es']);
    expect(tester.widget<LanguageBarChip>(chip()).selected, isTrue);
    state.shellTab.value = ShellTab.decks;
    await tester.pumpAndSettle();
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard)).view.language.code,
      'es',
    );

    // On Progress, a swipe or the menu turns All off.
    state.shellTab.value = ShellTab.progress;
    await tester.pumpAndSettle();
    final codes = <String>[for (final l in state.languageChoices) l.code];
    await swipe(tester, codes.indexOf('hi') < codes.indexOf('es') ? 200 : -200);
    expect(state.shownLanguage, 'hi');
    expect(state.settings.progressAll, isFalse);
    await tester.tap(allButton());
    await tester.pumpAndSettle();
    expect(state.settings.progressAll, isTrue);
    await openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text(nameOf(state, 'es')),
      ),
    );
    await tester.pumpAndSettle();
    expect(state.settings.progressAll, isFalse);
    expect(statTile('22', l10n.statsReviews), findsOneWidget);
  });

  testWidgets('with one language, Progress has no All', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: learner(const <String>['te']));
    state.shellTab.value = ShellTab.progress;
    await tester.pumpAndSettle();
    expect(allButton(), findsNothing);
    expect(chip(), findsOneWidget);
  });

  testWidgets('nothing on the bar moves between the three tabs', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(
      tester,
      state: learner(const <String>['hi', 'bn', 'te', 'mr'], choice: 'bn'),
    );
    final bug = find
        .descendant(of: bar(), matching: find.byIcon(Icons.bug_report_outlined))
        .hitTestable();
    final slot = find.descendant(
      of: bar(),
      matching: find.byKey(const ValueKey<String>('language-bar-all-slot')),
    );
    final glyph = state.languages.singleWhere((l) => l.code == 'te').icon!;
    final rects = <String, List<Rect>>{};
    for (final tab in <ShellTab>[
      ShellTab.today,
      ShellTab.decks,
      ShellTab.progress,
    ]) {
      state.shellTab.value = tab;
      await tester.pumpAndSettle();
      rects[tab.name] = <Rect>[
        tester.getRect(chip()),
        tester.getRect(glyphOnBar(glyph)),
        tester.getRect(slot),
        tester.getRect(bug),
      ];
    }
    expect(rects['decks'], rects['today']);
    expect(rects['progress'], rects['today']);
    // All turned on moves nothing either.
    await tester.tap(allButton());
    await tester.pumpAndSettle();
    expect(<Rect>[
      tester.getRect(chip()),
      tester.getRect(glyphOnBar(glyph)),
      tester.getRect(slot),
      tester.getRect(bug),
    ], rects['today']);
  });

  group('the edge mask', () {
    Finder mask() => find.descendant(
      of: bar(),
      matching: find.byKey(const ValueKey<String>('language-bar-mask')),
    );

    void narrow(WidgetTester tester) {
      usePhone(tester);
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    }

    testWidgets('is not drawn where the row fits', (tester) async {
      narrow(tester);
      await pumpApp(
        tester,
        state: learner(const <String>['hi', 'bn'], choice: 'bn'),
      );
      expect(mask(), findsNothing);
    });

    testWidgets('fades only an end with more beyond it, and keeps the chip '
        'clear of the fade', (tester) async {
      narrow(tester);
      final state = learner(eight, choice: 'bn');
      await pumpApp(tester, state: state);
      expect(mask(), findsOneWidget);
      ScrollPosition row() => tester
          .widget<SingleChildScrollView>(
            find.descendant(
              of: bar(),
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .controller!
          .position;
      expect(row().maxScrollExtent, greaterThan(0));
      final zoneRect = tester.getRect(mask());
      final chipRect = tester.getRect(chip());
      expect(chipRect.left, greaterThanOrEqualTo(zoneRect.left));
      expect(chipRect.right, lessThanOrEqualTo(zoneRect.right));
      // Bengali is second: the row is at its start, so only the end fades,
      // and the chip is clear of it.
      expect(row().pixels, 0);
      expect(
        chipRect.right,
        lessThanOrEqualTo(zoneRect.right - LanguageBar.fade),
      );

      // The last language: the row scrolls to its end, the chip in view.
      state.showLanguage('es');
      await tester.pumpAndSettle();
      expect(row().pixels, row().maxScrollExtent);
      expect(mask(), findsOneWidget);
      final last = tester.getRect(chip());
      expect(last.right, lessThanOrEqualTo(zoneRect.right));
      expect(last.left, greaterThanOrEqualTo(zoneRect.left + LanguageBar.fade));

      // One between: both ends fade, the chip centred, clear of both.
      state.showLanguage('gu');
      await tester.pumpAndSettle();
      expect(row().pixels, greaterThan(0));
      expect(row().pixels, lessThan(row().maxScrollExtent));
      final middle = tester.getRect(chip());
      expect(
        middle.left,
        greaterThanOrEqualTo(zoneRect.left + LanguageBar.fade),
      );
      expect(
        middle.right,
        lessThanOrEqualTo(zoneRect.right - LanguageBar.fade),
      );
    });
  });

  group('TalkBack', () {
    testWidgets('the bar is one button, with the swipe as two actions', (
      tester,
    ) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpApp(
        tester,
        state: learner(const <String>['hi', 'bn', 'te', 'mr'], choice: 'bn'),
      );
      final l10n = l10nOf(tester);
      final label = l10n.languageBarLabel(nameOf(state, 'bn'), 2, 4);
      expect(label, 'Language shown: Bengali, 2 of 4 languages');
      final next = CustomSemanticsAction(
        label: l10n.languageBarNext(nameOf(state, 'te')),
      );
      final previous = CustomSemanticsAction(
        label: l10n.languageBarPrevious(nameOf(state, 'hi')),
      );
      final node = find.bySemanticsLabel(label);
      expect(node, findsOneWidget);
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          onTapHint: l10n.languageBarHint,
          customActions: <CustomSemanticsAction>[next, previous],
        ),
      );
      // The glyphs are not read one by one.
      for (final code in <String>['hi', 'te', 'mr']) {
        final glyph = state.languages.singleWhere((l) => l.code == code).icon!;
        expect(find.bySemanticsLabel(glyph), findsNothing);
      }

      final barNode = tester.getSemantics(node);
      barNode.owner!.performAction(
        barNode.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(next),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(state.shownLanguage, 'te');
      semantics.dispose();
    });

    testWidgets('on the first language only Next is offered', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpApp(
        tester,
        state: learner(const <String>['hi', 'bn'], choice: 'hi'),
      );
      final l10n = l10nOf(tester);
      final label = l10n.languageBarLabel(nameOf(state, 'hi'), 1, 2);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          onTapHint: l10n.languageBarHint,
          customActions: <CustomSemanticsAction>[
            CustomSemanticsAction(
              label: l10n.languageBarNext(nameOf(state, 'bn')),
            ),
          ],
        ),
      );
      semantics.dispose();
    });

    testWidgets('Progress\'s All is a toggle button', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpApp(tester, state: await aro(choice: 'es'));
      state.shellTab.value = ShellTab.progress;
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      final all = find.bySemanticsLabel(l10n.languageBarAllLabel);
      expect(
        tester.getSemantics(all),
        matchesSemantics(
          label: l10n.languageBarAllLabel,
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
          onTapHint: l10n.languageBarAllHint,
        ),
      );
      semantics.dispose();
    });
  });

  testWidgets('a deck\'s, a unit\'s and Inspect\'s page belong to one deck, '
      'so none has a language switcher (#526)', (tester) async {
    usePhone(tester);
    await pumpApp(tester, state: await aro());
    final context = tester.element(find.byType(TodayPage));
    for (final (open, page) in <(Future<void> Function(), Type)>[
      (() => AppNavigator.openDeck(context, 'hi-en-market'), DeckDetailPage),
      (() => AppNavigator.openUnit(context, 'hi-en-market'), UnitPage),
      (() => AppNavigator.openInspect(context, 'hi-en-market'), InspectPage),
    ]) {
      unawaited(open());
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(page),
          matching: find.byType(LanguageBar),
        ),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  group('accessibility', () {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final tab in <ShellTab>[
        ShellTab.today,
        ShellTab.decks,
        ShellTab.progress,
      ]) {
        testWidgets('the ${tab.name} tab, ${themeMode.name}', (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          final state = await aro(choice: 'es');
          state.settings.themeMode = themeMode;
          await pumpApp(tester, state: state);
          state.shellTab.value = tab;
          await tester.pumpAndSettle();
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }

      testWidgets('the open menu, ${themeMode.name}', (tester) async {
        usePhone(tester);
        final semantics = tester.ensureSemantics();
        final state = await aro(choice: 'es');
        state.settings.themeMode = themeMode;
        await pumpApp(tester, state: state);
        await openMenu(tester);
        expect(find.byType(MenuItemButton), findsNWidgets(2));
        await meetsEveryGuideline(tester);
        semantics.dispose();
      });
    }

    for (final dark in <bool>[false, true]) {
      for (final tab in <ShellTab>[
        ShellTab.today,
        ShellTab.decks,
        ShellTab.progress,
      ]) {
        testWidgets('the ${tab.name} tab at 1.4x'
            '${dark ? ', dark' : ''}: 56 high, nothing clipped, targets '
            'big enough', (tester) async {
          usePhone(tester, textScale: 1.4);
          final semantics = tester.ensureSemantics();
          final state = learner(const <String>[
            'hi',
            'bn',
            'te',
            'mr',
            'gu',
            'kn',
          ], choice: 'kn');
          if (dark) state.settings.themeMode = ThemeMode.dark;
          await pumpApp(tester, state: state);
          state.shellTab.value = tab;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(bar()).height, 56);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await openMenu(tester);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          semantics.dispose();
        });
      }
    }
  });
}
