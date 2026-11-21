// The blind-pass comparison (ADR-0058, W5): what two or more reviewers'
// separate answers add up to, per facet.

import 'package:fluenough/core/review/facet_compare.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'FL-AAAA-AAAA-A';
const _b = 'FL-BBBB-BBBB-B';
const _c = 'FL-CCCC-CCCC-C';

ReviewCheck _right(String rater) => ReviewCheck(rater: rater);

ReviewCheck _fix(String rater, [String? text]) => ReviewCheck(
  rater: rater,
  answer: FacetAnswer.flagged(<PointerTag>{
    PointerTag.spellingWrong,
  }, replacement: text),
);

void main() {
  const yeh = 'کي';
  const farsi = 'کی';

  test('two right answers agree it is right', () {
    final got = compareFacet(<ReviewCheck>[_right(_a), _right(_b)]);
    expect(got.status, FacetStatus.settled);
    expect(got.fixes, isEmpty);
    expect(got.needsHuman, isFalse);
  });

  test('the same fix after the language folds is agreed, no human step', () {
    final checks = <ReviewCheck>[_fix(_a, yeh), _fix(_b, farsi)];
    final plain = compareFacet(checks);
    expect(plain.status, FacetStatus.contested);
    final urdu = compareFacet(checks, language: 'ur');
    expect(urdu.status, FacetStatus.agreedFix);
    expect(urdu.agreedFix, yeh, reason: 'the first typed text, as typed');
    expect(urdu.fixes, <String>[yeh]);
    expect(urdu.needsHuman, isFalse);
    expect(compareFacet(checks, language: 'ps').status, FacetStatus.contested);
  });

  test('rival fixes are kept once each, in the order proposed', () {
    final got = compareFacet(<ReviewCheck>[
      _fix(_a, 'kala'),
      _fix(_b, 'kaala'),
      _fix(_c, ' kala '),
    ]);
    expect(got.status, FacetStatus.contested);
    expect(got.fixes, <String>['kala', 'kaala']);
    expect(got.needsPick, isTrue);
    expect(got.agreedFix, isNull);
  });

  test('right against a flag is contested and not a pick', () {
    final got = compareFacet(<ReviewCheck>[_right(_a), _fix(_b, 'x')]);
    expect(got.status, FacetStatus.contested);
    expect(got.fixes, <String>['x']);
    expect(got.needsPick, isFalse);
  });

  test('a tag and no fix is flagged with nothing to apply', () {
    final got = compareFacet(<ReviewCheck>[_fix(_a)]);
    expect(got.isFlaggedNoFix, isTrue);
    expect(got.needsHuman, isTrue);
  });

  test('a rater who answers again replaces the earlier answer', () {
    final got = compareFacet(<ReviewCheck>[_fix(_a, 'x'), _fix(_a, 'y')]);
    expect(got.fixes, <String>['y']);
  });

  test('a reviewer asking is left out of the rivals', () {
    final fixes = distinctFixesOf(<ReviewCheck>[
      _fix(_a, 'x'),
      _fix(_b, 'y'),
    ], exceptRater: ' fl-aaaa-aaaa-a ');
    expect(fixes, <String>['y']);
  });

  test('each facet is compared in the language its text is in', () {
    const pair = ReviewPair('ur', 'en');
    expect(languageOfFacet(Facet.word, pair), 'ur');
    expect(languageOfFacet(Facet.example, pair), 'ur');
    expect(languageOfFacet(Facet.meaning, pair), 'en');
    expect(languageOfFacet(Facet.note, pair), 'en');
    expect(languageOfFacet(Facet.reading, pair), isNull);
    expect(languageOfFacet(Facet.ipa, pair), isNull);
    expect(languageOfFacet(Facet.audio, pair), isNull);
  });

  test('answers of several reviewers compare facet by facet', () {
    final byRater = <String, Map<Facet, FacetAnswer>>{
      _a: <Facet, FacetAnswer>{
        Facet.word: FacetAnswer.flagged(<PointerTag>{
          PointerTag.spellingWrong,
        }, replacement: yeh),
        Facet.meaning: const FacetAnswer.right(),
      },
      _b: <Facet, FacetAnswer>{
        Facet.word: FacetAnswer.flagged(<PointerTag>{
          PointerTag.spellingWrong,
        }, replacement: farsi),
        Facet.meaning: const FacetAnswer.right(),
      },
    };
    final got = compareAnswers(byRater, pair: const ReviewPair('ur', 'en'));
    expect(got.keys.toList(), <Facet>[Facet.word, Facet.meaning]);
    expect(got[Facet.word]!.status, FacetStatus.agreedFix);
    expect(got[Facet.meaning]!.status, FacetStatus.settled);
    // With no course the word is compared by NFC and white space alone.
    expect(compareAnswers(byRater)[Facet.word]!.status, FacetStatus.contested);
  });

  test('case is folded only when the facet says so', () {
    final checks = <ReviewCheck>[_fix(_a, 'Kala'), _fix(_b, 'kala')];
    expect(compareFacet(checks).status, FacetStatus.contested);
    expect(
      compareFacet(checks, caseInsensitive: true).status,
      FacetStatus.agreedFix,
    );
  });
}
