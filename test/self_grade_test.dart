import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

void main() {
  final now = DateTime(2026, 9, 28, 19);

  group('SelfGrade', () {
    test('maps Again, Hard, Good, Easy to grades 1, 3, 4, 5', () {
      expect(SelfGrade.values.map((g) => g.toGrade()), [1, 3, 4, 5]);
    });

    test('sits on the same ladder as the machine-graded outcomes', () {
      expect(SelfGrade.again.toGrade(), AnswerOutcome.wrong.toGrade());
      expect(SelfGrade.hard.toGrade(), AnswerOutcome.closeTypo.toGrade());
      expect(SelfGrade.good.toGrade(), AnswerOutcome.closeDiacritics.toGrade());
      expect(SelfGrade.easy.toGrade(), AnswerOutcome.exact.toGrade());
    });

    test('only Again fails, for FSRS and for the session score alike', () {
      for (final grade in SelfGrade.values) {
        expect(
          grade.isCorrect,
          grade.toGrade() >= Fsrs.passingGrade,
          reason: grade.name,
        );
      }
      expect(SelfGrade.again.isCorrect, isFalse);
    });

    test('Again on a new card is due tomorrow, not later in the session', () {
      final state = Fsrs.next(
        null,
        SelfGrade.again.toGrade(),
        now: now,
        rated: true,
      );
      expect(state.intervalDays, 1);
      expect(state.dueAt, DateTime(2026, 9, 29, 19));
    });

    test('a better rating gives a new card a longer first interval', () {
      final days = [
        for (final grade in SelfGrade.values)
          Fsrs.next(null, grade.toGrade(), now: now, rated: true).intervalDays,
      ];
      expect(days, [1, 1, 2, 8]);
    });
  });

  group('TypoJudgement', () {
    test('"I knew it" records the near miss grade, 3', () {
      expect(TypoJudgement.knewIt.toGrade(), AnswerOutcome.closeTypo.toGrade());
      expect(TypoJudgement.knewIt.isCorrect, isTrue);
    });

    test('"Count it wrong" records a failure, 1', () {
      expect(TypoJudgement.countWrong.toGrade(), AnswerOutcome.wrong.toGrade());
      expect(TypoJudgement.countWrong.isCorrect, isFalse);
    });
  });
}
