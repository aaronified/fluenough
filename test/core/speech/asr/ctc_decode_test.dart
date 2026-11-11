import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/ctc_decode.dart';

// Same toy vocabulary as test/fixtures/asr/golden_ctc.json: blank is index 5.
const pieces = ['<unk>', '▁te', 'lu', 'gu', '▁x'];
const blank = 5;

void main() {
  group('decode', () {
    test('repeated ids collapse to one piece', () {
      expect(decode([1, 1, 1], pieces, blank), 'te');
    });

    test('repeats separated by a blank stay two pieces', () {
      expect(decode([1, blank, 1], pieces, blank), 'te te');
    });

    test('a blank between different pieces drops nothing', () {
      expect(decode([1, blank, 2, blank, 3], pieces, blank), 'telugu');
    });

    test('empty input gives an empty string', () {
      expect(decode([], pieces, blank), '');
    });

    test('only blanks give an empty string', () {
      expect(decode([blank, blank, blank], pieces, blank), '');
    });

    test('unknown pieces are dropped', () {
      expect(decode([0, 1, 0, 2], pieces, blank), 'telu');
    });

    test('spaces from the word-start mark are collapsed and trimmed', () {
      expect(decode([4, 4, blank, 4], pieces, blank), 'x x');
    });

    test('an id outside the pieces is dropped and logged once', () {
      final messages = <String>[];
      expect(
        decode([1, 9, blank, 9, 2], pieces, blank, log: messages.add),
        'telu',
      );
      expect(messages, hasLength(1));
      expect(messages.single, contains('2 id(s)'));
    });
  });
}
