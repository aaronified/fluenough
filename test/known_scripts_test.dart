// Every script a learner knows or learns shows on a card (owner, 2026-11-22):
// the main text in the script they learn, the others they read beneath it.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/two_script_course.dart';

const String _dev = 'devanagari';
const String _pa = 'perso_arabic';

Future<AppState> _learner({
  Set<String>? learns,
  Set<String> reads = const <String>{},
}) async {
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi'],
    learningChosen: true,
    scriptsLearned: <String, Set<String>>{'hi': ?learns},
  );
  if (reads.isNotEmpty) {
    settings.scriptsRead = <String, bool>{
      for (final script in reads) 'hi:$script': true,
    };
  }
  final state = AppState.test(
    decks: MemoryDeckSource(twoScriptCourse()),
    settings: settings,
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

void main() {
  group('other spellings of a card', () {
    test('learns Perso-Arabic and reads Devanagari: Perso-Arabic is main, '
        'Devanagari is the smaller line', () async {
      final state = await _learner(learns: {_pa}, reads: {_dev});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'کتاب');
      final under = state.otherSpellings(card, words.language);
      expect(under.map((s) => s.text), <String>['किताब']);
      expect(under.single.language.script, _dev);
    });

    test('learns Devanagari and reads Perso-Arabic: Perso-Arabic is the '
        'smaller line', () async {
      final state = await _learner(learns: {_dev}, reads: {_pa});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'किताब');
      final under = state.otherSpellings(card, words.language);
      expect(under.map((s) => s.text), <String>['کتاب']);
      expect(under.single.language.script, _pa);
    });

    test('learns both: each shown once, none twice', () async {
      final state = await _learner(learns: {_dev, _pa});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'किताब');
      final under = state.otherSpellings(card, words.language);
      expect(under.map((s) => s.text), <String>['کتاب']);
    });

    test('knows only the primary script and learns none: unchanged', () async {
      final state = await _learner(reads: {_dev});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      expect(state.targetShown(card, words.language).text, 'किताब');
      expect(state.otherSpellings(card, words.language), isEmpty);
    });

    test('learns Perso-Arabic and reads nothing else: no line for a script '
        'neither known nor learned', () async {
      final state = await _learner(learns: {_pa});
      final words = state.deckById('hi-en-words')!;
      expect(state.otherSpellings(words.cards.first, words.language), isEmpty);
    });

    test('a card without the spelling falls back to its target, with no '
        'other line', () async {
      final state = await _learner(learns: {_pa}, reads: {_dev});
      final words = state.deckById('hi-en-words')!;
      final house = words.cards.last;
      expect(state.targetShown(house, words.language).text, 'घर');
      expect(state.otherSpellings(house, words.language), isEmpty);
    });
  });

  group('a card on screen', () {
    testWidgets('shows both scripts at 1.4x text with no overflow', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await _learner(learns: {_pa}, reads: {_dev});
      final words = state.deckById('hi-en-words')!;
      final card = words.cards.first;
      await pumpScreen(
        tester,
        TargetText.card(
          card.target,
          language: words.language,
          fontSize: 28,
          card: card,
        ),
        state: state,
      );
      expect(find.text('کتاب'), findsOneWidget);
      expect(find.text('किताब'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
