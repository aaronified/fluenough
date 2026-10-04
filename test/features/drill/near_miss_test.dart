import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/features/drill/drill_session.dart';

/// A near miss waits for the learner to judge it, unless it is word for word
/// another card's answer: then it is that other word, and wrong.

const String future = 'te-en-grammar-future';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late DrillSession session;

  setUp(() async {
    state = AppState.test();
    await state.load();
    final queue = state.buildSession(
      DrillRequest.untaught(future, skill: Skill.grammar),
    );
    session = DrillSession(state: state, items: queue.items);
  });

  tearDown(() {
    session.dispose();
    state.dispose();
  });

  test("another cell's form, one letter off, is wrong", () {
    final card = session.item.card;
    // చేస్తాను against చేస్తావు or చేస్తాడు: the wrong person, not a slip.
    final other = state
        .deckById(future)!
        .cards
        .firstWhere(
          (c) =>
              c.target != card.target &&
              !card.altTarget.contains(c.target) &&
              levenshtein(c.target, card.target) == 1,
        );
    session.check(other.target);
    expect(session.answer!.graded!.outcome, AnswerOutcome.wrong);
    expect(session.answer!.awaitsJudgement, isFalse);
  });

  test('a slip that is no other answer still waits to be judged', () {
    final target = session.item.card.target;
    session.check(target.substring(0, target.length - 1));
    expect(session.answer!.graded!.outcome, AnswerOutcome.closeTypo);
    expect(session.answer!.awaitsJudgement, isTrue);
  });
}
