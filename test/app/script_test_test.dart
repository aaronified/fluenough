import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/script_test.dart';
import 'package:fluenough/app/settings.dart';

/// "How well do you know the script" (#554), on the bundled decks.
void main() {
  late AppState state;

  setUpAll(() async {
    state = AppState.test(
      settings: SettingsNotifier(spokenLanguages: const <String>['en', 'bn']),
    );
    await state.load();
  });

  List<DeckEntry> lessons(String code) =>
      state.scriptLessons(code, native: 'en');

  test("Assamese's script lessons are its script decks, not spelling or "
      'reading', () {
    final ids = <String>[for (final e in lessons('as')) e.id];
    expect(ids, contains('as-en-script-consonants'));
    expect(ids, contains('as-en-script-conjuncts'));
    expect(ids.any((id) => id.contains('spelling')), isFalse);
    expect(ids.any((id) => id.contains('aitar')), isFalse);
  });

  test('the test always asks ৰ and ৱ, among letters and conjuncts', () {
    for (var seed = 0; seed < 20; seed++) {
      final test = ScriptTest(lessons('as'), random: Random(seed));
      final asked = <String>[for (final q in test.questions) q.card.target];
      expect(asked, containsAll(<String>['ৰ', 'ৱ']), reason: 'seed $seed');
      expect(asked.toSet().length, asked.length);
      expect(asked.length, 8);
      final decks = <String>{for (final q in test.questions) q.card.deckId};
      expect(decks, contains('as-en-script-conjuncts'), reason: 'seed $seed');
      for (final q in test.questions) {
        expect(q.options, contains(q.card.native));
        expect(q.options.toSet().length, q.options.length);
      }
    }
  });

  test('all right passes; one wrong fails', () {
    for (final wrong in <int>[0, 1]) {
      final test = ScriptTest(lessons('as'), random: Random(3));
      var missed = 0;
      while (!test.isFinished) {
        final q = test.question!;
        final own = q.card.tags.contains(ownLetterTag);
        if (!own && missed < wrong) {
          missed++;
          test.answer(null);
        } else {
          test.answer(q.card.native);
        }
      }
      expect(test.passed, wrong == 0, reason: '$wrong wrong');
      expect(test.right, 8 - wrong);
    }
  });

  test('an own letter wrong fails, whatever else is right', () {
    final test = ScriptTest(lessons('as'), random: Random(5));
    while (!test.isFinished) {
      final q = test.question!;
      test.answer(q.card.target == 'ৱ' ? null : q.card.native);
    }
    expect(test.right, 7);
    expect(test.passed, isFalse);
  });

  test('passed, the script lessons are skipped; failed, they stay', () {
    expect(state.scriptLessonsSkipped('as', native: 'en'), isFalse);
    state.skipScriptLessons('as', true, native: 'en');
    expect(state.scriptLessonsSkipped('as', native: 'en'), isTrue);
    for (final entry in lessons('as')) {
      expect(state.isPlaced(entry), isTrue);
    }
    expect(state.scriptLearned('as'), isTrue);
    state.skipScriptLessons('as', false, native: 'en');
    expect(state.scriptLessonsSkipped('as', native: 'en'), isFalse);
    expect(state.settings.placedDecks, isEmpty);
    // Neither touches whether the course is learned in its script.
    expect(state.settings.learnsAlphabet('as'), isTrue);
  });

  test('Telugu has no own letters: its test asks its script alone', () {
    final te = lessons('te');
    expect(te, isNotEmpty);
    final test = ScriptTest(te, random: Random(1));
    expect(
      test.questions.where((q) => q.card.tags.contains(ownLetterTag)),
      isEmpty,
    );
  });
}
