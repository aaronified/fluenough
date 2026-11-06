// "IPA replaces transliteration" (#697), on the screens that drew a
// transliteration of their own: with IPA on and the switch on, the reading
// line is the IPA; with the switch off it is the transliteration. Telugu is
// the frozen fixture course, learned without its script so that readings show.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/why_closed_sheet.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _grammarDeck = 'te-en-grammar-past';
const String _wordsDeck = 'te-en-family';

AppState _learner({required bool replaces}) {
  final state = AppState.test(
    decks: RepositoryDeckSource('test/fixtures/ask_pin'),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['te'],
      learningChosen: true,
      scriptsLearned: <String, Set<String>>{'te': <String>{}},
    )..ipaReplacesReading = replaces,
  );
  addTearDown(state.dispose);
  return state;
}

/// A phone tall enough for the unit's lazy list to build every row.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
}

void main() {
  group('the grammar drill, a language learned without its script', () {
    Future<void> pumpGrammar(
      WidgetTester tester, {
      required bool replaces,
    }) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(_grammarDeck, skill: Skill.grammar),
        ),
        state: _learner(replaces: replaces),
      );
    }

    testWidgets('switch off: the prompt is the transliteration, with the IPA '
        'on its small line', (tester) async {
      await pumpGrammar(tester, replaces: false);
      expect(find.text('cēyaḍam (to do) — నేను'), findsOneWidget);
      expect(find.text('/tʃeːjaɖam/'), findsOneWidget);
    });

    testWidgets('switch on: the prompt is the IPA, left to right, and the '
        'transliteration and the small line are gone', (tester) async {
      await pumpGrammar(tester, replaces: true);
      final prompt = find.text('/tʃeːjaɖam/ (to do) — నేను');
      expect(prompt, findsOneWidget);
      expect(tester.widget<Text>(prompt).textDirection, TextDirection.ltr);
      expect(find.textContaining('cēyaḍam'), findsNothing);
      expect(find.text('/tʃeːjaɖam/'), findsNothing);
    });
  });

  group('the word rows of a unit page', () {
    Future<(String, String)> pumpUnit(
      WidgetTester tester, {
      required bool replaces,
    }) async {
      useTallPhone(tester);
      final state = _learner(replaces: replaces);
      await state.load();
      final card = state.deckById(_wordsDeck)!.cards.first;
      expect(card.reading, isNotNull);
      expect(card.ipa, isNotNull);
      await pumpScreen(
        tester,
        const UnitPage(deckId: _wordsDeck),
        state: state,
      );
      return (card.reading!, '/${card.ipa}/');
    }

    Future<void> scrollTo(WidgetTester tester, Finder what) async {
      for (var i = 0; i < 40 && what.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
      }
    }

    testWidgets('switch off: a word shows its transliteration, not its IPA', (
      tester,
    ) async {
      final (reading, ipa) = await pumpUnit(tester, replaces: false);
      await scrollTo(tester, find.text(reading));
      expect(find.text(reading), findsWidgets);
      expect(find.text(ipa), findsNothing);
    });

    testWidgets('switch on: a word shows its IPA, not its transliteration', (
      tester,
    ) async {
      final (reading, ipa) = await pumpUnit(tester, replaces: true);
      await scrollTo(tester, find.text(ipa));
      expect(find.text(ipa), findsWidgets);
      expect(find.text(reading), findsNothing);
    });
  });

  group('the sheet that says why a sentence is closed', () {
    Future<(String, String)> pumpSheet(
      WidgetTester tester, {
      required bool replaces,
    }) async {
      usePhone(tester);
      final state = _learner(replaces: replaces);
      await state.load();
      final entry = state.deckById(_wordsDeck)!;
      final card = entry.cards.first;
      await pumpScreen(
        tester,
        Scaffold(
          body: WhyClosedSheet(card: card, language: entry.language),
        ),
        state: state,
      );
      return (card.reading!, '/${card.ipa}/');
    }

    testWidgets('switch off: the card\'s transliteration', (tester) async {
      final (reading, ipa) = await pumpSheet(tester, replaces: false);
      expect(find.text(reading), findsOneWidget);
      expect(find.text(ipa), findsNothing);
    });

    testWidgets('switch on: the card\'s IPA in its place', (tester) async {
      final (reading, ipa) = await pumpSheet(tester, replaces: true);
      expect(find.text(ipa), findsOneWidget);
      expect(find.text(reading), findsNothing);
    });
  });
}
