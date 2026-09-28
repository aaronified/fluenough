import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

void main() {
  final now = DateTime(2026, 9, 28, 19);

  group('SelfGrade', () {
    test('maps Again, Hard, Good, Easy to SM-2 grades 1, 3, 4, 5', () {
      expect(SelfGrade.values.map((g) => g.toSm2Grade()), [1, 3, 4, 5]);
    });

    test('sits on the same ladder as the machine-graded outcomes', () {
      expect(SelfGrade.again.toSm2Grade(), AnswerOutcome.wrong.toSm2Grade());
      expect(SelfGrade.hard.toSm2Grade(), AnswerOutcome.closeTypo.toSm2Grade());
      expect(
        SelfGrade.good.toSm2Grade(),
        AnswerOutcome.closeDiacritics.toSm2Grade(),
      );
      expect(SelfGrade.easy.toSm2Grade(), AnswerOutcome.exact.toSm2Grade());
    });

    test('only Again fails, for SM-2 and for the session score alike', () {
      for (final grade in SelfGrade.values) {
        expect(
          grade.isCorrect,
          grade.toSm2Grade() >= Sm2.passingGrade,
          reason: grade.name,
        );
      }
      expect(SelfGrade.again.isCorrect, isFalse);
    });

    test('Again on a new card is due tomorrow, not later in the session', () {
      final state = Sm2.next(
        Sm2State.fresh(now),
        SelfGrade.again.toSm2Grade(),
        now: now,
      );
      expect(state.intervalDays, 1);
      expect(state.dueAt, DateTime(2026, 9, 29, 19));
    });

    test('every passing rating gives a new card one day, then six', () {
      for (final grade in [SelfGrade.hard, SelfGrade.good, SelfGrade.easy]) {
        final first = Sm2.next(
          Sm2State.fresh(now),
          grade.toSm2Grade(),
          now: now,
        );
        expect(first.intervalDays, 1, reason: grade.name);
        final second = Sm2.next(first, grade.toSm2Grade(), now: now);
        expect(second.intervalDays, 6, reason: grade.name);
      }
    });
  });

  group('TypoJudgement', () {
    test('"I knew it" records the near miss grade, 3', () {
      expect(
        TypoJudgement.knewIt.toSm2Grade(),
        AnswerOutcome.closeTypo.toSm2Grade(),
      );
      expect(TypoJudgement.knewIt.isCorrect, isTrue);
    });

    test('"Count it wrong" records a failure, 1', () {
      expect(
        TypoJudgement.countWrong.toSm2Grade(),
        AnswerOutcome.wrong.toSm2Grade(),
      );
      expect(TypoJudgement.countWrong.isCorrect, isFalse);
    });
  });
}
