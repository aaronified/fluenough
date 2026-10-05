import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/romanised.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_session.dart';

/// Answers typed in Latin letters (#47, ADR-0022), graded against the
/// card's reading in its language's scheme.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  setUp(() async {
    state = AppState.test(tts: FixedTtsEngine(<String>{'hi'}));
    await state.load();
  });

  tearDown(() => state.dispose());

  /// A session in Latin letters on [deckId]'s cards in [skill], starting
  /// on the first card [where] picks.
  DrillSession latin(
    String deckId,
    Skill skill, {
    bool Function(Card card)? where,
  }) {
    final cards = state.deckById(deckId)!.cards;
    final first = cards.firstWhere(
      (c) => c.reading != null && (where?.call(c) ?? true),
    );
    final mode = skill.mode!;
    final session = DrillSession(
      state: state,
      items: <SessionItem>[
        for (final card in <Card>[first, ...cards.where((c) => c != first)])
          SessionItem(card: card, mode: mode, state: null),
      ],
      inputMode: InputMode.translit,
    );
    addTearDown(session.dispose);
    expect(session.transliterating, isTrue);
    return session;
  }

  test('before the script units, the reading counts in full', () {
    final session = latin('hi-en-market', Skill.production);
    expect(session.expectsScript, isFalse);
    session.check(session.item.card.reading!);
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
    expect(session.answer!.grade, 5);
  });

  test('past the script units, the reading counts as a hard recall', () {
    // Placed past Hindi's script units: the script is expected now.
    state.settings.placedDecks = <String>{
      for (final unit in state.courseUnits('hi'))
        for (final entry in unit)
          if (entry.id.contains('-script-')) entry.id,
    };
    final session = latin('hi-en-market', Skill.production);
    expect(session.expectsScript, isTrue);
    expect(
      DrillSession(state: state, items: session.items).inputMode,
      InputMode.script,
    );
    session.check(session.item.card.reading!);
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
    expect(session.answer!.grade, DrillSession.romanisedGrade);
  });

  test('a spelling learners also type is the same answer', () {
    final session = latin(
      'hi-en-market',
      Skill.production,
      where: (c) => c.reading!.contains('a'),
    );
    final reading = session.item.card.reading!;
    session.check(reading.replaceFirst('a', 'aa').toUpperCase());
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
  });

  test('the script is still accepted, in full', () {
    final session = latin('hi-en-market', Skill.production);
    session.check(session.item.card.target);
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
    expect(session.answer!.grade, 5);
  });

  test('what was heard can be typed in Latin letters', () {
    final session = latin('hi-en-market', Skill.listening);
    expect(session.canTransliterate, isTrue);
    session.check(session.item.card.reading!);
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
  });

  test('a grammar cell accepts the reading of each form it lists', () {
    // A cell whose other form is typed differently: Assamese আছোঁ and আছো
    // are both typed asu, so either matches the first.
    bool distinct(DeckEntry entry, Card card) {
      final spelling = RomanisedSpelling(state.romanisationFor(entry.language));
      String typed(String reading) => spelling.key(spelling.typedForm(reading));
      return card.altReading.isNotEmpty &&
          typed(card.altReading.first) != typed(card.reading!);
    }

    final deck = state.decks.firstWhere(
      (e) => e.cards.any((c) => distinct(e, c)),
    );
    final session = latin(
      deck.id,
      Skill.grammar,
      where: (c) => distinct(deck, c),
    );
    final card = session.item.card;
    session.check(card.altReading.first);
    expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
    expect(session.answer!.graded!.matched, card.altReading.first);
  });

  test("a near miss that is another card's reading is that word, and "
      'wrong', () {
    // Two cards of one deck whose readings, spelled one way, are one letter
    // apart: chai and chhai are one spelling, so not those.
    for (final deck in state.decks.where((e) => e.language.code == 'hi')) {
      final spelling = RomanisedSpelling(state.romanisationFor(deck.language));
      for (final card in deck.cards) {
        final reading = card.reading;
        if (reading == null || spelling.key(reading).length < 4) continue;
        final other = deck.cards
            .where(
              (o) =>
                  o.id != card.id &&
                  o.reading != null &&
                  levenshtein(
                        spelling.key(o.reading!),
                        spelling.key(reading),
                      ) ==
                      1,
            )
            .firstOrNull;
        if (other == null) continue;
        final session = latin(
          deck.id,
          Skill.production,
          where: (c) => c.id == card.id,
        );
        session.check(other.reading!);
        expect(session.answer!.graded!.outcome, AnswerOutcome.wrong);
        return;
      }
    }
    fail('no Hindi deck has two readings one letter apart');
  });
}
