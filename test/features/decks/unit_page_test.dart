import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/scheduling/session_queue.dart' show Ask;
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/number_practice_tile.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/path_parts.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/word_mastery.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import '../../support/harness.dart';

/// The design's Telugu learner, with Family under way.
Future<AppState> teluguLearner() async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app);
}

/// A phone tall enough for the unit's lazy list to build every row.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
}

final Finder downward = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// A course of one unit: a word whose partner sounds almost the same and
/// is rude, the partner, and a phrase.
MemoryDeckSource tinyCourse() => MemoryDeckSource(const <String, String>{
  'decks/es/es-en-tiny.yaml': '''
schema: 1
id: es-en-tiny
name: Tiny
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9001
    target: "gato"
    native: "cat"
    ipa: "ˈɡato"
    notes: "A plain note."
    pair: "es-9002"
  - id: es-9002
    target: "gatu"
    native: "a rude word"
    tags: ["offensive"]
  - id: es-9003
    target: "buenos días a todos"
    native: "good morning, everyone"
    pos: "phrase"
''',
  'decks/es/es-en-path.yaml': '''
schema: 1
kind: path
id: es-en-path
language: es
native: en
units:
  - [es-en-tiny]
''',
});

void main() {
  testWidgets('the header: level, number, name, description and the '
      'notice of a deck no speaker has checked', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family', plan: PathFixtures.telugu),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text(l10n.pathUnitNumber(7)), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(
      find.text(state.deckById('te-en-family')!.deck.description!),
      findsOneWidget,
    );
    expect(find.text(l10n.deckUnreviewed('Telugu')), findsOneWidget);
    expect(
      find.text(l10n.decksCourseHeading('Telugu', 'English')),
      findsOneWidget,
    );
    // The bug icon stays, and Review is at the top end.
    expect(find.byType(ReportButton), findsWidgets);
    expect(find.text(l10n.unitReview), findsOneWidget);
  });

  testWidgets('without a plan, no level is shown', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    expect(find.text('A1'), findsNothing);
    expect(find.text(l10nOf(tester).pathUnitNumber(7)), findsOneWidget);
  });

  testWidgets('tiles and words: each word Known, Learning n% or New, from '
      'its recent answers', (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    final content = UnitContent(unitOfDeck(state, 'te-en-family')!.decks);
    final answers = RecentAnswers(state.progress.log);
    final known = content.words
        .where((c) => answers.of(c.id).level == MasteryLevel.known)
        .length;
    expect(known, greaterThan(0));
    expect(
      find.text(l10n.unitFraction('$known', '${content.words.length}')),
      findsOneWidget,
    );
    expect(find.text(l10n.unitWordsKnown), findsOneWidget);
    expect(find.text(l10n.unitRulesKnown), findsOneWidget);
    expect(find.text(l10n.unitSentencesOpen), findsOneWidget);
    expect(find.text(l10n.unitKnownMeans(85)), findsOneWidget);

    // The first six words, then all of them.
    final chips = find.byType(MasteryChip);
    final shownFirst = tester.widgetList(chips).length;
    expect(
      tester.widgetList<MasteryChip>(chips).take(6).map((c) => c.mastery.level),
      [for (final c in content.words.take(6)) answers.of(c.id).level],
    );
    await tester.scrollUntilVisible(
      find.text(l10n.unitShowAll(content.words.length)),
      200,
      scrollable: downward.first,
    );
    await tester.tap(find.text(l10n.unitShowAll(content.words.length)));
    await tester.pumpAndSettle();
    expect(tester.widgetList(chips).length, greaterThan(shownFirst));
    expect(find.text(l10n.unitShowFewer), findsOneWidget);
    // Some are still being learned, and some are new.
    final levels = <MasteryLevel>{
      for (final c in content.words) answers.of(c.id).level,
    };
    expect(levels, containsAll(MasteryLevel.values));
    expect(find.textContaining(RegExp(r'^Learning \d+%$')), findsWidgets);
  });

  testWidgets('rules: each grammar deck, its status, and its table on '
      'request', (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    final rule = state.deckById('te-en-grammar-be')!;
    expect(find.text(l10n.unitSectionRules(2)), findsOneWidget);
    expect(find.text(rule.deck.name), findsWidgets);
    final show = find.text(l10n.unitRuleShowTable);
    await tester.scrollUntilVisible(show, 200, scrollable: downward.first);
    expect(find.text(l10n.unitRuleWord), findsNothing);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(find.text(l10n.unitRuleWord), findsOneWidget);
    expect(find.text(l10n.unitRuleCells), findsOneWidget);
    final pattern = rule.deck.pattern!;
    for (final slot in pattern.slots) {
      expect(find.text(slot), findsWidgets, reason: slot);
    }
    await tester.tap(find.text(l10n.unitRuleHideTable));
    await tester.pumpAndSettle();
    expect(find.text(l10n.unitRuleWord), findsNothing);
  });

  testWidgets('sentences: how many are open, each open or not yet', (
    tester,
  ) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    final content = UnitContent(unitOfDeck(state, 'te-en-family')!.decks);
    final open = content.sentences.where(state.isTaught).length;
    expect(
      find.text(l10n.unitSentencesCount(open, content.sentences.length)),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<MasteryChip>(find.byType(MasteryChip))
          .where((c) => c.notOpen)
          .length,
      content.sentences.length - open,
    );
  });

  testWidgets('Continue reviews what is due in the unit, and says how many '
      'new and due', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    final ids = <String>{'te-en-family', 'te-en-grammar-be'};
    final due = state.buildSession(DrillRequest(deckIds: ids)).due.length;
    expect(due, greaterThan(0));
    final fresh = state
        .lessonFor(DrillRequest.lesson(language: 'te', deckId: 'te-en-family'))
        .where((item) => item.ask == Ask.teach)
        .length;
    expect(fresh, greaterThan(0));
    final continueButton = find.text(l10n.unitContinue(fresh, due));
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    final drill = tester.widget<DrillPage>(find.byType(DrillPage));
    expect(drill.request.deckIds, <String>{'te-en-family', 'te-en-grammar-be'});
    expect(drill.request.lesson, isFalse);
  });

  testWidgets('with nothing due, Continue teaches the unit\'s next words', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: AppState.test(),
    );
    final l10n = l10nOf(tester);
    final label = tester
        .widget<Text>(find.textContaining(RegExp(r'^Continue')))
        .data!;
    expect(label, endsWith(l10n.unitContinue(0, 0).split(', ').last));
    await tester.tap(find.textContaining(RegExp(r'^Continue')));
    await tester.pumpAndSettle();
    final drill = tester.widget<DrillPage>(find.byType(DrillPage));
    expect(drill.request.lesson, isTrue);
    expect(drill.request.deckIds, <String>{'te-en-family'});
  });

  testWidgets('with nothing new and nothing due, Continue is off', (
    tester,
  ) async {
    usePhone(tester);
    final progress = MemoryProgress();
    final state = AppState.test(decks: tinyCourse(), progress: progress);
    await state.load();
    for (final card in state.deckById('es-en-tiny')!.cards) {
      for (final mode in card.modesIn(ttsAvailable: false)) {
        progress.record(
          deckId: 'es-en-tiny',
          cardId: card.id,
          mode: mode,
          grade: 4,
          now: state.now(),
        );
      }
    }
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'es-en-tiny'),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.unitNothingLeft), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(l10n.unitNothingLeft),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Review is a stub until reviewer mode: it says so', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-family'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.unitReview));
    await tester.pump();
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
  });

  testWidgets('the unit\'s decks open their own screens, and the numbers '
      'unit offers number practice', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-numbers-big'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    await tester.scrollUntilVisible(
      find.byType(NumberPracticeTile),
      300,
      scrollable: downward.first,
    );
    expect(find.text(l10n.unitDecks), findsOneWidget);
    await tester.tap(find.text('Tens and big numbers').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DeckDetailPage>(find.byType(DeckDetailPage)).deckId,
      'te-en-numbers-big',
    );
  });

  testWidgets('a word opens its card: the word, reading, IPA, meaning and '
      'note, and a warning where another word sounds almost the same', (
    tester,
  ) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const UnitPage(deckId: 'te-en-sound-differences'),
      state: await teluguLearner(),
    );
    final l10n = l10nOf(tester);
    final word = state
        .deckById('te-en-sound-differences')!
        .cards
        .firstWhere((c) => c.id == PathFixtures.soundAlikeCard);
    final row = find.text(word.native);
    await tester.scrollUntilVisible(row, 200, scrollable: downward.first);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsOneWidget);
    final sheet = find.byType(WordSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(word.target), findsOneWidget);
    expect(inSheet(word.reading!), findsOneWidget);
    expect(inSheet(l10n.wordSheetIpa(word.ipa!)), findsOneWidget);
    expect(inSheet(word.native), findsOneWidget);
    expect(inSheet(word.notes!), findsOneWidget);
    expect(inSheet(l10n.wordSheetSoundsLikeTitle), findsOneWidget);
    final partner = state
        .deckOf(word)!
        .cards
        .firstWhere(
          (c) => c.id == word.pair,
          orElse: () => state.decks
              .expand((e) => e.cards)
              .firstWhere((c) => c.id == word.pair),
        );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(
          l10n.wordSheetSoundsLike(
            partner.target,
            partner.reading!,
            partner.native,
          ),
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    // Its own bug icon reports the card.
    expect(
      tester
          .widget<ReportButton>(
            find.descendant(of: sheet, matching: find.byType(ReportButton)),
          )
          .detail,
      word.id,
    );
  });

  testWidgets('a rude word it sounds like is hidden unless adult content is '
      'on', (tester) async {
    usePhone(tester);
    final state = AppState.test(decks: tinyCourse());
    await state.load();
    final word = state.deckById('es-en-tiny')!.cards.first;
    final language = state.deckById('es-en-tiny')!.language;
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: word, language: language),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(adultContentOn(state), isFalse);
    expect(find.text(l10n.wordSheetSoundsRude), findsOneWidget);
    expect(find.textContaining('gatu', findRichText: true), findsNothing);

    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: word, language: language, showRude: true),
      ),
      state: state,
    );
    expect(find.text(l10n.wordSheetSoundsRude), findsOneWidget);
    expect(
      find.text(
        l10n.wordSheetSoundsLikeNoReading('gatu', 'a rude word'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    // No picture, no reading, but the IPA and the note.
    expect(find.text(l10n.wordSheetIpa('ˈɡato')), findsOneWidget);
    expect(find.text('A plain note.'), findsOneWidget);
  });

  testWidgets('a deck outside any path has no unit: its screen says not '
      'found', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const UnitPage(deckId: 'no-such-deck'),
      state: AppState.test(),
    );
    expect(find.text(l10nOf(tester).deckNotFound), findsOneWidget);
  });
}
