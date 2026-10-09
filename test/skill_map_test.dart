import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';

/// One answer judges its own skill in full, and, if right, implies others in
/// part (ADR-0034; docs/research/skill-evidence.md).
void main() {
  final day = DateTime(2026, 10, 1, 9);
  const words = SkillMap(formHeardIn: <String>{'te-en-script'});

  LoggedReview review(
    DrillMode mode,
    int grade,
    DateTime at, {
    String deck = 'te-en-words',
  }) => (
    key: (cardId: 'te-0001', mode: mode),
    deckId: deck,
    at: at,
    grade: grade,
    elapsed: Duration.zero,
    answerGiven: 'x',
  );

  group('impliedBy', () {
    test('Write and Say imply Recognition', () {
      for (final mode in [DrillMode.production, DrillMode.speaking]) {
        expect(words.impliedBy(mode, 'te-en-words'), {
          DrillMode.recognition: SkillMap.implied,
        });
      }
    });

    test('Hear implies Recognition, or Write in script practice', () {
      expect(words.impliedBy(DrillMode.listening, 'te-en-words'), {
        DrillMode.recognition: SkillMap.implied,
      });
      expect(words.impliedBy(DrillMode.listening, 'te-en-script'), {
        DrillMode.production: SkillMap.implied,
      });
    });

    test('Recognition, grammar and reading imply nothing', () {
      for (final mode in [
        DrillMode.recognition,
        DrillMode.grammar,
        DrillMode.reading,
      ]) {
        expect(words.impliedBy(mode, 'te-en-words'), isEmpty);
      }
    });
  });

  group('Fsrs.implied', () {
    final state = Fsrs.next(null, 4, now: day);
    final later = day.add(const Duration(days: 3));

    test('moves stability part of the way to a Good review', () {
      final good = Fsrs.review(state, Rating.good, now: later).stability;
      final implied = Fsrs.implied(state, 0.5, now: later);
      expect(
        implied.stability,
        closeTo(state.stability + 0.5 * (good - state.stability), 1e-9),
      );
    });

    test('never moves the due date, the last review or the difficulty', () {
      final implied = Fsrs.implied(state, 0.5, now: later);
      expect(implied.dueAt, state.dueAt);
      expect(implied.lastReviewAt, state.lastReviewAt);
      expect(implied.difficulty, state.difficulty);
      expect(implied.repetitions, state.repetitions);
    });
  });

  group('replay', () {
    final later = day.add(const Duration(days: 3));
    final recognised = review(DrillMode.recognition, 4, day);

    test('a right Write answer raises Recognition\'s stability in part', () {
      final alone = replayReviews([recognised]).states;
      final withWrite = replayReviews([
        recognised,
        review(DrillMode.production, 4, later),
      ], skills: words).states;
      final rec = (cardId: 'te-0001', mode: DrillMode.recognition);
      expect(withWrite[rec]!.stability, greaterThan(alone[rec]!.stability));
      expect(withWrite[rec]!.dueAt, alone[rec]!.dueAt);
    });

    test('a miss does not touch it', () {
      final rec = (cardId: 'te-0001', mode: DrillMode.recognition);
      final missed = replayReviews([
        recognised,
        review(DrillMode.production, 1, later),
      ], skills: words).states;
      expect(
        missed[rec]!.stability,
        replayReviews([recognised]).states[rec]!.stability,
      );
    });

    test('a pair never asked is not started by it', () {
      final states = replayReviews([
        review(DrillMode.production, 4, day),
      ], skills: words).states;
      expect(
        states.containsKey((cardId: 'te-0001', mode: DrillMode.recognition)),
        isFalse,
      );
    });
  });
}
