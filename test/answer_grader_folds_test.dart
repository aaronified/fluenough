import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';

/// The flags that tell the interface *why* an answer was a close miss.
///
/// The outcome itself is unchanged by them — an article miss is still
/// `closeDiacritics`, graded 4 — so these tests pin only which message the
/// drill can pick: "mind the accent", "keep the article", or both.
void main() {
  const spanish = AnswerGrader(articles: ['el', 'la', 'los', 'las', 'un']);

  GradedAnswer grade(String given, String expected) =>
      spanish.grade(given, expected);

  test('a missing accent folds the diacritics and keeps the article', () {
    final result = grade('el nino', 'el niño');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.foldedDiacritics, isTrue);
    expect(result.droppedArticle, isFalse);
  });

  test('a missing article drops the article and folds nothing', () {
    final result = grade('niño', 'el niño');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.droppedArticle, isTrue);
    expect(result.foldedDiacritics, isFalse);
  });

  test('an extra article is dropped the same way', () {
    final result = grade('la casa', 'casa');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.droppedArticle, isTrue);
    expect(result.foldedDiacritics, isFalse);
  });

  test('the wrong article counts as a dropped one', () {
    final result = grade('la niño', 'el niño');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.droppedArticle, isTrue);
    expect(result.foldedDiacritics, isFalse);
  });

  test('both missing sets both flags', () {
    final result = grade('nino', 'el niño');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.droppedArticle, isTrue);
    expect(result.foldedDiacritics, isTrue);
  });

  test('an accent typed on the article itself is an accent miss', () {
    final result = grade('él niño', 'el niño');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.foldedDiacritics, isTrue);
    expect(result.droppedArticle, isFalse);
  });

  test('the flags describe the alternate that matched', () {
    final result = spanish.grade(
      'nina',
      'la mujer',
      alternates: const ['la niña'],
    );
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.matched, 'la niña');
    expect(result.droppedArticle, isTrue);
    expect(result.foldedDiacritics, isTrue);
  });

  test('a language without articles only ever folds diacritics', () {
    const plain = AnswerGrader();
    final result = plain.grade('pais', 'país');
    expect(result.outcome, AnswerOutcome.closeDiacritics);
    expect(result.foldedDiacritics, isTrue);
    expect(result.droppedArticle, isFalse);
  });

  test('every other outcome leaves both flags false', () {
    for (final (given, expected) in [
      ('el niño', 'el niño'), // exact
      ('el nino', 'el nido'), // typo
      ('la mesa', 'el niño'), // wrong
      ('', 'el niño'), // empty
    ]) {
      final result = grade(given, expected);
      expect(result.outcome, isNot(AnswerOutcome.closeDiacritics));
      expect(result.droppedArticle, isFalse, reason: given);
      expect(result.foldedDiacritics, isFalse, reason: given);
    }
  });
}
