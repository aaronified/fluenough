// Split out of languages_and_scripts_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: placement, placement in the review's screen, placement offered after Learn on the first launch, Start at the beginning, in the offer after Learn, placement asks nothing the pills have said, placement in the learner's scripts, placement's written questions, placement's form questions, placement's read-aloud question, the script check, the deck walk, Find my level, placement credits what it found.

import 'dart:math';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement.dart';
import 'package:fluenough/app/placement_credit.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/models/card.dart' as model;
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/placed_review.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/choice_tile.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart' show WordTile;
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/onboarding_placement.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/placement/placement_questions.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/mode_pill.dart';
import 'package:fluenough/ui/widgets/reading_first.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'support/harness.dart';
import 'support/picker.dart';
import 'support/two_script_course.dart';
import 'support/languages_and_scripts_shared.dart';

// From placement_flow_test.dart.
/// Choosing what to learn and placement (#117, ADR-0013), from first launch
/// and from Settings.

/// The app on first launch after the languages the learner speaks, on the
/// bundled decks unless [decks] is given.
Future<AppState> pumpFirstLaunch(
  WidgetTester tester, {
  DeckSource? decks,
}) async {
  final state = AppState.test(
    decks: decks,
    settings: SettingsNotifier(spokenLanguages: const <String>['en']),
  );
  addTearDown(state.dispose);
  await tester.pumpWidget(
    withLanguageList(FluenoughApp(key: UniqueKey(), state: state)),
  );
  await tester.pumpAndSettle();
  return state;
}

/// Ends placement from the header's close button, keeping what it found.
Future<void> stopPlacement(WidgetTester tester) async {
  await tester.tap(find.byTooltip(l10nOf(tester).drillEndSession));
  await tester.pumpAndSettle();
}

/// Puts the sentence on screen in order, tile by tile, and checks it.
Future<void> answerTiles(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  final shown = tester.widget<PlacementTiles>(find.byType(PlacementTiles));
  final q = shown.question;
  final latin = shown.latin && q.readingTiles != null;
  final right = latin
      ? model.tilesOf(q.card.reading!)
      : q.card.tilesOfSpelling(shown.spelling);
  final tiles = latin ? q.readingTiles! : q.tilesOfSpelling(shown.spelling);
  final used = <int>{};
  for (final word in right) {
    final at = <int>[
      for (var i = 0; i < tiles.length; i++)
        if (tiles[i] == word && !used.contains(i)) i,
    ].first;
    used.add(at);
    final pool = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is Wrap && w.alignment == WrapAlignment.center,
      ),
      matching: find.byType(WordTile),
    );
    await tapInFrame(tester, pool.at(at));
  }
  await tapInFrame(tester, find.widgetWithText(FilledButton, l10n.drillCheck));
  await goOn(tester);
}

/// Answers the placement question on screen, of whatever kind: rightly,
/// or with "I don't know".
Future<void> answerShown(WidgetTester tester, {bool right = true}) async {
  final l10n = l10nOf(tester);
  if (!right) {
    await tapInFrame(tester, find.text(l10n.placementDontKnow));
    return goOn(tester);
  }
  Future<void> tap(Finder f) => tapInFrame(tester, f);
  if (find.byType(PlacementTiles).evaluate().isNotEmpty) {
    return answerTiles(tester);
  }

  final match = find.byType(PlacementMatch);
  if (match.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementMatch>(match).question;
    for (final (i, card) in q.cards.indexed) {
      await tap(find.byKey(ValueKey<String>('match-left-$i')));
      final j = q.answers.indexOf(card.native);
      await tap(find.byKey(ValueKey<String>('match-right-$j')));
    }
    return tap(find.widgetWithText(FilledButton, l10n.placementCheck));
  }
  final typed = find.byType(PlacementType);
  if (typed.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementType>(typed).question;
    await tester.enterText(
      find.byKey(const ValueKey<String>('placement-answer')),
      q.produce ? q.card.target : q.card.reading!,
    );
    await tester.pumpAndSettle();
    return tap(find.widgetWithText(FilledButton, l10n.placementCheck));
  }
  final hear = find.byType(PlacementHear);
  if (hear.evaluate().isNotEmpty) {
    final q = tester.widget<PlacementHear>(hear).question;
    return tap(find.byKey(ValueKey<String>('hear-option-${q.answer}')));
  }
  final q = tester
      .widget<PlacementChoice>(find.byType(PlacementChoice))
      .question;
  // The options are shuffled, so the right one may sit below the fold.
  await tap(
    find.descendant(of: find.byType(ChoiceTile), matching: find.text(q.answer)),
  );
  return goOn(tester);
}

/// Whether a placement question is on screen.
bool questionShown() =>
    find.byType(PlacementChoice).evaluate().isNotEmpty ||
    find.byType(PlacementTiles).evaluate().isNotEmpty ||
    find.byType(PlacementMatch).evaluate().isNotEmpty ||
    find.byType(PlacementType).evaluate().isNotEmpty ||
    find.byType(PlacementHear).evaluate().isNotEmpty ||
    find.byType(PlacementSay).evaluate().isNotEmpty;

// From placement_test.dart.
/// Placement (#117, ADR-0013) on the bundled Hindi course.

// From languages_learning_fixes_test.dart.
/// What the review of #633 asked for in Languages I'm learning (#626): a
/// language the learner speaks is placed, a learned language can stop a
/// script, "Find my level" keeps a passed script test, and a chosen
/// language's choices survive closing its sheet.

/// A learner who speaks [spoken], learning [learning] (none chosen yet when
/// empty).
Future<AppState> pumpPickerLanguagesLearningFixes(
  WidgetTester tester, {
  List<String> spoken = const <String>['en'],
  List<String> learning = const <String>[],
  Set<String> noAlphabet = const <String>{},
}) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
  final state = AppState.test(
    settings: SettingsNotifier(
      spokenLanguages: spoken,
      learningLanguages: learning,
      learningChosen: learning.isNotEmpty,
      noAlphabet: noAlphabet,
    ),
  );
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    KeyedSubtree(
      key: UniqueKey(),
      child: LanguagePickerPage(
        firstRun: learning.isEmpty,
        spokenList: pickerSpokenList,
      ),
    ),
    state: state,
  );
  return state;
}

// From scripts_learned_test.dart.
/// The scripts a language is learned in, one set per language (#623): kept,
/// restored, and read from the old yes or no.

const String devanagari = 'devanagari';

const LanguageInfo telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

// Placement in the learner's scripts (owner, 2026-10-20).
/// A Marathi speaker who reads its script, Devanagari, learning the tiny
/// two-script Hindustani course in [scripts] (none: without its alphabet),
/// or as [reads] says when they do not read it.
AppState devanagariReader(Set<String> scripts, {bool reads = true}) =>
    AppState.test(
      decks: MemoryDeckSource(<String, String>{
        ...twoScriptCourse(),
        'decks/mr/mr-en-words.yaml': '''
schema: 1
id: mr-en-words
name: "Words"
language: { code: mr, iso639_3: mar, name: Marathi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: mr-en-words-0001, target: "घर", native: "house", reading: "ghar" }
''',
      }),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en', 'mr'],
        learningLanguages: const <String>['hi'],
        learningChosen: true,
        noAlphabet: <String>{if (scripts.isEmpty) 'hi'},
        scriptsLearned: <String, Set<String>>{'hi': scripts},
      )..scriptsRead = <String, bool>{'en': true, 'mr': reads},
    );

/// Answers each placement question on screen rightly, after [check] has
/// looked at the card each word question shows. A script is checked where
/// the learner's pills say they read it.
Future<void> placeAll(
  WidgetTester tester,
  void Function(model.Card card) check,
) async {
  final l10n = l10nOf(tester);
  var guard = 0;
  var words = 0;
  while (guard++ < 40) {
    if (!questionShown()) break;
    if (find.text(l10n.placementQuestion).evaluate().isNotEmpty) {
      words++;
      check(tester.widget<TargetText>(find.byType(TargetText)).card!);
    }
    await answerShown(tester);
  }
  expect(words, greaterThan(0), reason: 'placement asked a word');
}

/// The [word] on screen as written: a long word on a drill card is drawn
/// with breaks between its aksharas (#515), and keeps the word as its
/// semantics label.
Finder shownWord(String word) => find.byWidgetPredicate(
  (w) => w is Text && (w.data == word || w.semanticsLabel == word),
);

Future<void> pumpPlacement(WidgetTester tester, AppState state) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    // As Find my level opens it, from Languages I'm learning.
    PlacementPage(
      languages: const <String>['hi'],
      alphabet: <String, bool>{'hi': state.settings.learnsAlphabet('hi')},
      random: Random(1),
      onFinished: (_) {},
    ),
    state: state,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The picker reads assets/languages.yaml through the asset bundle, which
  // keeps what it read, and a widget test does not wait for real time. So
  // whether a test got the list depended on which tests ran before it in its
  // CI shard: a read left half done by an earlier test, or the 100 ms a
  // helper waits for a read of its own. Read once here, in real time, and
  // every test finds the finished read in the cache, in any order.
  setUpAll(() => rootBundle.loadString(spokenLanguagesAsset));

  group('placement', () {
    testWidgets(
      'first launch asks what to learn; Find my level asks nothing more: a '
      'script the pills do not say is read is new, and the walk places the '
      'decks known',
      (tester) async {
        usePhone(tester);
        final state = await pumpFirstLaunch(tester);
        final l10n = l10nOf(tester);

        expect(find.text(l10n.learnTitle), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        final go = find.widgetWithText(FilledButton, l10n.commonContinue);
        expect(tester.widget<FilledButton>(go).onPressed, isNull);

        // Where to start is asked in the language's sheet (#626): from the
        // beginning, so placement has nothing to ask.
        await pickLanguage(tester, 'hi', begin: true);
        expect(isPicked(tester, 'hi'), isTrue);
        await tester.tap(go);
        await tester.pumpAndSettle();
        expect(find.byType(PlacementPage), findsNothing);
        expect(find.byType(AppShell), findsOneWidget);
        expect(state.settings.learningLanguages, <String>['hi']);
        expect(state.settings.learningChosen, isTrue);
        expect(state.settings.placedDecks, isEmpty);
        expect(state.currentProfile.learns('bn'), isFalse);

        {
          usePhone(tester);
          final state = await pumpFirstLaunch(tester);
          final l10n = l10nOf(tester);
          final decks = state.walkDecks('hi');
          final askable = DeckWalk(decks).askableDecks;

          await pickLanguage(tester, 'hi');
          await tapText(tester, l10n.commonContinue);
          // The learner has said they read neither script, so each is
          // placed as new with no question, and the walk begins at once.
          expect(find.byType(PlacementPage), findsOneWidget);

          // The walk: each question numbered, with no total.
          expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);
          await answerShown(tester);
          await answerShown(tester, right: false);
          // A miss gets a second question from the same deck.
          expect(find.text(l10n.placementQuestionNumber(3)), findsOneWidget);
          await answerShown(tester, right: false);

          for (final script in <String>[devanagari, persoArabic]) {
            expect(
              find.text(l10n.placementScriptNew(l10n.scriptName(script))),
              findsOneWidget,
            );
          }
          expect(
            find.text(
              l10n.placementWordsMissed(
                decks[askable[1] - 1].deck.name,
                decks[askable[1]].deck.name,
              ),
            ),
            findsOneWidget,
          );
          await tapText(tester, l10n.placementDone);
          expect(state.settings.placedDecks, <String>{
            for (final e in decks.take(askable[1])) e.id,
          });
          // The scripts chosen to learn stay learned, though new.
          expect(
            state.settings.scriptsLearned('hi', primary: devanagari),
            <String>{devanagari, persoArabic},
          );
        }
      },
    );

    testWidgets('Stop here keeps what placement found; leaving part-way saves '
        'nothing', (tester) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);
      final script = state.placementScripts('hi').first;
      // Devanagari is read, as its pill says.
      state.settings.scriptsRead = <String, bool>{'en': true, 'hi': true};

      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      await answerShown(tester);
      await stopPlacement(tester);
      expect(
        find.text(l10n.placementScriptLetters(l10n.scriptName(devanagari))),
        findsOneWidget,
      );
      expect(find.text(l10n.placementTryAgain), findsNothing);
      await tapText(tester, l10n.placementDone);
      expect(
        state.settings.placedDecks,
        ScriptCheck.placedFor(script.decks, ScriptStanding.letters),
      );
      expect(state.settings.placedDecks, isNotEmpty);

      {
        usePhone(tester);
        final state = await pumpFirstLaunch(tester);
        state.settings.scriptsRead = <String, bool>{'en': true, 'hi': true};
        final l10n = l10nOf(tester);
        await pickLanguage(tester, 'hi');
        await tapText(tester, l10n.commonContinue);
        await answerShown(tester);
        // The phone's Back: a question has no bar of its own to go back by.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePickerPage), findsOneWidget);
        expect(state.settings.learningChosen, isFalse);
        expect(state.settings.learningLanguages, isEmpty);
        expect(state.settings.placedDecks, isEmpty);
      }
    });

    testWidgets('Try again from here starts the walk where it landed, and is '
        'offered again only while a try gets at least a deck further', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);
      final decks = state.walkDecks('hi');
      final askable = DeckWalk(decks).askableDecks;
      Set<String> before(int deck) => <String>{
        for (final e in decks.take(deck)) e.id,
      };

      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      await answerShown(tester);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(
        find.text(l10n.placementTryAgainNote(decks[askable[1]].deck.name)),
        findsOneWidget,
      );

      // From there: one deck further.
      await tapText(tester, l10n.placementTryAgain);
      expect(find.text(l10n.placementQuestionNumber(4)), findsOneWidget);
      await answerShown(tester);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(find.text(l10n.placementNoFurther), findsNothing);
      expect(find.text(l10n.placementTryAgain), findsOneWidget);

      // From there again: no further, so this is where the learner starts.
      await tapText(tester, l10n.placementTryAgain);
      await answerShown(tester, right: false);
      await answerShown(tester, right: false);
      expect(find.text(l10n.placementNoFurther), findsOneWidget);
      expect(find.text(l10n.placementTryAgain), findsNothing);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placedDecks, before(askable[2]));
    });

    testWidgets('the end of placement asks how the placed words are reviewed, '
        'Spot-check picked, and keeps the choice for the course', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      state.settings.scriptsRead = <String, bool>{'en': true, 'hi': true};
      final l10n = l10nOf(tester);

      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      await answerShown(tester);
      await stopPlacement(tester);
      expect(find.text(l10n.placedReviewQuestion), findsOneWidget);
      expect(
        find.textContaining(l10n.placedReviewDefault, findRichText: true),
        findsOneWidget,
      );
      // Nothing changed: the default is what is saved.
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placedReviewOf('hi'), PlacedReview.spotCheck);
      expect(state.settings.placedAtOf('hi'), isNotEmpty);

      {
        usePhone(tester);
        final state = await pumpFirstLaunch(tester);
        state.settings.scriptsRead = <String, bool>{'en': true, 'hi': true};
        final l10n = l10nOf(tester);
        await pickLanguage(tester, 'hi');
        await tapText(tester, l10n.commonContinue);
        await answerShown(tester);
        await stopPlacement(tester);
        await tapText(tester, l10n.placedReviewSetInStone);
        await tapText(tester, l10n.placementDone);
        expect(state.settings.placedReviewOf('hi'), PlacedReview.setInStone);
      }
    });

    testWidgets('two languages are placed one after the other', (tester) async {
      usePhone(tester);
      final state = await pumpFirstLaunch(tester);
      final l10n = l10nOf(tester);

      // Found by search, not by scrolling: where a row sits in the full list
      // changes with every course written.
      await searchPicker(tester, 'Hindustani');
      await pickLanguage(tester, 'hi');
      await searchPicker(tester, 'Bengali');
      await pickLanguage(tester, 'bn');
      await tapText(tester, l10n.commonContinue);
      // In the catalog's order, starting at once: "Find my level" was chosen
      // in each sheet.
      expect(find.byType(PlacementPage), findsOneWidget);
      await giveUp(tester);
      await tapText(tester, l10n.placementNext);
      expect(find.byType(PlacementPage), findsOneWidget);
      await giveUp(tester);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.learningLanguages, <String>['bn', 'hi']);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets(
      'the owner\'s example: learning Hindustani for its Perso-Arabic, '
      'reading Devanagari through Hindi and knowing every word, the learner '
      'is placed in under 20 questions: Devanagari read, Perso-Arabic taught, '
      'the words placed to the end',
      (tester) async {
        usePhone(tester);
        final state = AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en', 'hi'],
            learningLanguages: const <String>['hi'],
            learningChosen: true,
            scriptsLearned: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
          )..scriptsRead = <String, bool>{'en': true, 'hi': true},
        );
        addTearDown(state.dispose);
        PlacementFound? found;
        await pumpScreen(
          tester,
          PlacementPage(
            languages: const <String>['hi'],
            alphabet: const <String, bool>{'hi': true},
            scripts: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
            languageNames: const <String, String>{'hi': 'Hindi'},
            random: Random(3),
            onFinished: (f) => found = f,
          ),
          state: state,
        );
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        final scripts = state.placementScripts('hi');
        final deva = scripts.firstWhere((s) => s.script == devanagari);
        final urdu = scripts.firstWhere((s) => s.script == persoArabic);

        // Devanagari is checked, as the learner's pills say they read it
        // through Hindi; Perso-Arabic, which they learn, is new with no
        // question.
        var asked = 0;
        final kinds = <Type>[];
        while (questionShown() &&
            find.text(l10n.placementQuestion).evaluate().isEmpty) {
          for (final type in <Type>[
            PlacementMatch,
            PlacementChoice,
            PlacementType,
            PlacementHear,
            PlacementSay,
          ]) {
            if (find.byType(type).evaluate().isNotEmpty) kinds.add(type);
          }
          await answerShown(tester);
          asked++;
        }
        // No voice and no recogniser: the heard and read-aloud words are
        // words to write in Latin letters.
        expect(kinds, <Type>[
          PlacementMatch,
          PlacementChoice,
          PlacementType,
          PlacementType,
          PlacementType,
        ]);
        // The words are shown in the script the learner reads.
        final first = tester.widget<PlacementChoice>(
          find.byType(PlacementChoice),
        );
        expect(shownWord(first.question.card.target), findsOneWidget);
        while (questionShown()) {
          await answerShown(tester);
          asked++;
        }
        expect(asked, lessThanOrEqualTo(20));

        expect(
          find.text(l10n.placementScriptReads(l10n.scriptName(devanagari))),
          findsOneWidget,
        );
        expect(
          find.text(l10n.placementScriptNew(l10n.scriptName(persoArabic))),
          findsOneWidget,
        );
        expect(find.text(l10n.placementWordsAll), findsOneWidget);
        await tapText(tester, l10n.placementDone);
        final placed = found!.placed['hi']!;
        expect(placed, containsAll(<String>[for (final e in deva.decks) e.id]));
        for (final e in urdu.decks) {
          expect(placed, isNot(contains(e.id)));
        }
        expect(
          placed,
          containsAll(<String>[for (final e in state.walkDecks('hi')) e.id]),
        );
        expect(found!.scripts['hi'], <String, ScriptStanding>{
          devanagari: ScriptStanding.reads,
          persoArabic: ScriptStanding.newTo,
        });
      },
    );
  });

  group('placement in the review\'s screen', () {
    const bengali = LanguageInfo(
      code: 'bn',
      iso639_3: 'ben',
      name: 'Bengali',
      script: 'bengali',
    );
    const sentence = model.Card(
      id: 't-0',
      deckId: 't',
      target: 'আমি ভাত খাই',
      native: 'I eat rice',
      reading: 'ami bhat khai',
      pos: 'phrase',
    );

    Widget inShell(Widget child) => PlacementShell(
      onClose: () {},
      deckName: 'Sentences',
      progress: 0.3,
      reportDetail: 'test',
      child: child,
    );

    testWidgets('a sentence is asked in the review\'s own screen: its header '
        'and wave, its card with the meaning, tiles to put in order, Check, '
        'and feedback with a swipe on', (tester) async {
      usePhone(tester);
      final answers = <bool>[];
      await pumpScreen(
        tester,
        inShell(
          PlacementTiles(
            question: TileQuestion.shuffled(sentence, Random(1)),
            number: 2,
            spelling: sentence.target,
            language: bengali,
            latin: false,
            onAnswer: answers.add,
          ),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(DrillFrame), findsOneWidget);
      expect(find.byType(DrillHeader), findsOneWidget);
      expect(find.text(l10n.placementQuestionNumber(2)), findsOneWidget);
      expect(find.text('Sentences'), findsOneWidget);
      expect(find.text(sentence.native), findsOneWidget);
      expect(find.text(l10n.drillRearrangePrompt), findsOneWidget);
      expect(find.byType(WordTile), findsNWidgets(3));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.drillCheck),
            )
            .onPressed,
        isNull,
        reason: 'Check waits for every word',
      );

      await answerTiles(tester);
      expect(answers, <bool>[true]);
    });

    testWidgets('the words in any other order are wrong, and say the '
        'sentence before going on', (tester) async {
      usePhone(tester);
      final answers = <bool>[];
      await pumpScreen(
        tester,
        inShell(
          PlacementTiles(
            question: TileQuestion.shuffled(sentence, Random(1)),
            number: 1,
            spelling: sentence.target,
            language: bengali,
            latin: false,
            onAnswer: answers.add,
          ),
        ),
      );
      final l10n = l10nOf(tester);
      final pool = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Wrap && w.alignment == WrapAlignment.center,
        ),
        matching: find.byType(WordTile),
      );
      // In the order they are shown, which is not the sentence's.
      for (var i = 0; i < 3; i++) {
        await tapInFrame(tester, pool.at(i));
      }
      await tapInFrame(
        tester,
        find.widgetWithText(FilledButton, l10n.drillCheck),
      );
      expect(answers, isEmpty, reason: 'feedback first, then the swipe on');
      expect(find.byType(FeedbackBanner), findsOneWidget);
      await goOn(tester);
      expect(answers, <bool>[false]);
    });

    testWidgets('a choice marks the answer and says it, and goes on only '
        'with the chevron; "I don\'t know" is wrong', (tester) async {
      usePhone(tester);
      final answers = <bool>[];
      final q = PlacementQuestion(
        card: sentence,
        options: <String>['I eat rice', 'I drink tea', 'I see you'],
      );
      Future<void> pumpChoice() => pumpScreen(
        tester,
        inShell(
          PlacementChoice(
            question: q,
            number: 1,
            title: const Text('What does this mean?'),
            shown: const Text('shown'),
            onAnswer: answers.add,
          ),
        ),
      );
      await pumpChoice();
      final l10n = l10nOf(tester);
      expect(find.byType(ChoiceTile), findsNWidgets(3));
      await tapInFrame(tester, find.text('I drink tea'));
      expect(answers, isEmpty);
      expect(find.byType(FeedbackBanner), findsOneWidget);
      // Answered wrong: the right option and the one chosen, no others, and
      // no Continue button.
      expect(find.byType(ChoiceTile), findsNWidgets(2));
      expect(find.text(l10n.commonContinue), findsNothing);
      expect(find.text(l10n.feedbackAnswer('I eat rice')), findsOneWidget);
      await goOn(tester);
      expect(answers, <bool>[false]);

      answers.clear();
      await pumpChoice();
      await tapInFrame(tester, find.text('I eat rice'));
      await goOn(tester);
      expect(answers, <bool>[true]);

      answers.clear();
      await pumpChoice();
      await tapInFrame(tester, find.text(l10n.placementDontKnow));
      await goOn(tester);
      expect(answers, <bool>[false]);
    });

    testWidgets('the walk through a course is drawn in that screen, each '
        'word a choice of tiles under the review\'s header', (tester) async {
      await pumpPlacement(tester, devanagariReader(const <String>{}));
      var words = 0;
      await placeAll(tester, (card) {
        words++;
        expect(find.byType(DrillFrame), findsOneWidget);
        expect(find.byType(DrillHeader), findsOneWidget);
        expect(find.byType(ChoiceTile), findsWidgets);
        expect(find.byType(AppBar), findsNothing);
      });
      expect(words, greaterThan(0));
    });
  });

  group('placement offered after Learn on the first launch', () {
    AppState learnsHindi({bool reads = true}) {
      final state = devanagariReader(const <String>{}, reads: reads);
      state.settings.placementOffers = const <String>['hi'];
      return state;
    }

    testWidgets('it begins at once in the review\'s screen with no ask '
        'screen; closing at the first question places nothing, and Done ends '
        'the offer', (tester) async {
      usePhone(tester);
      final state = learnsHindi(reads: false);
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi']),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.byType(DrillFrame), findsOneWidget);
      expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);

      await stopPlacement(tester);
      // The result is in the same screen.
      expect(find.byType(DrillFrame), findsOneWidget);
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placementOffers, isEmpty);
      expect(state.settings.placedDecks, isEmpty);
    });

    testWidgets('the check runs, saves what it placed, and ends the offer', (
      tester,
    ) async {
      usePhone(tester);
      final state = learnsHindi();
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi']),
        state: state,
      );
      final l10n = l10nOf(tester);
      await placeAll(tester, (card) {
        expect(find.byType(DrillFrame), findsOneWidget);
      });
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placementOffers, isEmpty);
      expect(state.settings.placedDecks, isNotEmpty);
    });

    testWidgets('each language is saved as it is done, and leaves the offer as '
        'the learner goes on, so quitting between two does not offer the first '
        'again', (tester) async {
      usePhone(tester);
      final state = devanagariReader(const <String>{});
      state.settings.placementOffers = const <String>['hi', 'mr'];
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi', 'mr']),
        state: state,
      );
      final l10n = l10nOf(tester);
      await placeAll(tester, (card) {});
      expect(
        state.settings.placedDecks,
        isNotEmpty,
        reason: 'saved when its result shows',
      );
      expect(state.settings.placementOffers, <String>['hi', 'mr']);
      await tapText(tester, l10n.placementNext);
      expect(state.settings.placementOffers, <String>['mr']);
    });
  });

  group('Start at the beginning, in the offer after Learn', () {
    testWidgets('it is a button under the first question that places nothing, '
        'saves nothing for the language, and goes on to the next, then the '
        'app', (tester) async {
      usePhone(tester);
      final state = devanagariReader(const <String>{}, reads: false);
      state.settings.placementOffers = const <String>['hi', 'mr'];
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi', 'mr']),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.placementStartAtBeginning), findsOneWidget);

      await tapText(tester, l10n.placementStartAtBeginning);
      expect(state.settings.placedDecks, isEmpty);
      expect(state.settings.placedAtOf('hi'), isEmpty);
      expect(state.settings.courseNative('hi'), isNull);
      expect(state.settings.placementOffers, <String>['mr']);
      expect(find.byType(PlacementTiles), findsNothing);
      expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);

      await tapText(tester, l10n.placementStartAtBeginning);
      expect(state.settings.placedDecks, isEmpty);
      expect(state.settings.placementOffers, isEmpty);
    });

    testWidgets('it is offered under the first question only', (tester) async {
      usePhone(tester);
      final state = devanagariReader(const <String>{}, reads: false);
      state.settings.placementOffers = const <String>['hi'];
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi']),
        state: state,
      );
      final l10n = l10nOf(tester);
      await answerShown(tester);
      expect(find.text(l10n.placementStartAtBeginning), findsNothing);
    });

    testWidgets('the close button, unlike it, keeps what was found so far: '
        'after a right answer the decks cleared are placed', (tester) async {
      usePhone(tester);
      final state = devanagariReader(const <String>{}, reads: false);
      state.settings.placementOffers = const <String>['hi'];
      await pumpScreen(
        tester,
        const OnboardingPlacementOffer(languages: <String>['hi']),
        state: state,
      );
      final l10n = l10nOf(tester);
      await answerShown(tester);
      if (find.byType(PlacementFrame).evaluate().isNotEmpty) {
        await stopPlacement(tester);
      }
      await tapText(tester, l10n.placementDone);
      expect(state.settings.placedDecks, isNotEmpty);
      expect(state.settings.placementOffers, isEmpty);
    });
  });

  group('placement asks nothing the pills have said', () {
    testWidgets('a script is checked where a pill says it is read, and is new '
        'with no question where none does; the course is begun with no ask, '
        'no script question and no native choice', (tester) async {
      Future<void> pumpHindustani(Map<String, bool> read) async {
        usePhone(tester);
        final state = AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en', 'hi'],
            learningLanguages: const <String>['hi'],
            learningChosen: true,
            scriptsLearned: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
          )..scriptsRead = read,
        );
        addTearDown(state.dispose);
        await pumpScreen(
          tester,
          PlacementPage(
            languages: const <String>['hi'],
            alphabet: const <String, bool>{'hi': true},
            scripts: <String, Set<String>>{
              'hi': <String>{persoArabic},
            },
            random: Random(3),
            onFinished: (_) {},
          ),
          state: state,
        );
        await tester.pumpAndSettle();
      }

      // Devanagari read, as its pill says: its check runs first.
      await pumpHindustani(<String, bool>{'en': true, 'hi': true});
      final l10n = l10nOf(tester);
      expect(find.byType(PlacementMatch), findsOneWidget);
      expect(find.text(l10n.placementQuestion), findsNothing);

      // No pill says it is read: straight to the words.
      await pumpHindustani(<String, bool>{'en': true});
      expect(find.byType(PlacementMatch), findsNothing);
      expect(find.text(l10n.placementQuestion), findsOneWidget);
    });

    testWidgets('the result sits in the review\'s screen with Continue at its '
        'foot', (tester) async {
      await pumpPlacement(tester, devanagariReader(const <String>{}));
      final l10n = l10nOf(tester);
      await stopPlacement(tester);
      expect(find.byType(DrillFrame), findsOneWidget);
      expect(find.byType(DrillHeader), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.placementDone),
        findsOneWidget,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ModePill), findsNothing);
      expect(find.byTooltip(l10n.drillEndSession), findsNothing);
    });
  });

  group('placement in the learner\'s scripts', () {
    testWidgets('a Devanagari reader learning Perso-Arabic is placed on the '
        'Perso-Arabic spelling, never the reading first; learning both, on '
        'each, as drills show them', (tester) async {
      await pumpPlacement(tester, devanagariReader(<String>{persoArabic}));
      await placeAll(tester, (card) {
        expect(find.byType(ReadingFirst), findsNothing);
        final urdu = card.targetScripts[persoArabic];
        if (urdu != null) {
          expect(shownWord(urdu), findsOneWidget);
          expect(shownWord(card.target), findsNothing);
        }
      });

      await pumpPlacement(
        tester,
        devanagariReader(<String>{devanagari, persoArabic}),
      );
      await placeAll(tester, (card) {
        expect(find.byType(ReadingFirst), findsNothing);
        expect(shownWord(card.target), findsOneWidget);
        if (card.targetScripts[persoArabic] case final urdu?) {
          expect(shownWord(urdu), findsOneWidget);
        }
      });
    });

    testWidgets(
      'learned without its scripts, a language is shown in a script the '
      'check found the learner reads, and its reading first when they read '
      'none',
      (tester) async {
        await pumpPlacement(tester, devanagariReader(const <String>{}));
        await placeAll(tester, (card) {
          expect(find.byType(ReadingFirst), findsNothing);
          expect(shownWord(card.target), findsOneWidget);
        });

        await pumpPlacement(
          tester,
          devanagariReader(const <String>{}, reads: false),
        );
        expect(find.byType(ReadingFirst), findsOneWidget);
      },
    );
  });

  group('placement\'s written questions', () {
    const language = LanguageInfo(
      code: 'bn',
      iso639_3: 'ben',
      name: 'Bengali',
      script: 'bengali',
    );
    const english = LanguageInfo(code: 'en', iso639_3: 'eng', name: 'English');

    DeckEntry deckOf(String id, List<model.Card> cards) => DeckEntry(
      path: '$id.yaml',
      deck: Deck(
        id: id,
        name: id,
        kind: DeckKind.vocab,
        language: language,
        native: english,
        license: 'CC-BY-SA-4.0',
        cards: cards,
      ),
    );

    List<model.Card> cards(
      String id,
      String meaning, {
      Set<DrillMode> modes = const <DrillMode>{},
    }) => <model.Card>[
      for (var i = 0; i < 4; i++)
        model.Card(
          id: '$id-$i',
          deckId: id,
          target: 'শব্দ$id$i',
          native: '$meaning $id $i',
          reading: 'shobdo $id $i',
          pos: modes.isEmpty ? 'noun' : 'other',
          modes: modes,
        ),
    ];

    test('a card that opts out of production, as a sound or spelling '
        'description does, is never asked as a word to write, while an '
        'ordinary word of the same course still is', () {
      const noProduction = <DrillMode>{
        DrillMode.production,
        DrillMode.listening,
        DrillMode.speaking,
      };
      // Answering right throughout, five clean answers jump the walk to the
      // last deck, and the written questions come from the last three decks
      // from the one past the last cleared: here w6, sounds and w7.
      final decks = <DeckEntry>[
        for (var i = 0; i < 7; i++) deckOf('w$i', cards('w$i', 'word')),
        deckOf(
          'sounds',
          cards(
            'sounds',
            'clusters at the start of a word',
            modes: noProduction,
          ),
        ),
        deckOf('w7', cards('w7', 'word')),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final walk = DeckWalk(decks, random: Random(seed));
        final written = <String>[];
        var asked = 0;
        while (!walk.isFinished && asked++ < 100) {
          final question = walk.question!;
          if (question is TypeQuestion && question.produce) {
            written.add(question.card.id);
          }
          walk.answer(true);
        }
        expect(walk.isFinished, isTrue);
        expect(written, isNotEmpty, reason: 'ordinary words are written');
        expect(written.where((id) => id.startsWith('sounds')), isEmpty);
      }
    });

    test('a course of descriptions alone is placed with choices, never a '
        'written question', () {
      const noProduction = <DrillMode>{DrillMode.production};
      final decks = <DeckEntry>[
        for (var i = 0; i < 6; i++)
          deckOf('s$i', cards('s$i', 'a sound', modes: noProduction)),
      ];
      final walk = DeckWalk(decks, random: Random(4));
      var asked = 0;
      while (!walk.isFinished && asked++ < 100) {
        expect(walk.question, isNot(isA<TypeQuestion>()));
        walk.answer(true);
      }
      expect(walk.isFinished, isTrue);
    });

    // -------------------------------------------------------------------
    // Owner, 2026-11-02: "There should be no write questions unless the
    // answer is very specific. Use sentence formation questions."

    DeckEntry deckIn(LanguageInfo lang, String id, List<model.Card> cards) =>
        DeckEntry(
          path: '$id.yaml',
          deck: Deck(
            id: id,
            name: id,
            kind: DeckKind.vocab,
            language: lang,
            native: english,
            license: 'CC-BY-SA-4.0',
            cards: cards,
          ),
        );

    /// Nine decks of four cards, each card's target made by [target].
    List<DeckEntry> course(
      String Function(String id, int i) target, {
      String pos = 'noun',
      List<String> alt = const <String>[],
      LanguageInfo? lang,
    }) => <DeckEntry>[
      for (var d = 0; d < 9; d++)
        deckIn(lang ?? language, 'c$d', <model.Card>[
          for (var i = 0; i < 4; i++)
            model.Card(
              id: 'c$d-$i',
              deckId: 'c$d',
              target: target('c$d', i),
              native: 'meaning c$d $i',
              reading: 'reading c$d $i',
              pos: pos,
              altTarget: alt,
            ),
        ]),
    ];

    /// Everything the walk over [decks] asks when each answer is right.
    List<PlacementAsk> asked(List<DeckEntry> decks) {
      final asks = <PlacementAsk>[];
      for (var seed = 0; seed < 10; seed++) {
        final walk = DeckWalk(decks, random: Random(seed));
        var n = 0;
        while (!walk.isFinished && n++ < 100) {
          asks.add(walk.question!);
          walk.answer(true);
        }
        expect(walk.isFinished, isTrue);
      }
      return asks;
    }

    test('a single word with one valid spelling is written; a word, a '
        'phrase or a sentence of more, a word with other spellings and a '
        'course that cannot be typed never are', () {
      final written = asked(course((id, i) => 'শব্দ$id$i'));
      final typed = written.whereType<TypeQuestion>().toList();
      expect(typed, isNotEmpty);
      expect(typed.every((q) => q.produce && q.card.wordCount == 1), isTrue);

      final never = <String, List<DeckEntry>>{
        'a sentence': course((id, i) => 'আমি ভাত $id$i খাই'),
        'a phrase': course((id, i) => 'ধন্যবাদ $id$i', pos: 'phrase'),
        'two words': course((id, i) => 'দুই $id$i'),
        'other spellings': course(
          (id, i) => 'শব্দ$id$i',
          alt: const <String>['অন্য'],
        ),
        'a course not typed': course(
          (id, i) => 'শব্দ$id$i',
          lang: const LanguageInfo(
            code: 'bn',
            iso639_3: 'ben',
            name: 'Bengali',
            script: 'bengali',
            typed: false,
          ),
        ),
      };
      for (final MapEntry(:key, :value) in never.entries) {
        expect(
          asked(value).whereType<TypeQuestion>().where((q) => q.produce),
          isEmpty,
          reason: '$key is not written',
        );
      }
    });

    test('a deck of sentences or phrases is asked as tiles, with no word added '
        'to them; a deck with neither a sentence nor one word to write is '
        'asked as a choice', () {
      for (final decks in <List<DeckEntry>>[
        course((id, i) => 'আমি ভাত $id$i খাই'),
        course((id, i) => 'ধন্যবাদ $id$i', pos: 'phrase'),
      ]) {
        final tiles = asked(decks).whereType<TileQuestion>().toList();
        expect(tiles, isNotEmpty);
        for (final q in tiles) {
          expect(q.card.rearranges, isTrue);
          expect(
            <String>[...q.tilesOfSpelling(q.card.target)]..sort(),
            <String>[...q.card.tilesOfSpelling(q.card.target)]..sort(),
            reason: 'the target\'s own words, none added or left out',
          );
        }
      }
      final choices = asked(course((id, i) => 'দুই $id$i'));
      expect(choices.whereType<TileQuestion>(), isEmpty);
      expect(choices.every((q) => q is PlacementQuestion), isTrue);
    });

    test('no card is asked twice in a walk, whatever the deck holds', () {
      for (final decks in <List<DeckEntry>>[
        course((id, i) => 'শব্দ$id$i'),
        course((id, i) => 'আমি ভাত $id$i খাই'),
        course((id, i) => 'দুই $id$i'),
        course((id, i) => 'শব্দ$id$i', alt: const <String>['অন্য']),
      ]) {
        for (var seed = 0; seed < 20; seed++) {
          for (final right in <bool Function(int)>[
            (_) => true,
            (n) => n.isOdd,
            (n) => n < 6,
          ]) {
            final walk = DeckWalk(decks, random: Random(seed));
            final ids = <String>[];
            var n = 0;
            while (!walk.isFinished && n < 100) {
              ids.add(walk.question!.card.id);
              walk.answer(right(n++));
            }
            expect(ids.toSet().length, ids.length, reason: '$ids');
          }
        }
      }
    });

    test('tiles of a spelling with another count of words than the target, as '
        'a reading may have, are shuffled too', () {
      const card = model.Card(
        id: 't-0',
        deckId: 't',
        target: 'আমি ভাত খাই',
        native: 'I eat rice',
        pos: 'phrase',
      );
      for (var seed = 0; seed < 20; seed++) {
        final q = TileQuestion.shuffled(card, Random(seed));
        final words = <String>['a', 'b', 'c', 'd'];
        final shown = q.shown(words);
        expect(<String>[...shown]..sort(), words);
        expect(shown, isNot(words));
      }
    });

    test('putting the tiles in order credits the deck; a wrong order, or '
        '"I don\'t know", places the learner before it', () {
      final decks = course((id, i) => 'আমি ভাত $id$i খাই');
      final all = DeckWalk(decks, random: Random(2));
      while (!all.isFinished) {
        all.answer(true);
      }
      expect(all.landing, decks.length);
      expect(all.placedDeckIds, <String>{for (final e in decks) e.id});

      final wrong = DeckWalk(decks, random: Random(2));
      while (wrong.question is! TileQuestion) {
        wrong.answer(true);
      }
      final at = wrong.asking!;
      wrong.answer(false);
      expect(wrong.isFinished, isTrue);
      expect(wrong.missed, at);
      expect(wrong.landing, at);
      expect(wrong.placedDeckIds, isNot(contains(decks[at].id)));
    });
  });

  group('placement\'s form questions', () {
    late DeckEntry nouns;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      nouns = state.decks.firstWhere(
        (e) => e.language.code == 'hi' && e.deck.pattern != null,
      );
    });

    test('a form of a table\'s word names the word once, in the question, '
        'and offers only its forms, of which one alone is right', () {
      final pattern = nouns.deck.pattern!;
      final slotOf = <String, String>{
        for (final slot in pattern.slots)
          pattern.slotLabels[slot] ?? slot: slot,
      };
      final walk = DeckWalk(<DeckEntry>[nouns], random: Random(3));
      var asked = 0;
      while (!walk.isFinished) {
        final q = walk.question! as PlacementQuestion;
        final word = q.formOf!;
        final row = pattern.entries.singleWhere((e) => e.lemma == word.lemma);
        expect(q.options.length, greaterThan(1));
        for (final option in q.options) {
          expect(option, isNot(contains(word.lemma)));
          expect(option, isNot(contains(word.gloss)));
          final slot = slotOf[option]!;
          // Only the right option's form is the one shown.
          expect(row.forms[slot] == q.card.target, option == q.answer);
          expect(q.isRight(option), option == q.answer);
        }
        walk.answer(true);
        asked++;
      }
      expect(asked, greaterThan(0));
      expect(walk.placedDeckIds, <String>{nouns.id});
    });
  });

  group('placement\'s read-aloud question', () {
    testWidgets('a speech miss does not answer it: the learner hears that '
        'nothing was heard, and can speak again', (tester) async {
      usePhone(tester);
      final speech = FixedSpeechEngine(onDevice: <String>{'hi'})
        ..failing = const SpeechHeard.failed(SpeechFailure.noMatch);
      final state = AppState.test(
        speech: speech,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      await state.startSpeech();
      final entry = state.decks.firstWhere((e) => e.language.code == 'hi');
      final card = entry.deck.cards.first;
      final answers = <bool>[];
      await pumpScreen(
        tester,
        Scaffold(
          body: PlacementSay(
            question: SayQuestion(
              card: card,
              shown: card.target,
              language: entry.language,
            ),
            number: 1,
            onAnswer: answers.add,
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);

      await tapText(tester, l10n.placementSayStart);
      expect(answers, isEmpty);
      expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);

      // Speak again: still not answered, then heard right.
      await tapText(tester, l10n.placementSayStart);
      expect(answers, isEmpty);
      speech
        ..failing = null
        ..next = <SpeechAlternative>[SpeechAlternative(card.target)];
      await tapText(tester, l10n.placementSayStart);
      expect(answers, <bool>[true]);
      expect(speech.listens, hasLength(3));
    });
  });

  group('the script check', () {
    late PlacementScript devanagariScript;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      devanagariScript = state
          .placementScripts('hi')
          .firstWhere((s) => s.script == devanagari);
    });

    ScriptCheck check({bool sound = false}) => ScriptCheck(
      script: devanagari,
      decks: devanagariScript.decks,
      words: devanagariScript.words,
      canHear: sound,
      canSay: sound,
      random: Random(2),
    );

    Set<String> decksNamed(List<String> endings) => <String>{
      for (final e in devanagariScript.decks)
        if (endings.any(e.id.endsWith)) e.id,
    };
    final letters = <String>[
      'script-vowels',
      'script-consonants',
      'script-digits',
    ];
    final joined = <String>[
      ...letters,
      'script-vowel-signs',
      'script-conjuncts',
    ];

    test(
      'a miss gets another question of the same level, and right, the '
      'check goes on; a second miss ends it, placed by the level reached',
      () {
        final c = check();
        expect(c.question, isA<MatchQuestion>());
        c.answer(true);
        final missed = c.question!;
        expect(missed, isA<PlacementQuestion>());
        c.answer(false);
        expect(c.isFinished, isFalse);
        expect(c.question, isA<PlacementQuestion>());
        expect(c.question!.card.id, isNot(missed.card.id));
        c.answer(true);
        expect(c.question, isA<TypeQuestion>());
        c
          ..answer(false)
          ..answer(false);
        expect(c.isFinished, isTrue);
        expect(c.asked, 5);
        expect(c.standing, ScriptStanding.joined);
        expect(c.placedDeckIds, decksNamed(joined));

        final atLetters = check()
          ..answer(false)
          ..answer(false);
        expect(atLetters.standing, ScriptStanding.newTo);
        expect(atLetters.placedDeckIds, isEmpty);

        final atJoined = check()
          ..answer(true)
          ..answer(false)
          ..answer(false);
        expect(atJoined.standing, ScriptStanding.letters);
        expect(atJoined.placedDeckIds, decksNamed(letters));
      },
    );

    test('without a voice or a recogniser, the heard and read-aloud levels '
        'are harder words to write in Latin letters; with them, a word heard '
        'and one read aloud; every level right skips the script\'s decks', () {
      for (final sound in <bool>[false, true]) {
        final c = check(sound: sound);
        final kinds = <Type>[];
        while (!c.isFinished) {
          kinds.add(c.question.runtimeType);
          c.answer(true);
        }
        expect(kinds, <Type>[
          MatchQuestion,
          PlacementQuestion,
          TypeQuestion,
          if (sound) HearQuestion else TypeQuestion,
          if (sound) SayQuestion else TypeQuestion,
        ]);
        expect(c.standing, ScriptStanding.reads);
        expect(c.placedDeckIds, <String>{
          for (final e in devanagariScript.decks) e.id,
        });
      }
    });

    test('"I can\'t speak now" on the read-aloud question skips it: it is '
        'not a miss, so the result is what answering it right would reach '
        'and the check goes on', () {
      final c = check(sound: true);
      while (c.question is! SayQuestion) {
        c.answer(true);
      }
      final before = c.level;
      c.skipSay();
      expect(c.question, isNot(isA<SayQuestion>()));
      expect(c.level, before, reason: 'skipping neither passes nor fails');
      expect(c.isFinished, isFalse);
      c.answer(true);
      expect(c.standing, ScriptStanding.reads);

      // Skipped, then a miss is the first miss, not the second.
      final d = check(sound: true);
      while (d.question is! SayQuestion) {
        d.answer(true);
      }
      d.skipSay();
      d.answer(false);
      expect(d.isFinished, isFalse);
    });
  });

  group('the deck walk', () {
    late List<DeckEntry> decks;
    late List<DeckEntry> telugu;
    late List<int> askable;
    setUpAll(() async {
      final state = AppState.test();
      await state.load();
      decks = state.walkDecks('hi');
      telugu = state.walkDecks('te');
      askable = DeckWalk(decks).askableDecks;
    });

    DeckWalk walk() => DeckWalk(decks, random: Random(7));

    test('three decks right at the first try skip the next, and five jump to '
        'the end', () {
      final w = walk();
      final asked = <int>[];
      while (w.phase == WalkPhase.forward) {
        asked.add(w.asking!);
        w.answer(true);
      }
      expect(asked, <int>[
        askable[0],
        askable[1],
        askable[2],
        askable[4],
        askable[5],
      ]);
      expect(w.phase, WalkPhase.end);
      expect(w.asking, askable.last);
    });

    test('a miss gets a second question from the same deck: right, the walk '
        'goes on, its run counted again; wrong, it stops before that deck', () {
      final w = walk()..answer(true);
      final missed = w.question!;
      w.answer(false);
      expect(w.asking, askable[1]);
      expect(w.question!.card.id, isNot(missed.card.id));
      w.answer(true);
      final asked = <int>[];
      for (var i = 0; i < 3; i++) {
        asked.add(w.asking!);
        w.answer(true);
      }
      expect(asked, <int>[askable[2], askable[3], askable[4]]);
      expect(w.asking, askable[6], reason: 'three in a row skip one');
      w
        ..answer(false)
        ..answer(false);
      expect(w.isFinished, isTrue);
      expect(w.landing, askable[6]);
      expect(w.missed, askable[6]);
      expect(w.placedDeckIds, <String>{
        for (final e in decks.take(askable[6])) e.id,
      });
    });

    test('wrong at the end, the walk steps back by 2, then 3 more, then 5, '
        'until right; then two or three typed questions from the decks after '
        'decide where it lands', () {
      for (final typedRight in <bool>[true, false]) {
        final w = walk();
        for (var i = 0; i < 5; i++) {
          w.answer(true);
        }
        final end = askable.length - 1;
        expect(w.asking, askable[end]);
        w.answer(false);
        expect(w.asking, askable[end - 2]);
        w.answer(false);
        expect(w.asking, askable[end - 5]);
        w.answer(false);
        expect(w.asking, askable[end - 10]);
        w.answer(true);
        expect(w.phase, WalkPhase.produce);
        final typed = <int>[];
        while (w.phase == WalkPhase.produce) {
          // A sentence is put together, a word with one spelling written, any
          // other deck chosen: never a written sentence (owner, 2026-11-02).
          expect(
            w.question,
            anyOf(
              isA<TypeQuestion>(),
              isA<TileQuestion>(),
              isA<PlacementQuestion>(),
            ),
          );
          typed.add(w.asking!);
          w.answer(typedRight);
        }
        for (final deck in typed) {
          expect(deck, greaterThan(askable[end - 10]));
          expect(deck, lessThan(askable[end - 5]));
        }
        if (typedRight) {
          expect(typed.length, inInclusiveRange(2, 3));
          expect(w.landing, greaterThan(typed.last));
          expect(w.landing, lessThanOrEqualTo(askable[end - 5]));
        } else {
          expect(typed.length, 1);
          expect(w.landing, typed.single, reason: 'lands on the deck missed');
        }
      }
    });

    test('on the longest path, no way of answering asks more than about 20 '
        'questions of the words, so placement stays well under 40 with a '
        'script check at its longest (owner, 2026-10-20: "I cannot be '
        'expected to answer 100+ questions")', () {
      expect(telugu.length, greaterThan(100));
      var worst = 0;
      void run(bool Function(int n) right) {
        final w = DeckWalk(telugu, random: Random(1));
        var n = 0;
        while (!w.isFinished && n < 1000) {
          w.answer(right(n++));
        }
        expect(w.isFinished, isTrue);
        worst = max(worst, w.asked);
      }

      run((_) => true);
      run((_) => false);
      run((n) => n.isOdd);
      run((n) => n.isEven);
      run((n) => n < 5);
      for (final p in <double>[0.3, 0.5, 0.7, 0.85, 0.95]) {
        for (var seed = 0; seed < 100; seed++) {
          final random = Random(seed);
          run((_) => random.nextDouble() < p);
        }
      }
      expect(worst, lessThanOrEqualTo(24));
      // A script check asks at most two questions at each of five levels.
      expect(worst + 2 * 5, lessThan(36));
    });
  });

  group('Find my level', () {
    group('a language the learner speaks', () {
      testWidgets(
        'a language goes through placement when Find my level is chosen, '
        'and starting at the beginning places nothing',
        (tester) async {
          await pumpPickerLanguagesLearningFixes(
            tester,
            spoken: const <String>['en', 'hi'],
          );
          final l10n = l10nOf(tester);
          await pickLanguage(tester, 'hi');
          await tester.tap(find.text(l10n.commonContinue));
          await tester.pumpAndSettle();
          expect(find.byType(PlacementPage), findsOneWidget);

          {
            final state = await pumpPickerLanguagesLearningFixes(
              tester,
              spoken: const <String>['en', 'es'],
            );
            final l10n = l10nOf(tester);
            await pickLanguage(tester, 'es', begin: true);
            await tester.tap(find.text(l10n.commonContinue));
            await tester.pumpAndSettle();
            expect(find.byType(PlacementPage), findsNothing);
            expect(state.settings.learningLanguages, contains('es'));
          }
        },
      );
    });
  });
  group('placement credits what it found', () {
    late AppState state;
    late PlacementScript deva;
    setUp(() async {
      state = AppState.test();
      await state.load();
      deva = state
          .placementScripts('hi')
          .firstWhere((s) => s.script == devanagari);
    });

    Set<String> cardsOf(Iterable<DeckEntry> decks) => <String>{
      for (final e in decks)
        for (final c in e.cards) c.id,
    };

    test('a script read credits Read and Write, as Easy answers today', () {
      final placed = ScriptCheck.placedFor(deva.decks, ScriptStanding.reads);
      final written = state.creditPlacement(
        'hi',
        placed: placed,
        standings: <String, ScriptStanding>{devanagari: ScriptStanding.reads},
      );
      expect(written, greaterThan(0));
      final cards = cardsOf(deva.decks.where((e) => e.isScript));
      final scripts = state.progress.scriptStates;
      for (final id in cards) {
        for (final mode in <DrillMode>[
          DrillMode.readScript,
          DrillMode.writeScript,
        ]) {
          expect(
            scripts.containsKey((cardId: id, mode: mode, script: devanagari)),
            isTrue,
            reason: '$id $mode',
          );
        }
        final due = state.progress.stateOf(id, DrillMode.recognition)!;
        final easy = Fsrs.next(null, 5, now: state.now(), rated: true);
        expect(due.dueAt, easy.dueAt, reason: 'the Easy interval, from today');
        expect(due.lastReviewAt, state.now());
      }
      final numbers = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardLookupOf(state),
      );
      expect(
        numbers.scriptSkills.keys,
        containsAll(<ScriptSkill>[
          (script: devanagari, mode: DrillMode.readScript),
          (script: devanagari, mode: DrillMode.writeScript),
        ]),
      );
    });

    test('a script stopped part-way credits Read for the letters and '
        'composites only', () {
      final placed = ScriptCheck.placedFor(deva.decks, ScriptStanding.joined);
      state.creditPlacement(
        'hi',
        placed: placed,
        standings: <String, ScriptStanding>{devanagari: ScriptStanding.joined},
      );
      final credited = cardsOf(
        deva.decks.where((e) => placed.contains(e.id) && e.isScript),
      );
      final reading = cardsOf(
        deva.decks.where((e) => !placed.contains(e.id) && e.isScript),
      ).difference(credited);
      final scripts = state.progress.scriptStates;
      expect(credited, isNotEmpty);
      expect(reading, isNotEmpty);
      for (final id in credited) {
        expect(
          scripts.containsKey((
            cardId: id,
            mode: DrillMode.readScript,
            script: devanagari,
          )),
          isTrue,
        );
        expect(
          scripts.containsKey((
            cardId: id,
            mode: DrillMode.writeScript,
            script: devanagari,
          )),
          isFalse,
        );
      }
      for (final id in reading) {
        expect(state.progress.stateOf(id, DrillMode.recognition), isNull);
      }
    });

    test('placed word decks are credited, and a retake changes nothing', () {
      final walked = state.walkDecks('hi').take(2).toList();
      final placed = <String>{for (final e in walked) e.id};
      expect(state.creditPlacement('hi', placed: placed), greaterThan(0));
      final ids = cardsOf(walked);
      final states = <ProgressKey, FsrsState>{
        for (final entry in state.progress.states.entries)
          if (ids.contains(entry.key.cardId)) entry.key: entry.value,
      };
      expect(states, isNotEmpty);
      expect(state.creditPlacement('hi', placed: placed), 0);
      expect(state.progress.log.length, states.length);
    });
  });
}
