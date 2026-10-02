import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/learn_languages_page.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';

/// Choosing what to learn and placement (#117, ADR-0013), from first launch
/// and from Settings.

/// The app on first launch after the languages the learner speaks.
Future<AppState> pumpFirstLaunch(WidgetTester tester) async {
  final state = AppState.test(
    settings: SettingsNotifier(spokenLanguages: const <String>['en']),
  );
  addTearDown(state.dispose);
  await tester.pumpWidget(FluenoughApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final found = find.text(text);
  await tester.ensureVisible(found.first);
  await tester.pumpAndSettle();
  await tester.tap(found.first);
  await tester.pumpAndSettle();
}

String nameOf(AppState state, String code) =>
    state.languages.singleWhere((l) => l.code == code).name;

/// Answers the question on screen: rightly, from [state]'s course for
/// [code], or with "I don't know".
Future<void> answer(
  WidgetTester tester,
  AppState state,
  String code, {
  required bool right,
}) async {
  final l10n = l10nOf(tester);
  if (!right) return tapText(tester, l10n.placementDontKnow);
  final target = tester.widget<TargetText>(find.byType(TargetText)).text;
  final card = <DeckEntry>[for (final unit in state.courseUnits(code)) ...unit]
      .expand((e) => e.cards)
      .firstWhere((c) => c.target == target);
  await tester.ensureVisible(find.widgetWithText(OutlinedButton, card.native));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, card.native));
  await tester.pumpAndSettle();
}

Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
  for (final unit in units)
    for (final entry in unit) entry.id,
};

void main() {
  testWidgets('first launch asks what to learn; "I\'m new" starts from the '
      'beginning and saves the choice', (tester) async {
    usePhone(tester);
    final state = await pumpFirstLaunch(tester);
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');

    expect(find.text(l10n.learnTitle), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    final go = find.widgetWithText(FilledButton, l10n.commonContinue);
    expect(tester.widget<FilledButton>(go).onPressed, isNull);

    await tapText(tester, hindi);
    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(find.text(l10n.placementAskTitle(hindi)), findsOneWidget);
    expect(state.settings.learningChosen, isFalse, reason: 'nothing saved yet');

    await tapText(tester, l10n.placementNew(hindi));
    final first = state.courseUnits('hi').first.first.deck.name;
    expect(find.text(l10n.placementResultStart(hindi, first)), findsOneWidget);
    await tapText(tester, l10n.placementDone);

    expect(find.byType(AppShell), findsOneWidget);
    expect(state.settings.learningLanguages, <String>['hi']);
    expect(state.settings.learningChosen, isTrue);
    expect(state.settings.placedDecks, isEmpty);
    expect(state.currentProfile.learns('bn'), isFalse);
  });

  testWidgets('Find my level places the units known, and teaching starts '
      'after them', (tester) async {
    usePhone(tester);
    final state = await pumpFirstLaunch(tester);
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');
    final units = state.courseUnits('hi');

    await tapText(tester, hindi);
    await tapText(tester, l10n.commonContinue);
    await tapText(tester, l10n.placementFind);
    expect(find.text(l10n.placementQuestion), findsOneWidget);
    expect(find.text(l10n.placementProgress(1, units.length)), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await answer(tester, state, 'hi', right: true);
    }
    expect(find.text(l10n.placementProgress(2, units.length)), findsOneWidget);
    await answer(tester, state, 'hi', right: false);
    await answer(tester, state, 'hi', right: false);

    expect(
      find.text(l10n.placementResultFrom(1, hindi, units[1].first.deck.name)),
      findsOneWidget,
    );
    await tapText(tester, l10n.placementDone);
    expect(state.settings.placedDecks, decksOf(units.take(1)));
    expect(state.pendingUnits.first.first.id, units[1].first.id);
  });

  testWidgets('Stop here keeps what placement found so far', (tester) async {
    usePhone(tester);
    final state = await pumpFirstLaunch(tester);
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');
    final units = state.courseUnits('hi');

    await tapText(tester, hindi);
    await tapText(tester, l10n.commonContinue);
    await tapText(tester, l10n.placementFind);
    for (var i = 0; i < 4; i++) {
      await answer(tester, state, 'hi', right: true);
    }
    await tapText(tester, l10n.placementStop);
    expect(
      find.text(l10n.placementResultFrom(1, hindi, units[1].first.deck.name)),
      findsOneWidget,
    );
    await tapText(tester, l10n.placementDone);
    expect(state.settings.placedDecks, decksOf(units.take(1)));
  });

  testWidgets('two languages are placed one after the other', (tester) async {
    usePhone(tester);
    final state = await pumpFirstLaunch(tester);
    final l10n = l10nOf(tester);
    final hindi = nameOf(state, 'hi');
    final bengali = nameOf(state, 'bn');

    await tapText(tester, hindi);
    await tapText(tester, bengali);
    await tapText(tester, l10n.commonContinue);
    // In the catalog's order.
    expect(find.text(l10n.placementAskTitle(bengali)), findsOneWidget);
    await tapText(tester, l10n.placementNew(bengali));
    await tapText(tester, l10n.placementNext);
    expect(find.text(l10n.placementAskTitle(hindi)), findsOneWidget);
    await tapText(tester, l10n.placementNew(hindi));
    await tapText(tester, l10n.placementDone);
    expect(state.settings.learningLanguages, <String>['bn', 'hi']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('leaving placement part-way saves nothing', (tester) async {
    usePhone(tester);
    final state = await pumpFirstLaunch(tester);
    final l10n = l10nOf(tester);
    await tapText(tester, nameOf(state, 'hi'));
    await tapText(tester, l10n.commonContinue);
    await tapText(tester, l10n.placementFind);
    await answer(tester, state, 'hi', right: true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LearnLanguagesPage), findsOneWidget);
    expect(state.settings.learningChosen, isFalse);
    expect(state.settings.learningLanguages, isEmpty);
    expect(state.settings.placedDecks, isEmpty);
  });

  testWidgets('from Settings, only a language newly added is placed, and the '
      'others keep their placement', (tester) async {
    usePhone(tester);
    final base = AppState.test();
    await base.load();
    final hindiUnit = decksOf(base.courseUnits('hi').take(1));
    base.dispose();
    final state = await pumpApp(
      tester,
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          placedDecks: hindiUnit,
          learningChosen: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    final bengali = nameOf(state, 'bn');
    await tapText(tester, l10n.navSettings);
    expect(find.text(nameOf(state, 'hi')), findsWidgets);
    await tapText(tester, l10n.settingsLearn);

    expect(find.text(l10n.learnTitle), findsOneWidget);
    await tapText(tester, bengali);
    await tapText(tester, l10n.commonContinue);
    expect(find.text(l10n.placementAskTitle(bengali)), findsOneWidget);
    await tapText(tester, l10n.placementNew(bengali));
    await tapText(tester, l10n.placementDone);

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(LearnLanguagesPage), findsNothing);
    expect(state.settings.learningLanguages, <String>['bn', 'hi']);
    expect(state.settings.placedDecks, hindiUnit);

    // Taking a language off asks nothing.
    await tapText(tester, l10n.settingsLearn);
    await tapText(tester, bengali);
    await tapText(tester, l10n.commonContinue);
    expect(find.byType(PlacementPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(state.settings.learningLanguages, <String>['hi']);
  });

  testWidgets('nothing overflows at twice the text size, light and dark', (
    tester,
  ) async {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      usePhone(tester, textScale: 2.0);
      for (final page in <Widget>[
        const LearnLanguagesPage(firstRun: true),
        PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
        PlacementPage(
          languages: const <String>['hi'],
          onFinished: (_) {},
          random: Random(1),
          checking: true,
        ),
      ]) {
        await pumpScreen(
          tester,
          KeyedSubtree(key: UniqueKey(), child: page),
          themeMode: mode,
        );
        expect(tester.takeException(), isNull, reason: '$page $mode');
      }
    }
  });

  testWidgets('the screens meet the tap-target, label and contrast '
      'guidelines', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    for (final page in <Widget>[
      const LearnLanguagesPage(firstRun: true),
      PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
      PlacementPage(
        languages: const <String>['hi'],
        onFinished: (_) {},
        random: Random(1),
        checking: true,
      ),
    ]) {
      await pumpScreen(tester, KeyedSubtree(key: UniqueKey(), child: page));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  });
}
