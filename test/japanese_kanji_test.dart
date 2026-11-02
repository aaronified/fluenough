// Japanese written in kanji (ADR-0053): a kanji deck is `script: han` with
// `scripts: [han, kana]`, its cards' kana reading their `target_scripts.kana`.
// What the app does with it is what it does for any two-script language
// (#623); these tests hold that to the Japanese case.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/japanese_kanji_course.dart';
import 'support/picker.dart';

const String kana = 'kana';
const String han = 'han';

Future<AppState> japanese(Set<String>? scripts) async {
  final state = AppState.test(
    decks: MemoryDeckSource(japaneseKanjiCourse()),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['ja'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'ja': ?scripts},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

Set<String> decksOf(AppState state) => <String>{
  for (final unit in state.courseUnits('ja'))
    for (final entry in unit) entry.id,
};

void main() {
  group('Japanese in kanji', () {
    test('the course starts in kana although most of its decks are kanji '
        'decks, and a learner of kana alone leaves the kanji script unit '
        'out', () async {
      final state = await japanese(null);
      expect(state.primaryScript('ja'), kana);
      expect(state.learnedScripts(state.deckById('ja-en-words')!.language), [
        kana,
      ]);
      expect(decksOf(state), <String>{'ja-en-hiragana', 'ja-en-words'});
    });

    test('a learner of kana alone sees the kana of a kanji card, and a word '
        'already in kana as it is', () async {
      final state = await japanese(<String>{kana});
      final words = state.deckById('ja-en-words')!;
      final eat = state.targetShown(words.cards.first, words.language);
      expect(eat.text, 'たべる');
      expect(eat.language.script, kana);
      expect(state.otherSpellings(words.cards.first, words.language), isEmpty);
      final thanks = state.targetShown(words.cards.last, words.language);
      expect(thanks.text, 'ありがとう');
    });

    test('a learner of kana and kanji sees the kanji with its kana reading '
        'under it, and the kanji script unit', () async {
      final state = await japanese(<String>{kana, han});
      final words = state.deckById('ja-en-words')!;
      final eat = state.targetShown(words.cards.first, words.language);
      expect(eat.text, '食べる');
      expect(eat.language.script, han);
      final under = state.otherSpellings(words.cards.first, words.language);
      expect(under.map((s) => s.text), ['たべる']);
      expect(under.single.language.script, kana);
      expect(state.otherSpellings(words.cards.last, words.language), isEmpty);
      expect(decksOf(state), contains('ja-en-kanji-1'));
    });

    test('the kana reading is the card\'s second spelling and the romaji '
        'reading stays', () async {
      final state = await japanese(<String>{kana, han});
      final eat = state.deckById('ja-en-words')!.cards.first;
      expect(eat.target, '食べる');
      expect(eat.targetScripts, <String, String>{kana: 'たべる'});
      expect(eat.reading, 'taberu');
      expect(eat.targetIn(kana, firstScript: han), 'たべる');
      expect(eat.targetIn(han, firstScript: han), '食べる');
    });

    test('a typed answer is graded in the script written, and kanji is '
        'accepted in either', () async {
      final state = await japanese(<String>{kana, han});
      final eat = state.deckById('ja-en-words')!.cards.first;
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(card: eat, mode: DrillMode.production, state: null),
        ],
      );
      addTearDown(session.dispose);
      expect(session.writeScripts, [kana, han]);

      session.chooseScript(han);
      expect(session.acceptedAnswers.first, '食べる');
      // Kanji grades kanji only: the kana is not an answer.
      expect(session.acceptedAnswers, isNot(contains('たべる')));

      session.chooseScript(kana);
      expect(session.acceptedAnswers.first, 'たべる');
      expect(session.acceptedAnswers, contains('食べる'));
    });
  });

  group('Japanese example sentences in kanji', () {
    test(
      'an example keeps its kana line, and the romaji reading stays',
      () async {
        final state = await japanese(<String>{kana, han});
        final eat = state.deckById('ja-en-words')!.cards.first;
        final example = eat.examples.single;
        expect(example.target, '私は食べます。');
        expect(example.targetScripts, <String, String>{kana: 'わたしはたべます。'});
        expect(example.reading, 'watashi wa tabemasu.');
        expect(example.targetIn(kana, firstScript: han), 'わたしはたべます。');
      },
    );

    test('a learner of kana and kanji sees the kanji with the kana line '
        'under it', () async {
      final state = await japanese(<String>{kana, han});
      final words = state.deckById('ja-en-words')!;
      final example = words.cards.first.examples.single;
      expect(state.exampleShown(example, words.language).text, '私は食べます。');
      final under = state.exampleOtherSpellings(example, words.language);
      expect(under.map((s) => s.text), ['わたしはたべます。']);
      expect(under.single.language.script, kana);
    });

    test(
      'a learner of kana alone sees the kana line, and no second one',
      () async {
        final state = await japanese(<String>{kana});
        final words = state.deckById('ja-en-words')!;
        final example = words.cards.first.examples.single;
        final shown = state.exampleShown(example, words.language);
        expect(shown.text, 'わたしはたべます。');
        expect(shown.language.script, kana);
        expect(state.exampleOtherSpellings(example, words.language), isEmpty);
      },
    );
  });

  group('Japanese skills and placement', () {
    test('kana and kanji each have a Read and a Write pill, kanji named as '
        'kanji', () {
      final ja = pickerSpokenList.firstWhere((l) => l.code == 'ja');
      expect(AppState.test().skillShape(ja), const <SkillKey>[
        SkillKey(SkillKind.speak),
        SkillKey(SkillKind.hear),
        SkillKey(SkillKind.read, 'kana'),
        SkillKey(SkillKind.read, 'han'),
        SkillKey(SkillKind.write, 'kana'),
        SkillKey(SkillKind.write, 'han'),
      ]);
    });

    test('the script check asks about kana, then kanji', () async {
      final state = await japanese(<String>{kana, han});
      expect(state.placementScripts('ja').map((s) => s.script), [kana, han]);
    });

    test('the kanji check asks only words with a kanji, the kana check '
        'every word', () async {
      final state = await japanese(<String>{kana, han});
      final scripts = {
        for (final s in state.placementScripts('ja'))
          s.script: s.words.map((w) => w.spelling).toList(),
      };
      expect(scripts[han], ['食べる']);
      expect(scripts[kana], containsAll(['たべる', 'ありがとう']));
      expect(scripts[kana], isNot(contains('食べる')));
    });
  });
}
