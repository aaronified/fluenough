// English is known in every skill and the Latin script by everyone (#926):
// the defaults, an install from before, a choice that is kept, and what
// other profiles and the downloads see.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/picker.dart';

void main() {
  final en = pickerSpokenList.firstWhere((l) => l.code == 'en');
  final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
  final hi = pickerSpokenList.firstWhere((l) => l.code == 'hi');

  AppState stateWith(SettingsNotifier settings) {
    final state = AppState.test(settings: settings);
    addTearDown(state.dispose);
    return state;
  }

  const allKnow = <SkillKey>[
    SkillKey(SkillKind.speak),
    SkillKey(SkillKind.hear),
    SkillKey(SkillKind.read, 'latin'),
    SkillKey(SkillKind.write, 'latin'),
  ];

  test('a learner with no English entry has it known in all four skills', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    // Before anything runs, the page already reads it as known.
    final before = state.skillsOf(en);
    for (final key in allKnow) {
      expect(before.stateOf(key), SkillState.know, reason: '$key');
    }

    state.ensureEnglishKnown();

    final skills = state.skillsOf(en);
    for (final key in allKnow) {
      expect(skills.stateOf(key), SkillState.know, reason: '$key');
    }
    // The older lists follow, English after the learner's own languages.
    expect(state.settings.spokenLanguages, <String>['hi', 'en']);
    expect(state.settings.scriptsRead['en'], isTrue);
    // English is known, never learned.
    expect(state.learningCodes, isNot(contains('en')));
    expect(skills.anyLearn, isFalse);
  });

  test('a first launch is left to the setup', () {
    final state = stateWith(SettingsNotifier());
    state.ensureEnglishKnown();
    expect(state.settings.spokenLanguages, isEmpty);
    expect(state.settings.languageSkillsOf('en'), isNull);
  });

  test('an explicit change to English survives, even all Leave', () async {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningChosen: true,
      ),
    );
    state.ensureEnglishKnown();
    state.applySkills(
      en,
      state
          .skillsOf(en)
          .withState(
            const SkillKey(SkillKind.write, 'latin'),
            SkillState.leave,
          ),
    );
    state.ensureEnglishKnown();
    expect(
      state.skillsOf(en).stateOf(const SkillKey(SkillKind.write, 'latin')),
      SkillState.leave,
    );
    expect(
      state.skillsOf(en).stateOf(const SkillKey(SkillKind.speak)),
      SkillState.know,
    );

    // All Leave is kept across the clean-up at an app open, not forgotten.
    state.applySkills(en, LanguageSkills());
    await state.removeUnneededDecks();
    state.ensureEnglishKnown();
    expect(state.skillsOf(en).isAllLeave, isTrue);
    expect(state.settings.spokenLanguages, <String>['hi']);
  });

  test('the Latin script is known for a language written in it', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    final skills = state.skillsOf(es);
    expect(
      skills.stateOf(const SkillKey(SkillKind.read, 'latin')),
      SkillState.know,
    );
    expect(
      skills.stateOf(const SkillKey(SkillKind.write, 'latin')),
      SkillState.know,
    );
    expect(state.scriptsReadKnown, contains('latin'));
  });

  test('a language in the pool is not listed because of the Latin script', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningChosen: true,
      ),
    );
    expect(state.skillsOf(es).isAllLeave, isTrue);
  });

  test('a language in another script gets no Latin skills; Learn stays', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    expect(state.skillShape(hi).any((k) => k.script == 'latin'), isFalse);
    expect(state.skillsOf(hi).held.where((k) => k.script == 'latin'), isEmpty);
    // Spanish learned keeps its Learn skills; the Latin script is not
    // turned into Know over a Learn.
    final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
    final learned = withLatinKnown(
      LanguageSkills(<SkillKey, SkillState>{
        const SkillKey(SkillKind.speak): SkillState.learn,
        const SkillKey(SkillKind.read, 'latin'): SkillState.learn,
      }),
      state.skillScripts(es),
    );
    expect(
      learned.stateOf(const SkillKey(SkillKind.read, 'latin')),
      SkillState.learn,
    );
    expect(
      learned.stateOf(const SkillKey(SkillKind.write, 'latin')),
      SkillState.know,
    );
  });

  test('English known changes no profile\'s learned languages', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    state.createProfile(name: 'B', languages: <String>{'bn'});
    state.ensureEnglishKnown();
    expect(state.learningCodes, isNot(contains('en')));
    for (final profile in state.profiles) {
      expect(profile.languages ?? const <String>{}, isNot(contains('en')));
    }
    state.selectProfile(state.profiles.last.id);
    expect(state.learningCodes, isNot(contains('en')));
    expect(
      state.skillsOf(en).stateOf(const SkillKey(SkillKind.hear)),
      SkillState.know,
    );
  });
}
