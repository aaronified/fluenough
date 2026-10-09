import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/review/rater_code.dart';

void main() {
  test('a new code is FL-XXXX-XXXX-C in Crockford base32, and reads back', () {
    final random = Random(7);
    for (var i = 0; i < 200; i++) {
      final code = RaterCode.generate(random);
      final text = '$code';
      expect(
        text,
        matches(
          RegExp(
            r'^FL-[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}-'
            r'[0-9A-HJKMNP-TV-Z]$',
          ),
        ),
      );
      expect(RaterCode.tryParse(text), code);
    }
  });

  test('the alphabet leaves out I, L, O and U', () {
    expect(RaterCode.alphabet, hasLength(32));
    for (final letter in <String>['I', 'L', 'O', 'U']) {
      expect(RaterCode.alphabet.contains(letter), isFalse);
    }
  });

  test('codes are random: 200 made, 200 different', () {
    final random = Random(1);
    final codes = <RaterCode>{
      for (var i = 0; i < 200; i++) RaterCode.generate(random),
    };
    expect(codes, hasLength(200));
  });

  test('read loosely: any case, no dashes, I and L as 1, O as 0', () {
    final code = RaterCode.tryParse('${RaterCode.generate(Random(3))}')!;
    final plain = code.symbols;
    expect(RaterCode.tryParse(plain), code);
    expect(RaterCode.tryParse('fl-${plain.toLowerCase()}'), code);
    expect(
      RaterCode.tryParse(
        ' FL ${plain.substring(0, 4)} '
        '${plain.substring(4)} ',
      ),
      code,
    );
    // A code with a 1 and a 0 in it, typed with I and O.
    final withDigits = _codeWith(RegExp('[10]'));
    final typed = withDigits.symbols.replaceAll('1', 'I').replaceAll('0', 'O');
    expect(RaterCode.tryParse(typed), withDigits);
  });

  test('the check catches every single wrong symbol', () {
    final code = RaterCode.generate(Random(11));
    final plain = code.symbols;
    for (var at = 0; at < plain.length; at++) {
      for (final symbol in RaterCode.alphabet.split('')) {
        if (symbol == plain[at]) continue;
        final typo = plain.replaceRange(at, at + 1, symbol);
        expect(RaterCode.tryParse(typo), isNull, reason: typo);
      }
    }
  });

  test('the check catches two neighbours swapped', () {
    final random = Random(5);
    for (var i = 0; i < 300; i++) {
      final plain = RaterCode.generate(random).symbols;
      for (var at = 0; at < plain.length - 1; at++) {
        if (plain[at] == plain[at + 1]) continue;
        final swapped =
            '${plain.substring(0, at)}${plain[at + 1]}${plain[at]}'
            '${plain.substring(at + 2)}';
        expect(RaterCode.tryParse(swapped), isNull, reason: swapped);
      }
    }
  });

  test('not a code', () {
    for (final text in <String>[
      '',
      'FL-',
      'FL-7K3M-Q9TD',
      'FL-7K3M-Q9TD-66',
      'FL-7K3U-Q9TD-6',
      'hello world',
    ]) {
      expect(RaterCode.tryParse(text), isNull, reason: text);
    }
  });
}

/// A code whose symbols include a match of [pattern].
RaterCode _codeWith(RegExp pattern) {
  final random = Random(9);
  while (true) {
    final code = RaterCode.generate(random);
    if (pattern.hasMatch(code.symbols)) return code;
  }
}
