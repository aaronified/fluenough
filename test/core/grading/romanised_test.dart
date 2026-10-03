import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/romanised.dart';
import 'package:fluenough/core/models/romanisation.dart';

const Romanisation hindi = Romanisation(
  language: 'hi',
  scheme: 'Popular',
  equivalents: <List<String>>[
    ['a', 'aa'],
    ['i', 'ee', 'ii'],
    ['u', 'oo', 'uu'],
    ['v', 'w'],
    ['chh', 'ch'],
  ],
);

void main() {
  final spelling = RomanisedSpelling(hindi);

  test('each spelling a learner may type is written the decks\' way', () {
    expect(spelling.key('kitnaa'), spelling.key('kitna'));
    expect(spelling.key('paanee'), spelling.key('pani'));
    expect(spelling.key('doodh'), spelling.key('dudh'));
    expect(spelling.key('wahan'), spelling.key('vahan'));
  });

  test('case, accents, spaces and punctuation do not count', () {
    expect(spelling.key('Kitnā?'), spelling.key('kitna'));
    expect(spelling.key('kem chho'), spelling.key('kemchho'));
    expect(spelling.key('mul-mantra'), spelling.key('mulmantra'));
  });

  test('the longest spelling is read first, and once', () {
    // chh before ch, so achha is a + chh + a, not a + ch + ha.
    expect(spelling.key('achha'), spelling.key('acha'));
    expect(spelling.key('achha'), 'achha');
    // What a spelling is written as is never read again: aa is a, not a+a.
    expect(spelling.key('aaa'), 'aa');
  });

  test('without a romanisation file, only case, accents and spacing fold', () {
    final plain = RomanisedSpelling(null);
    expect(plain.key('Ka ā'), 'kaa');
    expect(plain.key('kitnaa'), isNot(plain.key('kitna')));
  });

  test('a romanised answer is exact, a near miss to judge, or wrong, and '
      'names the reading it matched', () {
    expect(
      spelling.grade('jaatee hoon', <String>['jati hun']),
      isA<GradedAnswer>()
          .having((g) => g.outcome, 'outcome', AnswerOutcome.exact)
          .having((g) => g.matched, 'matched', 'jati hun'),
    );
    expect(
      spelling.grade('jata hun', <String>['jati hun', 'jata hun']).matched,
      'jata hun',
    );
    expect(
      spelling.grade('jatu hun', <String>['jati hun']).outcome,
      AnswerOutcome.closeTypo,
    );
    expect(
      spelling.grade('khana', <String>['jati hun']).outcome,
      AnswerOutcome.wrong,
    );
    expect(
      spelling.grade('', <String>['jati hun']).outcome,
      AnswerOutcome.wrong,
    );
    expect(spelling.grade('x', const <String>[]).outcome, AnswerOutcome.wrong);
  });
}
