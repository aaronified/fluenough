import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/canonical.dart';

void main() {
  const grader = AnswerGrader();

  void same(String typed, String expected, {required String because}) {
    expect(typed == expected, isFalse, reason: 'the test needs two spellings');
    expect(
      grader.grade(typed, expected).outcome,
      AnswerOutcome.exact,
      reason: because,
    );
    expect(
      grader.grade(expected, typed).outcome,
      AnswerOutcome.exact,
      reason: '$because, either way round',
    );
  }

  group('one letter, two spellings, compare equal', () {
    test('Devanagari nukta letters, precomposed or not', () {
      same('\u095B\u0930\u093E', '\u091C\u093C\u0930\u093E', because: 'ज़रा');
    });

    test('Devanagari: every precomposed nukta letter', () {
      const pairs = <(String, String)>[
        ('ऩ', 'ऩ'),
        ('ऱ', 'ऱ'),
        ('ऴ', 'ऴ'),
        ('क़', 'क़'),
        ('ख़', 'ख़'),
        ('ग़', 'ग़'),
        ('ज़', 'ज़'),
        ('ड़', 'ड़'),
        ('ढ़', 'ढ़'),
        ('फ़', 'फ़'),
        ('य़', 'य़'),
      ];
      for (final (composed, decomposed) in pairs) {
        same(
          composed,
          decomposed,
          because: 'U+${composed.runes.first.toRadixString(16)}',
        );
      }
    });

    test('Bengali nukta letters and two-part vowel signs', () {
      // য় in সময় (time), both ways.
      same('সময়', 'সময়', because: 'সময়');
      same('ড়', 'ড়', because: 'ড়');
      same('ঢ়', 'ঢ়', because: 'ঢ়');
      // ো in বোন (sister): one code point, or ে then া.
      same('বোন', 'বোন', because: 'বোন');
      same('ৌ', 'ৌ', because: 'ৌ');
    });

    test('Telugu two-part vowel sign', () {
      // ై in కై, one code point or two.
      same('కై', 'కై', because: 'కై');
    });

    test('Indic digits read as 0 to 9', () {
      same('२०२०', '2020', because: 'Devanagari २०२०');
      same('১৯৫০', '1950', because: 'Bengali ১৯৫০');
      same('౪౦౦౭', '4007', because: 'Telugu ౪౦౦౭');
    });

    test('zero-width joiners are ignored', () {
      same('क्‍ष', 'क्ष', because: 'ZWJ');
      same('क्‌ष', 'क्ष', because: 'ZWNJ');
    });
  });

  group('what stays different', () {
    test('a missing nukta is right but flagged, not exact', () {
      final graded = grader.grade('जरा', 'ज़रा');
      expect(graded.outcome, AnswerOutcome.closeDiacritics);
      expect(graded.foldedDiacritics, isTrue);
    });

    test('a different letter is still a miss', () {
      // सड़क (road) is not सरक.
      expect(grader.grade('सरक', 'सड़क').outcome, isNot(AnswerOutcome.exact));
    });

    test('Latin text passes through unchanged', () {
      for (final text in ['la casa', 'niño', 'straße', '']) {
        expect(identical(canonical(text), text), isTrue, reason: text);
      }
    });
  });
}
