// The merged Languages page (#907): four skills a language, three states,
// one list. Behaviour a learner sees, at 1.4x text in light and dark.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';

AppLocalizations l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

/// An English speaker who reads Latin and learns Spanish, as the older
/// lists held it.
AppState learner() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
    learningChosen: true,
  )..scriptsRead = <String, bool>{'en': true},
);

Future<AppState> pumpLanguages(
  WidgetTester tester, {
  AppState? state,
  ThemeMode mode = ThemeMode.light,
  double textScale = 1.4,
}) {
  usePhone(tester, textScale: textScale);
  return pumpScreen(
    tester,
    LanguagesPage(spokenList: pickerSpokenList),
    state: state ?? learner(),
    themeMode: mode,
  );
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the older lists show as skills: Spanish learning, English '
      'known, Learning first', (tester) async {
    await pumpLanguages(tester);
    final text = l10n(tester);
    expect(find.text(text.languagesSectionLearning(1)), findsOneWidget);
    expect(find.text(text.languagesSectionKnow(1)), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-es')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the sheet fits at 1.4x text in ${mode.name}, its pills 48 px '
        'tall', (tester) async {
      await pumpLanguages(tester, mode: mode);
      await tapKey(tester, 'language-es');
      final speak = find.byKey(const ValueKey<String>('skill-speak'));
      expect(speak, findsOneWidget);
      expect(tester.getSize(speak).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tap cycles Know, Learn, Leave; the last Leave sends the '
      'language back to the pool', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-en');
    // English has no course, so Learn is skipped: Know goes to Leave.
    await tapKey(tester, 'skill-speak');
    expect(state.settings.languageSkillsOf('en')!.containsKey('speak'), false);
    await tapKey(tester, 'skill-hear');
    await tapKey(tester, 'skill-read:latin');
    // English is known in Write too, by default (#926).
    await tapKey(tester, 'skill-write:latin');
    expect(state.settings.languageSkillsOf('en'), isEmpty);
    expect(find.byKey(const ValueKey<String>('language-en')), findsNothing);
    // It stays among the languages spoken, which is never left empty.
    expect(state.settings.spokenLanguages, <String>['en']);
  });

  testWidgets('Learn on a skill downloads nothing here but leaves the button '
      'reading Check; a failed sound test keeps it', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    // Spanish speak is Learn already; set it to Leave, Know, then Learn.
    await tapKey(tester, 'skill-speak');
    await tapKey(tester, 'skill-speak');
    await tapKey(tester, 'skill-speak');
    expect(
      state
          .skillsOf(pickerSpokenList.firstWhere((l) => l.code == 'es'))
          .anyLearn,
      isTrue,
    );
    expect(find.text(text.languagesCheck), findsOneWidget);
    await tester.tap(find.text(text.languagesCheck));
    await tester.pumpAndSettle();
    // The test phone has no Spanish voice.
    expect(find.text(text.languagesCheckSoundBad), findsOneWidget);
    await tester.tap(find.text(text.commonClose));
    await tester.pumpAndSettle();
    expect(find.text(text.languagesCheck), findsOneWidget);
  });

  testWidgets('minutes a day step by 5 and show just "20 mins"', (
    tester,
  ) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    expect(find.text(text.languagesMinutesMins(15)), findsOneWidget);
    await tapKey(tester, 'minutes-more');
    expect(state.settings.dailyMinutesFor('es'), 20);
    expect(find.text(text.languagesMinutesMins(20)), findsOneWidget);
  });

  testWidgets('a script known from another language starts as Know when '
      'adding', (tester) async {
    final state = learner()
      ..settings.setLanguageSkills('hi', <String, String>{
        'read:devanagari': 'know',
      });
    await pumpLanguages(tester, state: state);
    final text = l10n(tester);
    await tester.tap(find.byTooltip(text.languagesAdd));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('languages-add-search')),
      'Marathi',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'add-mr');
    expect(
      find.text(text.languagesKnownFrom(text.languagesSkillRead, 'Hindustani')),
      findsOneWidget,
    );
    await tapKey(tester, 'skill-speak');
    await tester.tap(find.text(text.languagesAddLanguage('Marathi')));
    await tester.pumpAndSettle();
    expect(
      state.settings.languageSkillsOf('mr'),
      containsPair('speak', 'know'),
    );
    expect(state.settings.spokenLanguages, contains('mr'));
  });

  testWidgets('a filter pill keeps only the languages with that state', (
    tester,
  ) async {
    await pumpLanguages(tester);
    await tapKey(tester, 'filter-learning');
    expect(find.byKey(const ValueKey<String>('language-es')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('language-en')), findsNothing);
    await tapKey(tester, 'filter-learning');
    expect(find.byKey(const ValueKey<String>('language-en')), findsOneWidget);
  });
}
