import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_choice.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/today/today_numbers.dart';

/// One language for the whole app (#461): the choice in Settings, the
/// rules for what it shows, and what Today counts under it.

AppState learning(
  List<String> languages, {
  MemoryProgress? progress,
  String? choice,
}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    languageChoice: choice,
  ),
  progress: progress,
);

/// Learning [languages], with a few words of each taught three days ago,
/// so that each has reviews due today and a lesson to come.
Future<AppState> withReviews(List<String> languages) async {
  final base = learning(languages);
  await base.load();
  final progress = MemoryProgress();
  for (final code in languages) {
    for (final card in base.untaughtCards(code).take(4)) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: base.now().subtract(const Duration(days: 3)),
      );
    }
  }
  base.dispose();
  final state = learning(languages, progress: progress);
  await state.load();
  return state;
}

Set<String> languagesIn(AppState state, DrillRequest request) => <String>{
  for (final item in state.buildSession(request).items)
    state.deckOf(item.card)!.language.code,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageChoice', () {
    test('offers the languages chosen, in their order, then the rest', () {
      expect(
        LanguageChoice.options(
          learning: const <String>['te', 'hi', 'fr'],
          available: const <String>['es', 'hi', 'te'],
        ),
        <String>['te', 'hi', 'es'],
        reason: 'fr has no deck on the phone, so nothing to show',
      );
    });

    test('shows All by default, and the one language when there is one', () {
      expect(LanguageChoice.shown(null, const <String>['hi', 'te']), isNull);
      expect(LanguageChoice.shown(null, const <String>['te']), 'te');
      expect(LanguageChoice.shown(null, const <String>[]), isNull);
    });

    test('shows the language chosen while it is offered, else All', () {
      const two = <String>['hi', 'te'];
      expect(LanguageChoice.shown('te', two), 'te');
      expect(LanguageChoice.shown('bn', two), isNull);
      expect(LanguageChoice.shown(LanguageChoice.all, two), isNull);
      // All is still a choice with one language.
      expect(
        LanguageChoice.shown(LanguageChoice.all, const <String>['te']),
        isNull,
      );
    });

    test('shows a language\'s content under All or under itself', () {
      expect(LanguageChoice.shows(null, 'hi'), isTrue);
      expect(LanguageChoice.shows('hi', 'hi'), isTrue);
      expect(LanguageChoice.shows('te', 'hi'), isFalse);
    });

    test('the stored value for All is no language code', () {
      expect(LanguageChoice.isValid(LanguageChoice.all), isTrue);
      expect(LanguageChoice.isValid('hi'), isTrue);
      expect(LanguageChoice.isValid('all'), isTrue, reason: 'Allar: a code');
      expect(LanguageChoice.all, isNot('all'));
      expect(LanguageChoice.isValid('Hindi'), isFalse);
      expect(LanguageChoice.isValid(''), isFalse);
    });
  });

  group('the setting', () {
    test('survives toStored and restore, a language or All', () {
      for (final choice in <String>['te', LanguageChoice.all]) {
        final changed = SettingsNotifier()
          ..learningLanguages = const <String>['hi', 'te']
          ..languageChoice = choice;
        expect(changed.toStored()['language_choice'], choice);
        final restored = SettingsNotifier()..restore(changed.toStored());
        expect(restored.languageChoice, choice);
        expect(restored.toStored(), changed.toStored());
      }
    });

    test('is unchosen, which shows All, when stored before #461', () {
      final old = SettingsNotifier()
        ..learningLanguages = const <String>['hi', 'te'];
      final stored = Map<String, String>.of(old.toStored())
        ..remove('language_choice');
      final restored = SettingsNotifier()..restore(stored);
      expect(restored.languageChoice, isNull);
      expect(SettingsNotifier().languageChoice, isNull, reason: 'default');
      expect(SettingsNotifier().toStored()['language_choice'], '');
    });

    test('a language no longer learned goes back to the default', () {
      final s = SettingsNotifier()
        ..learningLanguages = const <String>['hi', 'te']
        ..languageChoice = 'te';
      s.learningLanguages = const <String>['hi', 'te', 'bn'];
      expect(s.languageChoice, 'te', reason: 'still learned');
      s.learningLanguages = const <String>['hi', 'bn'];
      expect(s.languageChoice, isNull);

      s.languageChoice = LanguageChoice.all;
      s.learningLanguages = const <String>['bn'];
      expect(s.languageChoice, LanguageChoice.all, reason: 'All stays All');
    });

    test(
      'restoring a language not learned, or nonsense, keeps the default',
      () {
        final s = SettingsNotifier()
          ..restore(const <String, String>{
            'learning_languages': 'hi,te',
            'language_choice': 'bn',
          });
        expect(s.languageChoice, isNull);
        s.restore(const <String, String>{'language_choice': 'Telugu!'});
        expect(s.languageChoice, isNull);
        s.languageChoice = 'not a code';
        expect(s.languageChoice, isNull);
      },
    );
  });

  group('the app', () {
    test('offers the languages learned with decks, and shows All by '
        'default', () async {
      final state = learning(const <String>['te', 'hi']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.languageChoices.map((l) => l.code), <String>['te', 'hi']);
      expect(state.shownLanguage, isNull);
      expect(state.showsLanguage('te'), isTrue);
      expect(state.showsLanguage('hi'), isTrue);
    });

    test('with one language learned, shows it, and All can still be '
        'chosen', () async {
      final state = learning(const <String>['te']);
      addTearDown(state.dispose);
      await state.load();
      expect(state.shownLanguage, 'te');
      state.showLanguage(null);
      expect(state.settings.languageChoice, LanguageChoice.all);
      expect(state.shownLanguage, isNull);
    });

    test('falls back to All when the language shown stops being '
        'learned', () async {
      final state = learning(const <String>['bn', 'hi', 'te'], choice: 'te');
      addTearDown(state.dispose);
      await state.load();
      expect(state.shownLanguage, 'te');
      var rebuilt = 0;
      state.addListener(() => rebuilt++);
      state.setLearningLanguages(const <String>['bn', 'hi']);
      expect(state.shownLanguage, isNull);
      expect(rebuilt, greaterThan(0), reason: 'screens rebuild for it');
    });

    test('Today\'s lessons, words due, minutes and skill tiles are the '
        'shown language\'s', () async {
      final state = await withReviews(const <String>['bn', 'hi']);
      addTearDown(state.dispose);

      final all = TodayNumbers.of(state);
      expect(all.lessons.map((l) => l.language.code), <String>['bn', 'hi']);
      expect(all.languages.map((l) => l.code), <String>['bn', 'hi']);

      state.showLanguage('hi');
      final hindi = TodayNumbers.of(state);
      expect(hindi.lessons.map((l) => l.language.code), <String>['hi']);
      expect(hindi.languages.map((l) => l.code), <String>['hi']);
      expect(
        hindi.due,
        state.buildSession(const DrillRequest.today(language: 'hi')).length,
      );
      expect(hindi.due, greaterThan(0));
      expect(hindi.due, lessThan(all.due));
      expect(hindi.minutes, lessThanOrEqualTo(all.minutes));
      // What Start review drills is what the card counts.
      expect(languagesIn(state, hindi.start), <String>{'hi'});
      expect(state.buildSession(hindi.start).length, hindi.due);
      // Each tile counts, and reviews, Hindi alone.
      final recognition = Skill.recognition;
      expect(hindi.bySkill[recognition], lessThan(all.bySkill[recognition]!));
      expect(languagesIn(state, DrillRequest(skill: recognition)), <String>{
        'hi',
      });

      state.showLanguage('bn');
      final bengali = TodayNumbers.of(state);
      expect(bengali.lessons.map((l) => l.language.code), <String>['bn']);
      expect(bengali.due + hindi.due, all.due, reason: 'the parts make All');
      expect(
        bengali.bySkill[recognition]! + hindi.bySkill[recognition]!,
        all.bySkill[recognition],
      );

      state.showLanguage(null);
      final again = TodayNumbers.of(state);
      expect(again.due, all.due);
      expect(again.lessons.length, 2);
    });

    test('quick revision revises only the shown language', () async {
      final state = await withReviews(const <String>['bn', 'hi']);
      addTearDown(state.dispose);
      final everything = state.revisableCount;
      state.showLanguage('hi');
      final hindi = state.revisableCount;
      expect(hindi, greaterThan(0));
      expect(hindi, lessThan(everything));
      expect(languagesIn(state, const DrillRequest.revision(4)), <String>{
        'hi',
      });
    });

    test('where a course has got to does not depend on the language '
        'shown', () async {
      final state = await withReviews(const <String>['bn', 'hi']);
      addTearDown(state.dispose);
      final pending = <String>[
        for (final unit in state.pendingUnits) unit.first.id,
      ];
      state.showLanguage('hi');
      expect(<String>[
        for (final unit in state.pendingUnits) unit.first.id,
      ], pending);
    });
  });
}
