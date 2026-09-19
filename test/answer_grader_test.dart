import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';

void main() {
  const spanish = AnswerGrader(articles: ['el', 'la', 'los', 'las']);
  const plain = AnswerGrader();

  group('exact matching', () {
    test('identical answers', () {
      expect(plain.grade('la casa', 'la casa').outcome, AnswerOutcome.exact);
    });

    test('ignores case, surrounding space and terminal punctuation', () {
      for (final given in ['La Casa', '  la casa  ', 'la casa.', '¿la casa?']) {
        expect(plain.grade(given, 'la casa').outcome, AnswerOutcome.exact,
            reason: 'for input "$given"');
      }
    });

    test('collapses internal whitespace', () {
      expect(plain.grade('la    casa', 'la casa').outcome, AnswerOutcome.exact);
    });

    test('accepts a declared alternate', () {
      final result = plain.grade('the home', 'the house',
          alternates: const ['the home']);
      expect(result.outcome, AnswerOutcome.exact);
      expect(result.matched, 'the home');
    });
  });

  group('diacritics', () {
    test('a missing accent is correct but flagged', () {
      expect(plain.grade('pais', 'país').outcome, AnswerOutcome.closeDiacritics);
      expect(plain.grade('habláis', 'hablais').outcome,
          AnswerOutcome.closeDiacritics);
    });

    test('an accent on the wrong letter is still only a diacritic miss', () {
      expect(plain.grade('páis', 'país').outcome, AnswerOutcome.closeDiacritics);
    });

    test('folds German and Nordic letters', () {
      expect(plain.grade('grosse', 'größe').outcome,
          AnswerOutcome.closeDiacritics);
      expect(plain.grade('smorrebrod', 'smørrebrød').outcome,
          AnswerOutcome.closeDiacritics);
    });

    test('the matched answer is reported so the UI can show it', () {
      expect(plain.grade('pais', 'país').matched, 'país');
    });
  });

  group('articles', () {
    test('a dropped article is accepted when the language declares them', () {
      expect(spanish.grade('casa', 'la casa').outcome.isCorrect, isTrue);
    });

    test('a language with no declared articles does not drop words', () {
      expect(plain.grade('casa', 'la casa').outcome, AnswerOutcome.wrong);
    });

    test('an article that is the whole answer is not stripped away', () {
      expect(spanish.grade('la', 'la').outcome, AnswerOutcome.exact);
    });
  });

  group('typos', () {
    test('one wrong character in a short answer is a near miss', () {
      expect(plain.grade('gracia', 'gracias').outcome, AnswerOutcome.closeTypo);
    });

    test('long answers get a more generous allowance', () {
      expect(plain.grade('trabajamso', 'trabajamos').outcome,
          AnswerOutcome.closeTypo);
    });

    test('a short answer does not get the generous allowance', () {
      // Distance 2 on a three character answer is rejected, where the same
      // distance on the ten character answer above was accepted.
      expect(plain.grade('sre', 'ser').outcome, AnswerOutcome.wrong);
      expect(plain.grade('xyz', 'ser').outcome, AnswerOutcome.wrong);
    });

    test('a different word is wrong, not a typo', () {
      expect(plain.grade('perro', 'casa').outcome, AnswerOutcome.wrong);
    });
  });

  group('empty input', () {
    test('is always wrong', () {
      expect(plain.grade('', 'casa').outcome, AnswerOutcome.wrong);
      expect(plain.grade('   ', 'casa').outcome, AnswerOutcome.wrong);
    });
  });

  group('SM-2 grade mapping', () {
    test('a typo is not punished as a forgotten card', () {
      expect(AnswerOutcome.closeTypo.toSm2Grade(),
          greaterThanOrEqualTo(3));
    });

    test('outcomes map monotonically', () {
      expect(AnswerOutcome.exact.toSm2Grade(),
          greaterThan(AnswerOutcome.closeDiacritics.toSm2Grade()));
      expect(AnswerOutcome.closeDiacritics.toSm2Grade(),
          greaterThan(AnswerOutcome.closeTypo.toSm2Grade()));
      expect(AnswerOutcome.closeTypo.toSm2Grade(),
          greaterThan(AnswerOutcome.wrong.toSm2Grade()));
    });
  });

  group('levenshtein', () {
    test('computes the usual distances', () {
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('casa', 'casa'), 0);
      expect(levenshtein('', 'casa'), 4);
      expect(levenshtein('casa', ''), 4);
    });

    test('bails out once the cutoff is exceeded', () {
      expect(levenshtein('abc', 'xyz', cutoff: 1), greaterThan(1));
      expect(levenshtein('a', 'abcdefghij', cutoff: 2), greaterThan(2));
    });

    test('still returns exact distances within the cutoff', () {
      expect(levenshtein('gracia', 'gracias', cutoff: 2), 1);
    });
  });
}
