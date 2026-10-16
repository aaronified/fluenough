// A language that is not typed, as the IPA (ADR-0041), is asked by choosing:
// in reviews, and in a lesson, hard words' check included.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

Card card(String id, String target, {String? pos}) => Card(
  id: id,
  deckId: 'ipa-basics',
  target: target,
  native: 'native $id',
  pos: pos,
);

SessionItem item(Card c, DrillMode mode) =>
    SessionItem(card: c, mode: mode, state: null);

void main() {
  group('reviewAsks', () {
    final production = <SessionItem>[
      item(card('a', 'ɒ'), DrillMode.production),
    ];

    test('production is typed unless the language is not typed', () {
      expect(
        reviewAsks(production, canChoose: (_) => true).single.ask,
        Ask.own,
      );
      expect(
        reviewAsks(
          production,
          canChoose: (_) => true,
          typed: (_) => true,
        ).single.ask,
        Ask.own,
      );
      expect(
        reviewAsks(
          production,
          canChoose: (_) => true,
          typed: (_) => false,
        ).single.ask,
        Ask.chooseWord,
      );
    });

    test('without enough to choose from, it stays as it was', () {
      expect(
        reviewAsks(
          production,
          canChoose: (_) => false,
          typed: (_) => false,
        ).single.ask,
        Ask.own,
      );
    });

    test('recognition is not changed by it', () {
      final asked = reviewAsks(
        <SessionItem>[item(card('a', 'ɒ'), DrillMode.recognition)],
        canChoose: (_) => true,
        typed: (_) => false,
      );
      expect(asked.single.ask, Ask.chooseMeaning);
    });
  });

  group('lessonQuestions', () {
    final hard = card('h', 'hola', pos: 'phrase');

    test('a hard card is checked by typing, or by choosing when not typed', () {
      expect(lessonQuestions(hard).first, (
        mode: DrillMode.production,
        ask: Ask.own,
      ));
      expect(lessonQuestions(hard, typed: false).first, (
        mode: DrillMode.production,
        ask: Ask.chooseWord,
      ));
    });

    test('no question of a lesson asks for a typed production', () {
      final cards = <Card>[
        card('e', 'ɒ'),
        card('m', 'ɒ ɔ'),
        hard,
      ];
      final items = lessonPlan(
        cards,
        modesOf: (_) => const {DrillMode.production, DrillMode.recognition},
        canChoose: (_, _) => true,
        typed: (_) => false,
      );
      expect(
        items.where((i) => i.mode == DrillMode.production),
        everyElement(
          predicate<SessionItem>(
            (i) => i.ask == Ask.chooseWord || i.ask == Ask.teach,
          ),
        ),
      );
    });
  });
}
