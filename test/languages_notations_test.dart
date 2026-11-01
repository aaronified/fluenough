// The IPA and English Braille on the Languages page (owner, 2026-11-02: "This
// screen doesn't show ipa and braille, both of which are in my list"). They
// are notations taught like languages (ADR-0041, ADR-0043), listed at the end
// of assets/languages.yaml: the IPA is heard, spoken and read, never typed;
// English Braille is read and written, never spoken. Older lists that hold
// their codes read as skills with no migration.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:fluenough/features/languages/skill_widgets.dart';
import 'package:fluenough/features/onboarding/languages_step.dart';
import 'package:fluenough/features/onboarding/onboarding_step.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';

AppLocalizations l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

SpokenLanguage language(String code) =>
    pickerSpokenList.firstWhere((l) => l.code == code);

/// The older lists as the owner's profile holds them: Spanish, the IPA and
/// English Braille learned, nothing saved by the Languages page yet.
AppState learnsNotations() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es', 'ipa', 'qbe'],
    learningChosen: true,
  )..scriptsRead = <String, bool>{'en': true},
);

Future<AppState> pumpLanguages(
  WidgetTester tester, {
  required AppState state,
  ThemeMode mode = ThemeMode.light,
}) {
  usePhone(tester, textScale: 1.4);
  return pumpScreen(
    tester,
    LanguagesPage(spokenList: pickerSpokenList),
    state: state,
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

Finder row(String code) => find.byKey(ValueKey<String>('language-$code'));

/// The chips of [code]'s row, in order.
List<SkillBadge> chipsOf(WidgetTester tester, String code) => tester
    .widgetList<SkillBadge>(
      find.descendant(of: row(code), matching: find.byType(SkillBadge)),
    )
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the list and its skills', () {
    test('the IPA is never typed, and braille has no speech', () {
      final ipa = language('ipa');
      final braille = language('qbe');
      expect(ipa.typed, isFalse);
      expect(ipa.scriptOnly, isFalse);
      expect(ipa.scripts, <String>['ipa']);
      expect(braille.scriptOnly, isTrue);
      expect(braille.typed, isTrue);
      expect(braille.scripts, <String>['braille']);
      expect(ipa.isNotation && braille.isNotation, isTrue);
      expect(language('es').isNotation, isFalse);
    });

    test('the IPA has Speak, Hear and Read, and no Write; braille has Read '
        'and Write only', () {
      final state = AppState.test();
      expect(state.skillShape(language('ipa')), const <SkillKey>[
        SkillKey(SkillKind.speak),
        SkillKey(SkillKind.hear),
        SkillKey(SkillKind.read, 'ipa'),
      ]);
      expect(state.skillShape(language('qbe')), const <SkillKey>[
        SkillKey(SkillKind.read, 'braille'),
        SkillKey(SkillKind.write, 'braille'),
      ]);
    });

    test('a script nothing is typed in cycles Leave, Learn, Read, Leave', () {
      final seen = <ScriptLevel>[];
      var skills = LanguageSkills();
      for (var i = 0; i < 4; i++) {
        skills = skills.cycledScript('ipa', canLearn: true, canWrite: false);
        seen.add(skills.scriptLevelOf('ipa'));
      }
      expect(seen, <ScriptLevel>[
        ScriptLevel.learn,
        ScriptLevel.read,
        ScriptLevel.leave,
        ScriptLevel.learn,
      ]);
      expect(
        skills.held.where((k) => k.kind == SkillKind.write),
        isEmpty,
        reason: 'no Write is ever held for it',
      );
    });

    test('an older list that learned the IPA reads as Speak, Hear and Read '
        'learned, with no Write', () async {
      final state = learnsNotations();
      await state.load();
      final skills = state.skillsOf(language('ipa'));
      expect(skills.stateOf(const SkillKey(SkillKind.speak)), SkillState.learn);
      expect(skills.stateOf(const SkillKey(SkillKind.hear)), SkillState.learn);
      expect(
        skills.stateOf(const SkillKey(SkillKind.read, 'ipa')),
        SkillState.learn,
      );
      expect(skills.held.any((k) => k.kind == SkillKind.write), isFalse);
    });

    test('an older list that learned braille reads as Read and Write '
        'learned, with no Speak or Hear', () async {
      final state = learnsNotations();
      await state.load();
      final skills = state.skillsOf(language('qbe'));
      expect(skills.held.toSet(), <SkillKey>{
        const SkillKey(SkillKind.read, 'braille'),
        const SkillKey(SkillKind.write, 'braille'),
      });
      expect(skills.anyLearn, isTrue);
    });
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('learned in the older lists, both are rows in Learning with '
        'only the pills that mean something, at 1.4x in ${mode.name}', (
      tester,
    ) async {
      await pumpLanguages(tester, state: learnsNotations(), mode: mode);
      final text = l10n(tester);
      expect(find.text(text.languagesSectionLearning(3)), findsOneWidget);
      expect(row('ipa'), findsOneWidget);
      expect(row('qbe'), findsOneWidget);

      // The IPA: Spoken (hear, speak) and its script, which is read only.
      final ipa = chipsOf(tester, 'ipa');
      expect(ipa.map((c) => c.kind), <SkillKind>[
        SkillKind.hear,
        SkillKind.read,
      ]);
      expect(ipa.map((c) => c.mark), everyElement(SkillMark.learn));

      // Braille: the script alone, no Speak or Hear.
      final braille = chipsOf(tester, 'qbe');
      expect(braille.map((c) => c.kind), <SkillKind>[SkillKind.read]);
      expect(braille.single.mark, SkillMark.learn);

      // No dialect line under the IPA's name.
      expect(
        find.descendant(
          of: row('ipa'),
          matching: find.text(dialectOf(text, language('ipa'))),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('known in the older lists, both are rows in Know', (
    tester,
  ) async {
    final state = AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en', 'ipa', 'qbe'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      )..scriptsRead = <String, bool>{'en': true, 'qbe': true},
    );
    await pumpLanguages(tester, state: state);
    final text = l10n(tester);
    expect(find.text(text.languagesSectionKnow(3)), findsOneWidget);
    expect(row('ipa'), findsOneWidget);
    expect(row('qbe'), findsOneWidget);
    expect(chipsOf(tester, 'ipa').map((c) => c.kind), <SkillKind>[
      SkillKind.hear,
      SkillKind.read,
    ]);
    expect(chipsOf(tester, 'ipa').first.mark, SkillMark.knowBoth);
    expect(chipsOf(tester, 'qbe').map((c) => c.kind), <SkillKind>[
      SkillKind.read,
    ]);
    expect(chipsOf(tester, 'qbe').single.mark, isNot(SkillMark.leave));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the IPA sheet has Spoken and a Read-only script pill, and no '
      'dialect', (tester) async {
    final state = await pumpLanguages(tester, state: learnsNotations());
    await tapKey(tester, 'language-ipa');
    final text = l10n(tester);
    expect(find.byKey(const ValueKey<String>('skill-spoken')), findsOneWidget);
    expect(find.text(text.languagesDialectLabel), findsNothing);
    // The IPA starts at Learn: Read, Leave, Learn (the IPA has decks to
    // learn), Read. Never Read and Write.
    final seen = <ScriptLevel>[];
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, 'skill-script:ipa');
      seen.add(state.skillsOf(language('ipa')).scriptLevelOf('ipa'));
    }
    expect(seen, <ScriptLevel>[
      ScriptLevel.read,
      ScriptLevel.leave,
      ScriptLevel.learn,
      ScriptLevel.read,
    ], reason: 'no Write level');
    expect(
      state.settings.languageSkillsOf('ipa')!.keys,
      isNot(contains('write:ipa')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the braille sheet has no Spoken pill, and its script pill '
      'goes up to Read and Write', (tester) async {
    final state = await pumpLanguages(tester, state: learnsNotations());
    await tapKey(tester, 'language-qbe');
    expect(find.byKey(const ValueKey<String>('skill-spoken')), findsNothing);
    final braille = language('qbe');
    await tapKey(tester, 'skill-script:braille');
    expect(state.skillsOf(braille).scriptLevelOf('braille'), ScriptLevel.read);
    await tapKey(tester, 'skill-script:braille');
    expect(
      state.skillsOf(braille).scriptLevelOf('braille'),
      ScriptLevel.readWrite,
    );
    expect(
      state.settings.languageSkillsOf('qbe'),
      containsPair('write:braille', 'know'),
    );
    expect(tester.takeException(), isNull);
  });

  group('the filters', () {
    testWidgets('Write leaves out the IPA, Speak and Hear leave out braille, '
        'Learning keeps both', (tester) async {
      await pumpLanguages(tester, state: learnsNotations());
      await tapKey(tester, 'filter-write');
      expect(row('qbe'), findsOneWidget);
      expect(row('ipa'), findsNothing, reason: 'nothing is typed in the IPA');
      await tapKey(tester, 'filter-write');
      for (final f in <String>['speak', 'hear']) {
        await tapKey(tester, 'filter-$f');
        expect(row('ipa'), findsOneWidget, reason: f);
        expect(row('qbe'), findsNothing, reason: '$f: braille has no speech');
        await tapKey(tester, 'filter-$f');
      }
      await tapKey(tester, 'filter-learning');
      expect(row('ipa'), findsOneWidget);
      expect(row('qbe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Add a language', () {
    Future<AppState> openAdd(WidgetTester tester) async {
      final state = await pumpLanguages(
        tester,
        state: AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['es'],
            learningChosen: true,
          )..scriptsRead = <String, bool>{'en': true},
        ),
      );
      await tapKey(tester, 'languages-add-row');
      return state;
    }

    testWidgets('lists the IPA and braille, found by their names', (
      tester,
    ) async {
      await openAdd(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'phonetic',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-ipa')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'braille',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-qbe')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the IPA is added as heard, and is a Know row that is not '
        'among the languages spoken', (tester) async {
      final state = await openAdd(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'IPA',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'add-ipa');
      // Leave, Learn, Hear: two taps on the Spoken pill reach Hear.
      await tapKey(tester, 'skill-spoken');
      await tapKey(tester, 'skill-spoken');
      await tester.tap(find.text(l10n(tester).languagesAddLanguage('IPA')));
      await tester.pumpAndSettle();
      expect(state.skillsOf(language('ipa')).spokenLevel, SpokenLevel.hear);
      expect(state.settings.spokenLanguages, isNot(contains('ipa')));
      expect(row('ipa'), findsOneWidget);
      expect(
        find.text(l10n(tester).languagesSectionKnow(2)),
        findsOneWidget,
        reason: 'English and the IPA',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('braille is added as read and written', (tester) async {
      final state = await openAdd(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'braille',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'add-qbe');
      // Leave, Learn, Read, Read and Write: three taps on the script pill.
      await tapKey(tester, 'skill-script:braille');
      await tapKey(tester, 'skill-script:braille');
      await tapKey(tester, 'skill-script:braille');
      await tester.tap(
        find.text(l10n(tester).languagesAddLanguage('English Braille')),
      );
      await tester.pumpAndSettle();
      expect(
        state.skillsOf(language('qbe')).scriptLevelOf('braille'),
        ScriptLevel.readWrite,
      );
      expect(row('qbe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the first launch shares the list', () {
    testWidgets('the IPA and braille are offered, and a pick goes straight '
        'to the skills sheet', (tester) async {
      expect(asksWhichScripts(language('ipa')), isFalse);
      expect(asksWhichScripts(language('qbe')), isFalse);
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        OnboardingAddLanguagePage(
          answers: OnboardingAnswers(),
          all: pickerSpokenList,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'braille',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('add-qbe')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'IPA',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'add-ipa');
      expect(
        find.byKey(const ValueKey<String>('skill-script:ipa')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('skill-spoken')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list of what was set shows them in Learning', (
      tester,
    ) async {
      final answers = OnboardingAnswers(
        chosen: <String, ChosenLanguage>{
          'ipa': ChosenLanguage(
            language('ipa'),
            LanguageSkills().withSpokenLevel(SpokenLevel.learn),
          ),
          'qbe': ChosenLanguage(
            language('qbe'),
            LanguageSkills().withScriptLevel('braille', ScriptLevel.learn),
          ),
        },
      );
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        Scaffold(
          body: OnboardingLanguages(
            answers: answers,
            choices: pickerSpokenList,
          ),
        ),
      );
      expect(row('ipa'), findsOneWidget);
      expect(row('qbe'), findsOneWidget);
      expect(
        find.text(l10n(tester).languagesSectionLearning(2)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
