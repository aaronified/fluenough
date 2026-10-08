import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/play_button.dart';

import '../../support/harness.dart';

/// Hear (ADR-0034): the word is played, and its meaning chosen while the
/// pair is new or was last missed, typed once it was last remembered. In
/// script practice what was heard is typed instead.

const String spanish = 'es-fixture-hear';
const String script = 'hi-en-script-reading';

/// A small Spanish deck, in memory, with a meaning in parts.
MemoryDeckSource fixtureDecks() => MemoryDeckSource(const <String, String>{
  'decks/es/$spanish.yaml': '''
schema: 1
id: es-fixture-hear
name: "Spanish (Hear fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-hear-0001
    target: "ir"
    native: "to go, to leave"
  - id: es-fixture-hear-0002
    target: "la casa"
    native: "the house"
    alt_native: ["the home"]
  - id: es-fixture-hear-0003
    target: "el perro"
    native: "the dog"
  - id: es-fixture-hear-0004
    target: "el gato"
    native: "the cat"
  - id: es-fixture-hear-0005
    target: "la mesa"
    native: "the table"
''',
});

AppState spanishState({MemoryProgress? progress, DateTime? now}) =>
    AppState.test(
      decks: fixtureDecks(),
      tts: FixedTtsEngine(const <String>{'es'}),
      progress: progress,
      now: now,
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

/// [target] of the fixture deck heard, typed, as a remembered word is.
Future<AppState> pumpTyped(WidgetTester tester, String target) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(spanish, skill: Skill.listening),
    preset: DrillPreset(target: target),
  ),
  state: spanishState(),
);

Future<void> typeAndCheck(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tapText(tester, l10nOf(tester).drillCheck);
}

void main() {
  group('a Hear choice', () {
    testWidgets('a new word plays, and its meaning is chosen from meanings; '
        'the right one records Hear, graded 3', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.listening),
        ),
        state: AppState.test(decks: fixtureDecks(), tts: tts),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(ChoiceDrill), findsOneWidget);
      final session = tester
          .widget<ChoiceDrill>(find.byType(ChoiceDrill))
          .session;
      final card = session.item.card;
      expect(session.ask, Ask.hearMeaning);
      expect(session.item.mode, DrillMode.listening);
      expect(find.text(l10n.drillChooseHeardMeaning), findsOneWidget);
      // The options are meanings; the word is not given away.
      expect(session.options, hasLength(DrillSession.optionCount));
      for (final option in session.options) {
        expect(find.text(option.native), findsOneWidget);
        expect(find.text(option.target), findsNothing);
      }
      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken.last.text, card.target);

      await tapText(tester, card.native);
      final event = state.progress.log.single;
      expect(event.cardId, card.id);
      expect(event.mode, DrillMode.listening);
      expect(event.grade, DrillSession.scheduledChoiceGrade);
      expect(event.grade, 3);
      expect(event.answerGiven, card.native);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      // Now the word is shown with its meaning.
      expect(find.text(card.target), findsOneWidget);
    });

    testWidgets('a wrong meaning records 1 and shows the right one', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.listening),
          preset: const DrillPreset(target: 'la casa', ask: Ask.hearMeaning),
        ),
        state: spanishState(),
      );
      final l10n = l10nOf(tester);
      final card = cardOf(state, spanish, 'la casa');
      final session = tester
          .widget<ChoiceDrill>(find.byType(ChoiceDrill))
          .session;
      final wrong = session.options.firstWhere((o) => o.id != card.id);
      await tapText(tester, wrong.native);
      expect(state.progress.log.single.grade, 1);
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer(card.native)), findsOneWidget);
    });
  });

  group('a Hear review', () {
    testWidgets('is chosen while new, typed once remembered, and chosen '
        'again once missed', (tester) async {
      final start = DateTime(2026, 9, 1, 19);
      final later = DateTime(2026, 10, 30, 19);
      final base = spanishState();
      await base.load();
      final card = cardOf(base, spanish, 'ir');
      final request = DrillRequest.deck(spanish, skill: Skill.listening);

      Future<SessionItem> asked(MemoryProgress progress) async {
        final state = spanishState(progress: progress, now: later);
        await state.load();
        return state
            .sessionItems(request)
            .firstWhere((i) => i.card.id == card.id);
      }

      final remembered = MemoryProgress()
        ..record(
          deckId: spanish,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: start,
        );
      expect((await asked(remembered)).ask, Ask.own);

      final missed = MemoryProgress()
        ..record(
          deckId: spanish,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 1,
          now: start,
        );
      expect((await asked(missed)).ask, Ask.hearMeaning);
    });

    testWidgets('typed asks for the meaning, and accepts a part of it', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpTyped(tester, 'ir');
      final l10n = l10nOf(tester);
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
      expect(session.hearsMeaning, isTrue);
      expect(find.text(l10n.drillTypeMeaning), findsOneWidget);
      // Each part of "to go, to leave" is the meaning.
      expect(
        session.acceptedAnswers,
        containsAll(<String>['to go', 'to leave']),
      );

      await typeAndCheck(tester, 'to leave');
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      final event = state.progress.log.single;
      expect(event.mode, DrillMode.listening);
      expect(event.grade, greaterThanOrEqualTo(4));
    });

    testWidgets('typed accepts the whole meaning and an alternative', (
      tester,
    ) async {
      usePhone(tester);
      for (final typed in <String>['the house', 'the home']) {
        await tester.pumpWidget(const SizedBox.shrink());
        final state = await pumpTyped(tester, 'la casa');
        await typeAndCheck(tester, typed);
        expect(
          find.text(l10nOf(tester).feedbackCorrect),
          findsOneWidget,
          reason: typed,
        );
        expect(state.progress.log.single.grade, greaterThanOrEqualTo(4));
      }
    });

    testWidgets('typed is graded with the articles of the language the '
        'learner speaks', (tester) async {
      usePhone(tester);
      final state = await pumpTyped(tester, 'la casa');
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
      await typeAndCheck(tester, 'house');
      // English "the" left out: right, as a Spanish "la" left out is in
      // Write, not a wrong answer.
      final graded = session.answer!.graded!;
      expect(graded.outcome, AnswerOutcome.closeDiacritics);
      expect(graded.droppedArticle, isTrue);
      expect(find.text(l10nOf(tester).feedbackWrong), findsNothing);
      expect(state.progress.log.single.grade, greaterThanOrEqualTo(3));
    });

    testWidgets('typed, the word itself is not its meaning', (tester) async {
      usePhone(tester);
      final state = await pumpTyped(tester, 'la casa');
      await typeAndCheck(tester, 'la casa');
      expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
      expect(state.progress.log.single.grade, 1);
    });

    testWidgets('typed, another word\'s meaning is wrong', (tester) async {
      usePhone(tester);
      final state = await pumpTyped(tester, 'la casa');
      await typeAndCheck(tester, 'the dog');
      expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
      expect(state.progress.log.single.grade, 1);
    });
  });

  group('script practice', () {
    testWidgets('is asked to type what was heard, new or not', (tester) async {
      final state = AppState.test(tts: FixedTtsEngine(const <String>{'hi'}));
      await state.load();
      expect(state.hearsForm(state.deckById(script)!.cards.first), isTrue);
      final items = state.sessionItems(
        DrillRequest.untaught(script, skill: Skill.listening),
      );
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.mode, DrillMode.listening);
        expect(item.state, isNull, reason: 'a new pair');
        expect(item.ask, Ask.own, reason: item.card.target);
      }
      // A deck that does not teach the alphabet chooses the meaning.
      final words = state.sessionItems(
        DrillRequest.untaught('hi-en-first-words', skill: Skill.listening),
      );
      expect(words.map((i) => i.ask), everyElement(Ask.hearMeaning));
    });

    testWidgets('a card is typed as heard, in the script', (tester) async {
      usePhone(tester);
      final card = (await () async {
        final s = AppState.test();
        await s.load();
        return s.deckById(script)!.cards.firstWhere((c) => c.reading != null);
      }());
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(script, skill: Skill.listening),
          preset: DrillPreset(target: card.target),
        ),
        state: AppState.test(tts: FixedTtsEngine(const <String>{'hi'})),
      );
      final l10n = l10nOf(tester);
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
      expect(session.hearsMeaning, isFalse);
      expect(session.acceptedAnswers.first, card.target);
      expect(find.text(l10n.drillTypeHeard), findsOneWidget);
      expect(find.text(l10n.drillTypeMeaning), findsNothing);

      await typeAndCheck(tester, card.target);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(state.progress.log.single.mode, DrillMode.listening);
      expect(state.progress.log.single.grade, 5);
    });

    testWidgets('its meaning typed is not what was heard', (tester) async {
      usePhone(tester);
      final card = (await () async {
        final s = AppState.test();
        await s.load();
        return s.deckById(script)!.cards.firstWhere((c) => c.reading != null);
      }());
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(script, skill: Skill.listening),
          preset: DrillPreset(target: card.target),
        ),
        state: AppState.test(tts: FixedTtsEngine(const <String>{'hi'})),
      );
      await typeAndCheck(tester, card.native);
      expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
      expect(state.progress.log.single.grade, 1);
    });
  });
}
