import 'package:fluenough/core/models/ipa_clusters.dart';
import 'package:flutter_test/flutter_test.dart';

/// What one backspace takes from a typed IPA answer (#1221): a whole symbol
/// as it is seen, a letter with its marks, never half of one.

/// The text left after a backspace with the cursor at [offset].
String _after(String text, [int? offset]) {
  final at = offset ?? text.length;
  return text.replaceRange(ipaClusterStart(text, at), at, '');
}

void main() {
  group('a backspace takes one whole symbol', () {
    const symbols = <String, String>{
      'tie bar, ɡ͡b': 'ɡ͡b',
      'tie bar, t͡ʃ': 't͡ʃ',
      'tie bar below': 't͜ʃ',
      'nasal vowel, ã': 'ã',
      'nasal long vowel, ɑ̃ː': 'ɑ̃ː',
      'syllabic, n̩': 'n̩',
      'aspirated, kʰ': 'kʰ',
      'retroflex aspirated, ʈʰ': 'ʈʰ',
      'nasal long open-mid, ɛ̃ː': 'ɛ̃ː',
      'precomposed, ã': 'ã',
      'plain ASCII': 'b',
    };
    for (final MapEntry(:key, :value) in symbols.entries) {
      test(key, () {
        expect(_after('pa$value'), 'pa');
        expect(_after(value), isEmpty);
      });
    }

    test('stress goes on its own, before the letter it stands before', () {
      expect(_after('ˈa'), 'ˈ');
      expect(_after('ˈ'), isEmpty);
      expect(_after('aˈb'), 'aˈ');
      expect(_after('aˈ'), 'a', reason: 'the stress is not a mark on a');
    });

    test('a tie bar followed by nothing goes with its letter', () {
      expect(_after('pt͡'), 'p');
    });

    test('a symbol past U+FFFF is not split', () {
      expect(_after('p\u{1F600}'), 'p');
    });
  });

  group('the cursor can be anywhere', () {
    test('in the middle, the symbol before it goes and the rest stays', () {
      const text = 'pãt͡ʃi';
      // After ã: offset 3.
      expect(_after(text, 3), 'pt͡ʃi');
      // After t͡ʃ: offset 6.
      expect(_after(text, 6), 'pãi');
      expect(ipaClusterStart(text, 3), 1);
      expect(ipaClusterStart(text, 6), 3);
    });

    test('at the start, or before it, nothing goes', () {
      expect(ipaClusterStart('ab', 0), 0);
      expect(ipaClusterStart('ab', -3), 0);
    });

    test('between a letter and its mark, the letter goes with the part '
        'before the cursor', () {
      expect(ipaClusterStart('ãb', 1), 0);
    });

    test('past the end is the end', () {
      expect(ipaClusterStart('ab̃', 99), 1);
    });
  });
}
