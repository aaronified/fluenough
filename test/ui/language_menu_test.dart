import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/language_choice.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/course_chips.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/lesson_card.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/widgets/language_chips.dart';
import 'package:fluenough/ui/widgets/language_menu.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';

import '../support/harness.dart';

/// The language menu at the top of Today, Decks and Progress (#461), on the
/// design's Aro, who learns Hindi and Spanish, with twelve days of Spanish
/// (and Marathi, which Aro does not learn) reviews.

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

String nameOf(AppState state, String code) =>
    state.languages.singleWhere((l) => l.code == code).name;

/// Opens the menu on screen and chooses [label] in it.
Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.byType(LanguageMenu).hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Finder statTile(String value, String label) => find.byWidgetPredicate(
  (w) => w is StatTile && w.value == value && w.label == label,
);

Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('is on Today, Decks and Progress, and not on Settings', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro());
    Finder menuIn(Type page) => find.descendant(
      of: find.byType(page, skipOffstage: false),
      matching: find.byType(LanguageMenu, skipOffstage: false),
    );
    expect(menuIn(TodayPage), findsOneWidget);
    expect(menuIn(DecksPage), findsOneWidget);
    expect(menuIn(StatsPage), findsOneWidget);
    expect(menuIn(SettingsPage), findsNothing);
    for (final tab in ShellTab.values) {
      state.shellTab.value = tab;
      await tester.pumpAndSettle();
      expect(
        find.byType(LanguageMenu).hitTestable(),
        tab == ShellTab.settings ? findsNothing : findsOneWidget,
        reason: tab.name,
      );
    }
  });

  testWidgets('lists every language learned and All, and says which is '
      'shown', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro());
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');
    final spanish = nameOf(state, 'es');
    expect(
      find.byTooltip(l10n.languageMenuLabel(l10n.languageMenuAll)),
      findsOneWidget,
    );

    await tester.tap(find.byType(LanguageMenu));
    await tester.pumpAndSettle();
    final items = find.byType(MenuItemButton);
    expect(items, findsNWidgets(3));
    for (final label in <String>[l10n.languageMenuAll, hindi, spanish]) {
      expect(
        find.descendant(of: items, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(find.descendant(of: items, matching: find.text(spanish)));
    await tester.pumpAndSettle();
    expect(state.settings.languageChoice, 'es');
    expect(find.byTooltip(l10n.languageMenuLabel(spanish)), findsOneWidget);
  });

  testWidgets('Today shows only the chosen language\'s lesson, and All '
      'shows both again', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro());
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');
    final spanish = nameOf(state, 'es');
    LessonCard card() => tester.widget<LessonCard>(find.byType(LessonCard));
    List<String> lessons() => <String>[
      for (final lesson in card().lessons) lesson.language.code,
    ];
    expect(lessons(), containsAll(<String>['hi', 'es']));

    await choose(tester, hindi);
    expect(lessons(), <String>['hi']);
    expect(find.text(l10n.todayLessonTitleIn(spanish)), findsNothing);

    await choose(tester, spanish);
    expect(lessons(), <String>['es']);

    await choose(tester, l10n.languageMenuAll);
    expect(lessons(), containsAll(<String>['hi', 'es']));
  });

  testWidgets('Decks shows only the chosen language\'s course, without the '
      'course chips', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const DecksPage(),
      state: await aro(choice: 'es'),
    );
    expect(find.byType(CourseChips), findsNothing);
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard)).view.language.code,
      'es',
    );

    state.showLanguage('hi');
    await tester.pumpAndSettle();
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard)).view.language.code,
      'hi',
    );

    // All: every course, chosen by its chip, as before.
    state.showLanguage(null);
    await tester.pumpAndSettle();
    expect(find.byType(CourseChips), findsOneWidget);
    final chips = tester.widget<CourseChips>(find.byType(CourseChips));
    expect(
      chips.languages.map((l) => l.code),
      containsAll(<String>['hi', 'es', 'te']),
    );
  });

  testWidgets('Progress counts only the chosen language, without the '
      'language chips', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const StatsPage(),
      state: await aro(choice: 'es'),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(LanguageChips), findsNothing);
    // Spanish's 22 reviews, not Marathi's as well.
    expect(statTile('22', l10n.statsReviews), findsOneWidget);

    // Hindi has none yet.
    state.showLanguage('hi');
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsNoReviews), findsOneWidget);

    // All: the language chips, as before, and every review under their All.
    state.showLanguage(null);
    await tester.pumpAndSettle();
    expect(find.byType(LanguageChips), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.statsLanguageAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.statsLanguageAll));
    await tester.pumpAndSettle();
    expect(statTile('44', l10n.statsReviews), findsOneWidget);
  });

  testWidgets('on a deck\'s page, choosing another language goes back to '
      'the tabs; its own, or All, stays', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, state: await aro());
    final hindi = nameOf(state, 'hi');
    final spanish = nameOf(state, 'es');
    final context = tester.element(find.byType(TodayPage));
    unawaited(AppNavigator.openDeck(context, 'hi-en-market'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckDetailPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DeckDetailPage),
        matching: find.byType(LanguageMenu),
      ),
      findsOneWidget,
    );

    await choose(tester, hindi);
    expect(find.byType(DeckDetailPage), findsOneWidget);
    await choose(tester, l10nOf(tester).languageMenuAll);
    expect(find.byType(DeckDetailPage), findsOneWidget);

    await choose(tester, spanish);
    expect(find.byType(DeckDetailPage), findsNothing);
    expect(state.shownLanguage, 'es');
  });

  testWidgets('with one language learned, it is shown, and All is offered', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(
      tester,
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    final telugu = nameOf(state, 'te');
    expect(find.byTooltip(l10n.languageMenuLabel(telugu)), findsOneWidget);
    await choose(tester, l10n.languageMenuAll);
    expect(state.settings.languageChoice, LanguageChoice.all);
    expect(
      find.byTooltip(l10n.languageMenuLabel(l10n.languageMenuAll)),
      findsOneWidget,
    );
  });

  group('accessibility', () {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final choice in <String?>[null, 'es']) {
        for (final tab in <ShellTab>[
          ShellTab.today,
          ShellTab.decks,
          ShellTab.progress,
        ]) {
          testWidgets('the ${tab.name} tab, ${choice ?? 'All'}, '
              '${themeMode.name}', (tester) async {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final state = await aro(choice: choice);
            state.settings.themeMode = themeMode;
            await pumpApp(tester, state: state);
            state.shellTab.value = tab;
            await tester.pumpAndSettle();
            final l10n = l10nOf(tester);
            final name = choice == null
                ? l10n.languageMenuAll
                : nameOf(state, choice);
            // Named for a screen reader, as a button.
            expect(
              find.bySemanticsLabel(l10n.languageMenuLabel(name)),
              findsOneWidget,
            );
            await meetsEveryGuideline(tester);
            semantics.dispose();
          });
        }

        testWidgets('the open menu, ${choice ?? 'All'}, ${themeMode.name}', (
          tester,
        ) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          final state = await aro(choice: choice);
          state.settings.themeMode = themeMode;
          await pumpApp(tester, state: state);
          await tester.tap(find.byType(LanguageMenu));
          await tester.pumpAndSettle();
          expect(find.byType(MenuItemButton), findsNWidgets(3));
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    }

    for (final dark in <bool>[false, true]) {
      for (final tab in <ShellTab>[
        ShellTab.today,
        ShellTab.decks,
        ShellTab.progress,
      ]) {
        testWidgets('the ${tab.name} tab at text scale 2.0'
            '${dark ? ', dark' : ''}: nothing clipped, targets big '
            'enough', (tester) async {
          usePhone(tester, textScale: 2.0);
          final semantics = tester.ensureSemantics();
          final state = await aro(choice: 'es');
          if (dark) state.settings.themeMode = ThemeMode.dark;
          await pumpApp(tester, state: state);
          state.shellTab.value = tab;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(LanguageMenu).hitTestable(), findsOneWidget);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // The menu opens, its languages readable, at that size too.
          await tester.tap(find.byType(LanguageMenu).hitTestable());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          semantics.dispose();
        });
      }
    }
  });
}
