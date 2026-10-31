// The merged Languages page (#907): four skills a language, three states,
// one list. Behaviour a learner sees, at 1.4x text in light and dark.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/skill_widgets.dart';
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
  List<SpokenLanguage>? list,
  ThemeMode mode = ThemeMode.light,
  double textScale = 1.4,
}) {
  usePhone(tester, textScale: textScale);
  return pumpScreen(
    tester,
    LanguagesPage(spokenList: list ?? pickerSpokenList),
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

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the details show the language family as a tag, and none '
        'for a language without one, at 1.4x text in ${mode.name} (#698)', (
      tester,
    ) async {
      await pumpLanguages(tester, mode: mode);
      await tapKey(tester, 'language-es');
      await tester.tap(find.text('i'));
      await tester.pumpAndSettle();
      final tag = find.byKey(const ValueKey<String>('language-family'));
      expect(tag, findsOneWidget);
      expect(
        find.descendant(of: tag, matching: find.text('Romance')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a language with no family shows no family tag in its details '
      '(#698)', (tester) async {
    final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
    final unfiled = <SpokenLanguage>[
      for (final l in pickerSpokenList)
        if (l.code == 'es')
          SpokenLanguage(
            code: es.code,
            iso639_3: es.iso639_3,
            name: es.name,
            ownName: es.ownName,
            scripts: es.scripts,
          )
        else
          l,
    ];
    await pumpLanguages(tester, list: unfiled);
    await tapKey(tester, 'language-es');
    await tester.tap(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('language-family')), findsNothing);
    expect(find.text(l10n(tester).languagesInfoDialect), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long press on a skill pill shows its skill and state, and a '
      'tap still cycles it (#913)', (tester) async {
    final state = await pumpLanguages(tester);
    await tapKey(tester, 'language-es');
    final text = l10n(tester);
    final speak = find.byKey(const ValueKey<String>('skill-speak'));
    // Null until the learner edits Spanish on this page; the pill reads the
    // older lists (Learn, from the learner fixture) until then.
    final before = state.settings.languageSkillsOf('es');
    await tester.ensureVisible(speak);
    await tester.pumpAndSettle();
    await tester.longPress(speak);
    await tester.pumpAndSettle();
    expect(
      find.text(
        text.languagesSkillState(
          SkillKind.speak.label(text),
          SkillState.learn.label(text),
        ),
      ),
      findsOneWidget,
    );
    expect(state.settings.languageSkillsOf('es'), before, reason: 'no cycle');
    await tapKey(tester, 'skill-speak');
    expect(state.settings.languageSkillsOf('es'), isNot(before));
  });

  testWidgets('the sheet and page icons show a one-word hint on a long '
      'press (#913)', (tester) async {
    await pumpLanguages(tester);
    final text = l10n(tester);
    await tester.longPress(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    expect(find.text(text.hintReport), findsOneWidget);
    await tapKey(tester, 'language-es');
    await tester.longPress(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text(text.hintInfo), findsOneWidget);
  });

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
    await tester.tap(find.byTooltip(text.hintAdd));
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

  testWidgets('opened with a course name (the deck search shortcut), Add a '
      'language shows that course (#918)', (tester) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      LanguagesPage(spokenList: pickerSpokenList, initialQuery: 'Marathi'),
      state: learner(),
    );
    await tester.pumpAndSettle();
    final search = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('languages-add-search')),
    );
    expect(search.controller!.text, 'Marathi');
    expect(find.byKey(const ValueKey<String>('add-mr')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('add-hi')), findsNothing);
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
