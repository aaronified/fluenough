// Which word of a minimal pair the phone heard (#423).
import 'package:fluenough/core/grading/pair_match.dart';
import 'package:flutter_test/flutter_test.dart';

HeardReading _r(String text, [double? confidence]) =>
    (text: text, confidence: confidence);

void main() {
  const kalam = <String>['కలం'];
  const kaalam = <String>['కాలం'];

  test('the best reading names the word it is, once cleaned up', () {
    expect(
      matchPair(
        <HeardReading>[_r(' కాలం ')],
        first: kalam,
        second: kaalam,
      )?.side,
      PairSide.second,
    );
    expect(
      matchPair(<HeardReading>[_r('కలం')], first: kalam, second: kaalam)?.side,
      PairSide.first,
    );
  });

  test('a third word matches neither, and a vowel mark is not forgiven', () {
    final other = matchPair(
      <HeardReading>[_r('కల')],
      first: kalam,
      second: kaalam,
    );
    expect(other?.side, isNull);
    expect(other?.heard, 'కల');
    // The second word without its length mark is not the second word.
    expect(
      matchPair(
        <HeardReading>[_r('కలం')],
        first: const <String>['కాలం'],
        second: const <String>['కులం'],
      )?.side,
      isNull,
    );
  });

  test('another reading counts only if the phone was fairly sure of it', () {
    for (final (confidence, side) in <(double?, PairSide?)>[
      (0.9, PairSide.second),
      (0.0, null),
      (null, null),
    ]) {
      expect(
        matchPair(
          <HeardReading>[_r('కల', 0.9), _r('కాలం', confidence)],
          first: kalam,
          second: kaalam,
        )?.side,
        side,
        reason: '$confidence',
      );
    }
  });

  test('nothing heard is no match at all', () {
    expect(
      matchPair(const <HeardReading>[], first: kalam, second: kaalam),
      isNull,
    );
  });
}
