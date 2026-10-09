import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/play_button.dart';

import '../../support/harness.dart';

/// Multiple choice, match pairs and rearrange (ADR-0024).

const String spanish = 'es-en-core-100';
const String hindi = 'hi-en-first-words';
const String script = 'hi-en-script-reading';

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required String deck,
  required Skill skill,
  required String target,
  required Ask ask,
  AppState? state,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deck, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: state,
);

Card cardOf(AppState state, String deck, String target) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.target == target);

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A match pairs question of [target] and the next words of [deck] with
/// other meanings, in recognition, as a lesson asks it (ADR-0034). The
/// match shows until it is answered and continued.
Future<(AppState, DrillSession)> pumpMatch(
  WidgetTester tester, {
  required String deck,
  required String target,
}) async {
  final state = AppState.test();
  await state.load();
  final cards = state.deckById(deck)!.cards;
  final first = cards.firstWhere((c) => c.target == target);
  final group = <SessionItem>[
    SessionItem(card: first, mode: DrillMode.recognition, state: null),
  ];
  for (final card in cards) {
    if (group.length == matchSize) break;
    if (group.every(
      (g) => g.card.native != card.native && g.card.target != card.target,
    )) {
      group.add(
        SessionItem(card: card, mode: DrillMode.recognition, state: null),
      );
    }
  }
  final session = DrillSession(
    state: state,
    items: <SessionItem>[group.first.askedAs(Ask.matchPairs, group: group)],
  );
  addTearDown(session.dispose);
  await pumpScreen(
    tester,
    ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.finished
          ? const SizedBox.shrink()
          : MatchDrill(session: session, onClose: () {}),
    ),
    state: state,
  );
  return (state, session);
}

void main() {
  group('multiple choice', () {
    testWidgets('the right meaning records recognition, graded 4', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpAsked(
        tester,
        deck: spanish,
        skill: Skill.recognition,
        target: 'la casa',
        ask: Ask.chooseMeaning,
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, spanish, 'la casa');
      expect(find.byType(ChoiceDrill), findsOneWidget);
      expect(find.text(l10n.drillChooseMeaning), findsOneWidget);
      // Four options, each a different meaning, the card's among them.
      final options = find.descendant(
        of: find.bySemanticsLabel(l10n.drillOptionsGroup),
        matching: find.byType(InkWell),
      );
      expect(options, findsNWidgets(4));

      await tapText(tester, card.native);
      final event = state.progress.log.single;
      expect(event.cardId, card.id);
      expect(event.mode, DrillMode.recognition);
      expect(event.grade, 4);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      await tapText(tester, l10n.commonContinue);
      expect(find.byType(ChoiceDrill), findsNothing);
    });

    testWidgets('a wrong one records 1 and shows the answer', (tester) async {
      usePhone(tester);
      final state = await pumpAsked(
        tester,
        deck: spanish,
        skill: Skill.recognition,
        target: 'la casa',
        ask: Ask.chooseMeaning,
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, spanish, 'la casa');
      final session = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill));
      final wrong = session.session.options.firstWhere((o) => o.id != card.id);
      await tapText(tester, wrong.native);
      expect(state.progress.log.single.grade, 1);
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer(card.native)), findsOneWidget);
    });

    testWidgets('choosing the word records production; before the script '
        'units, each word shows its reading first', (tester) async {
      usePhone(tester);
      final state = await pumpAsked(
        tester,
        deck: hindi,
        skill: Skill.production,
        target: 'नमस्कार',
        ask: Ask.chooseWord,
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, hindi, 'नमस्कार');
      expect(find.text(l10n.drillChooseWord('Hindi')), findsOneWidget);
      expect(find.text(card.native), findsOneWidget);
      await tapText(tester, card.reading!);
      final event = state.progress.log.single;
      expect(event.mode, DrillMode.production);
      // A right choice in Write counts for less than a recall (ADR-0034).
      expect(event.grade, DrillSession.scheduledChoiceGrade);
      expect(event.grade, 3);
    });

    testWidgets('hearing and choosing, in script practice, plays the word and '
        'records listening, graded 3', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'hi'});
      final state = await pumpAsked(
        tester,
        deck: script,
        skill: Skill.listening,
        target: 'जल',
        ask: Ask.hearAndChoose,
        state: AppState.test(tts: tts),
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, script, 'जल');
      expect(state.hearsForm(card), isTrue);
      expect(find.text(l10n.drillChooseHeard), findsOneWidget);
      // The meaning is not given away.
      expect(find.text(card.native), findsNothing);
      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken.last.text, card.target);
      final session = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill));
      // Words to choose from, not meanings.
      for (final option in session.session.options) {
        expect(find.text(option.native), findsNothing);
      }
      await tapText(tester, card.target);
      final event = state.progress.log.single;
      expect(event.mode, DrillMode.listening);
      expect(event.grade, DrillSession.scheduledChoiceGrade);
      expect(find.text(card.native), findsOneWidget);
    });
  });

  group('match pairs', () {
    testWidgets('tapping a word and then its meaning matches them, and each '
        'records recognition as it is matched', (tester) async {
      usePhone(tester);
      final (state, _) = await pumpMatch(
        tester,
        deck: spanish,
        target: 'la casa',
      );
      final l10n = l10nOf(tester);
      final drill = tester.widget<MatchDrill>(find.byType(MatchDrill));
      final group = drill.session.item.group;
      expect(group, hasLength(matchSize));
      expect(find.text(l10n.drillMatchPrompt), findsOneWidget);

      // A wrong pair first: nothing recorded, the word marked missed.
      await tapText(tester, group[0].card.target);
      await tapText(tester, group[1].card.native);
      expect(state.progress.log, isEmpty);
      expect(drill.session.wasMissed(group[0]), isTrue);

      // Meaning first, then word, works too.
      for (final entry in group) {
        await tapText(tester, entry.card.native);
        await tapText(tester, entry.card.target);
      }
      final grades = <String, int>{
        for (final e in state.progress.log) e.cardId: e.grade,
      };
      expect(state.progress.log, hasLength(matchSize));
      expect(state.progress.log.map((e) => e.mode).toSet(), <DrillMode>{
        DrillMode.recognition,
      });
      expect(grades[group[0].card.id], 1);
      for (final entry in group.skip(1)) {
        expect(grades[entry.card.id], 4);
      }
      expect(find.text(l10n.drillMatchAgain(1)), findsOneWidget);
      await tapText(tester, l10n.commonContinue);
      expect(find.byType(MatchDrill), findsNothing);
    });

    testWidgets('a word dragged onto its meaning is matched', (tester) async {
      usePhone(tester);
      final (state, _) = await pumpMatch(
        tester,
        deck: spanish,
        target: 'la casa',
      );
      final card = cardOf(state, spanish, 'la casa');
      final word = find.text(card.target);
      final meaning = find.text(card.native);
      await tester.ensureVisible(word);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(word));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(meaning));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final event = state.progress.log.single;
      expect(event.cardId, card.id);
      expect(event.grade, 4);
    });
  });

  group('rearrange', () {
    testWidgets('the words put in order record production, graded 5', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpAsked(
        tester,
        deck: hindi,
        skill: Skill.production,
        target: 'आप कैसे हैं?',
        ask: Ask.rearrange,
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, hindi, 'आप कैसे हैं?');
      expect(find.byType(RearrangeDrill), findsOneWidget);
      expect(find.text(card.native), findsOneWidget);
      // Before the script units, the words come in Latin letters.
      final words = tilesOf(card.reading!);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.drillCheck),
            )
            .onPressed,
        isNull,
      );
      for (final word in words) {
        await tapText(tester, word);
      }
      await tapText(tester, l10n.drillCheck);
      final event = state.progress.log.single;
      expect(event.mode, DrillMode.production);
      expect(event.grade, 5);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    });

    testWidgets('a word placed can be taken back; the wrong order records 1', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpAsked(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'la casa',
        ask: Ask.rearrange,
      );
      final l10n = l10nOf(tester);
      Finder placed(String word) => find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == l10n.drillRearrangeAnswer,
        ),
        matching: find.text(word),
      );
      await tapText(tester, 'la');
      expect(placed('la'), findsOneWidget);
      // Its place among the words to place is kept, so the others stay put.
      expect(find.text('la'), findsNWidgets(2));
      await tester.tap(placed('la'));
      await tester.pumpAndSettle();
      expect(placed('la'), findsNothing);
      await tapText(tester, 'casa');
      await tapText(tester, 'la');
      await tapText(tester, l10n.drillCheck);
      expect(state.progress.log.single.grade, 1);
      expect(find.text(l10n.feedbackAnswer('la casa')), findsOneWidget);
    });
  });

  group('a session', () {
    testWidgets('asks recognition by match pairs and multiple choice, never '
        'by rating; a lesson does too', (tester) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['es'],
        ),
      );
      await state.load();
      // Recognition is a schedule of its own (ADR-0034): a review asks it,
      // by choosing the meaning, with options enough to choose among.
      final reviewed = state.sessionItems(
        DrillRequest.untaught(spanish, skill: Skill.recognition),
      );
      expect(reviewed, isNotEmpty);
      expect(reviewed.map((i) => i.mode).toSet(), {DrillMode.recognition});
      expect(
        <Ask>{for (final item in reviewed) item.ask},
        <Ask>{Ask.chooseMeaning, Ask.matchPairs},
      );
      expect(
        state.sessionItems(DrillRequest.untaught(spanish)).map((i) => i.mode),
        contains(DrillMode.recognition),
        reason: 'a new word starts with Recognition',
      );
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
      final recognised = <Ask>{
        for (final item in lesson)
          if (item.mode == DrillMode.recognition && item.ask != Ask.teach)
            item.ask,
      };
      expect(recognised, <Ask>{Ask.chooseMeaning, Ask.matchPairs});

      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.recognition),
        ),
        state: state,
      );
      expect(find.byType(MatchDrill), findsOneWidget);
      expect(find.byType(RecognitionDrill), findsNothing);
    });

    testWidgets('asks a phrase by rearranging, and a word by typing', (
      tester,
    ) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      await state.load();
      final items = state.sessionItems(
        DrillRequest.untaught(hindi, skill: Skill.production),
      );
      final phrase = items.firstWhere((i) => i.card.target == 'आप कैसे हैं?');
      final word = items.firstWhere((i) => i.card.target == 'नमस्कार');
      expect(phrase.ask, Ask.rearrange);
      expect(word.ask, Ask.own);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(hindi, skill: Skill.production),
        ),
        state: state,
      );
      expect(find.byType(TypedDrill), findsOneWidget);
    });
  });
}
