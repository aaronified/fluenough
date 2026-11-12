// What makes options look alike (lib/core/scheduling/look_alike.dart).
import 'package:fluenough/core/scheduling/look_alike.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts letters and words, not bytes', () {
    expect(runeLength('నేను'), 4);
    expect(wordCount('  I   am here '), 3);
    expect(wordCount(''), 0);
  });

  test('the band is a quarter of the length, never under the floor', () {
    expect(lengthBand('a' * 40), 10);
    expect(lengthBand('a' * 8), 5);
    expect(lengthBand('a' * 8, floor: 1), 2);
  });

  test('options in one band differ little in length and in words', () {
    expect(inOneBand('I am going home now', 'We are at the shop'), isTrue);
    // Far longer: the longest option would be a cue.
    expect(
      inOneBand('I am home', 'We went to the old market in the next town'),
      isFalse,
    );
    // The same length but a different number of words.
    expect(inOneBand('a b c d e f g', 'abcdefghijklm'), isFalse);
    // Symmetric.
    expect(
      inOneBand('We are at the shop', 'I am going home now'),
      inOneBand('I am going home now', 'We are at the shop'),
    );
  });
}
