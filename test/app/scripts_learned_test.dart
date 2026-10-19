import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';

import '../support/two_script_course.dart';

/// The scripts a language is learned in, one set per language (#623): kept,
/// restored, and read from the old yes or no.

const String devanagari = 'devanagari';
const String persoArabic = 'perso_arabic';

Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
  for (final unit in units)
    for (final entry in unit) entry.id,
};

Future<AppState> hindustani(Set<String>? scripts) async {
  final state = AppState.test(
    decks: MemoryDeckSource(twoScriptCourse()),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'hi': ?scripts},
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

void main() {
  group('settings', () {
    test('without a choice, the primary script follows the old yes or no', () {
      final learns = SettingsNotifier();
      expect(learns.scriptsLearned('hi', primary: devanagari), <String>{
        devanagari,
      });
      final without = SettingsNotifier(noAlphabet: const <String>{'hi'});
      expect(without.scriptsLearned('hi', primary: devanagari), isEmpty);
      expect(without.hasScriptsChosen('hi'), isFalse);
    });

    test('Perso-Arabic alone is learning the alphabet, and none is not', () {
      final s = SettingsNotifier()
        ..setScriptsLearned('hi', <String>{persoArabic});
      expect(s.scriptsLearned('hi', primary: devanagari), <String>{
        persoArabic,
      });
      expect(s.learnsAlphabet('hi'), isTrue);
      s.setScriptsLearned('hi', const <String>{});
      expect(s.learnsAlphabet('hi'), isFalse);
      expect(s.noAlphabet, <String>{'hi'});
      s.setScriptsLearned('hi', <String>{devanagari, persoArabic});
      expect(s.noAlphabet, isEmpty);
    });

    test('the old setter forgets the choice', () {
      final s = SettingsNotifier()
        ..setScriptsLearned('hi', <String>{persoArabic})
        ..setLearnsAlphabet('hi', true);
      expect(s.hasScriptsChosen('hi'), isFalse);
      expect(s.scriptsLearned('hi', primary: devanagari), <String>{devanagari});
    });

    test('the choice survives toStored and restore', () {
      final s = SettingsNotifier()
        ..setScriptsLearned('hi', <String>{devanagari, persoArabic})
        ..setScriptsLearned('bn', const <String>{});
      final restored = SettingsNotifier()..restore(s.toStored());
      expect(restored.scriptsLearned('hi', primary: devanagari), <String>{
        devanagari,
        persoArabic,
      });
      expect(restored.scriptsLearned('bn', primary: 'bengali'), isEmpty);
      expect(restored.toStored(), s.toStored());
    });

    test('settings stored before it migrate from no_alphabet', () {
      final old = SettingsNotifier()
        ..restore(const <String, String>{'no_alphabet': 'hi'});
      expect(old.scriptsLearned('hi', primary: devanagari), isEmpty);
      expect(old.scriptsLearned('bn', primary: 'bengali'), <String>{'bengali'});
      expect(old.hasScriptsChosen('hi'), isFalse);
    });
  });

  group('script decks', () {
    test('by default only the primary script is learned', () async {
      final state = await hindustani(null);
      expect(decksOf(state.courseUnits('hi')), <String>{
        'hi-en-letters',
        'hi-en-words',
      });
    });

    test('a Devanagari reader learning Perso-Arabic skips Devanagari '
        'units and gets the Perso-Arabic ones', () async {
      final state = await hindustani(<String>{persoArabic});
      expect(decksOf(state.courseUnits('hi')), <String>{
        'hi-en-urdu-letters',
        'hi-en-words',
      });
      expect(state.leavesOut(state.deckById('hi-en-letters')!), isTrue);
      expect(state.leavesOut(state.deckById('hi-en-urdu-letters')!), isFalse);
    });

    test('both scripts learned keep both, none keeps neither', () async {
      final both = await hindustani(<String>{devanagari, persoArabic});
      expect(decksOf(both.courseUnits('hi')), <String>{
        'hi-en-letters',
        'hi-en-urdu-letters',
        'hi-en-words',
      });
      final none = await hindustani(const <String>{});
      expect(decksOf(none.courseUnits('hi')), <String>{'hi-en-words'});
    });
  });

  group('a card in the script learned', () {
    test('Perso-Arabic only shows it right to left, and falls back to '
        'the first script where a card has none', () async {
      final state = await hindustani(<String>{persoArabic});
      final words = state.deckById('hi-en-words')!;
      final book = state.targetShown(words.cards.first, words.language);
      expect(book.text, 'کتاب');
      expect(book.language.rtl, isTrue);
      expect(book.language.script, persoArabic);
      expect(state.otherSpellings(words.cards.first, words.language), isEmpty);
      final house = state.targetShown(words.cards.last, words.language);
      expect(house.text, 'घर');
      expect(house.language.rtl, isFalse);
    });

    test('both learned show the primary and the other beneath', () async {
      final state = await hindustani(<String>{devanagari, persoArabic});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'किताब');
      final others = state.otherSpellings(card, words.language);
      expect(others.map((o) => o.text), <String>['کتاب']);
      expect(others.single.language.rtl, isTrue);
      expect(state.otherSpellings(words.cards.last, words.language), isEmpty);
    });

    test('Devanagari only is the card as it was', () async {
      final state = await hindustani(<String>{devanagari});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'किताब');
      expect(state.otherSpellings(card, words.language), isEmpty);
    });
  });
}
