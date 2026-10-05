import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/data/romanisation_parser.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/romanised.dart';
import 'package:fluenough/core/models/romanisation.dart';

/// Readings in ISO 15919 letters (ADR-0025) are graded as leniently as the
/// plain readings they replaced: an answer typed as the old reading was is
/// still exact.

Romanisation bundled(String code) => parseRomanisation(
  File('decks/$code/$code-romanisation.yaml').readAsStringSync(),
  source: '$code-romanisation.yaml',
);

void main() {
  test('every bundled romanisation names ISO 15919 and how it is typed', () {
    for (final code in <String>['hi', 'mr', 'gu', 'bn', 'as', 'te', 'kn']) {
      final romanisation = bundled(code);
      expect(romanisation.standard, 'ISO 15919', reason: code);
      expect(romanisation.typed, isNotEmpty, reason: code);
    }
  });

  test('pālu and palu are both right, typed either way', () {
    final telugu = RomanisedSpelling(bundled('te'));
    for (final typed in <String>['palu', 'paalu', 'pālu']) {
      expect(
        telugu.grade(typed, <String>['pālu']).outcome,
        AnswerOutcome.exact,
        reason: typed,
      );
    }
  });

  test('a reading is typed as people type it: c as ch, ś as sh, m̐ as n', () {
    final hindi = RomanisedSpelling(bundled('hi'));
    expect(hindi.typedForm('cāy'), 'chāy');
    expect(hindi.typedForm('acchā'), 'achhā');
    expect(hindi.typedForm('śādī'), 'shādī');
    expect(hindi.typedForm('haim̐'), 'hain');
    expect(hindi.grade('chai', <String>['cāy']).outcome, AnswerOutcome.exact);
    expect(hindi.grade('shadi', <String>['śādī']).outcome, AnswerOutcome.exact);
  });

  test('the old readings, typed, still match the new ones', () {
    final fixture = jsonDecode(
      File('test/fixtures/typed_readings.json').readAsStringSync(),
    ) as List<dynamic>;
    final spellings = <String, RomanisedSpelling>{};
    for (final entry in fixture.cast<Map<String, dynamic>>()) {
      final code = entry['language'] as String;
      final spelling = spellings.putIfAbsent(
        code,
        () => RomanisedSpelling(bundled(code)),
      );
      final reading = entry['reading'] as String;
      expect(
        spelling.grade(entry['typed'] as String, <String>[reading]).outcome,
        AnswerOutcome.exact,
        reason: '$code: ${entry['typed']} for $reading',
      );
    }
  });
}
