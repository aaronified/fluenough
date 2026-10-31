// English is known in every skill, fixed, and the Latin script by everyone
// (#926): the defaults, an install from before, and what
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

  test('English cannot be changed: a saved change or Leave is ignored', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningChosen: true,
      ),
    );
    state.applySkills(en, LanguageSkills());
    state.settings.setLanguageSkills('en', const <String, String>{});
    expect(state.skillsOf(en), englishKnownByDefault());
    state.ensureEnglishKnown();
    expect(state.settings.languageSkillsOf('en'), <String, String>{
      for (final key in allKnow) key.id: 'know',
    });
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

  test('Spanish learned: Speak and Hear Learn, the Latin script Know', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    expect(state.skillShape(hi).any((k) => k.script == 'latin'), isFalse);
    expect(state.skillsOf(hi).held.where((k) => k.script == 'latin'), isEmpty);
    final skills = state.skillsOf(es);
    expect(skills.stateOf(const SkillKey(SkillKind.speak)), SkillState.learn);
    for (final kind in const <SkillKind>[SkillKind.read, SkillKind.write]) {
      expect(skills.stateOf(SkillKey(kind, 'latin')), SkillState.know);
    }
  });

  test('a saved Learn of the Latin script becomes Know once, and a later '
      'hand-set Learn is kept', () {
    final state = stateWith(
      SettingsNotifier(
        spokenLanguages: const <String>['hi'],
        learningLanguages: const <String>['es'],
        learningChosen: true,
      ),
    );
    state.settings.setLanguageSkills('es', const <String, String>{
      'speak': 'learn',
      'hear': 'learn',
      'read:latin': 'learn',
      'write:latin': 'learn',
    });
    state.ensureLatinKnown();
    var skills = state.skillsOf(es);
    expect(skills.stateOf(const SkillKey(SkillKind.speak)), SkillState.learn);
    expect(
      skills.stateOf(const SkillKey(SkillKind.read, 'latin')),
      SkillState.know,
    );
    state.applySkills(
      es,
      skills.withState(
        const SkillKey(SkillKind.write, 'latin'),
        SkillState.learn,
      ),
    );
    state.ensureLatinKnown();
    skills = state.skillsOf(es);
    expect(
      skills.stateOf(const SkillKey(SkillKind.write, 'latin')),
      SkillState.learn,
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
    expect(state.skillsOf(en), englishKnownByDefault());
  });
}
