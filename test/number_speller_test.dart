import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/number_rules_parser.dart';
import 'package:fluenough/core/models/number_rules.dart';
import 'package:fluenough/core/numbers/number_speller.dart';

NumberRules bundled(String code) => parseNumberRules(
  File('decks/$code/$code-numbers.yaml').readAsStringSync(),
  source: '$code-numbers.yaml',
);

Matcher refusedWith(String message) => throwsA(
  isA<DeckParseException>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

void main() {
  group('Hindi: every number to 99 is a word of its own', () {
    final hi = bundled('hi');

    test('2020, 1950 and 4007, the usual spelling first', () {
      expect(spellNumber(hi, 2020).first, 'दो हज़ार बीस');
      expect(spellNumber(hi, 2020), contains('दो हजार बीस'));
      expect(spellNumber(hi, 1950).first, 'एक हज़ार नौ सौ पचास');
      expect(spellNumber(hi, 4007).first, 'चार हज़ार सात');
      expect(spellNumber(hi, 1000).first, 'एक हज़ार');
    });

    test('2026 and 1999, with the other accepted spelling of 99', () {
      expect(spellNumber(hi, 2026).first, 'दो हज़ार छब्बीस');
      expect(spellNumber(hi, 1999).first, 'एक हज़ार नौ सौ निन्यानवे');
      expect(spellNumber(hi, 1999), contains('एक हज़ार नौ सौ निन्यानबे'));
    });

    test('every four-digit number can be spelled', () {
      expect(spellableNumbers(hi), hasLength(9000));
    });
  });

  group('Bengali: joined hundreds and a short দু', () {
    final bn = bundled('bn');

    test('2020 and 1950, with the other accepted spellings', () {
      final twenty20 = spellNumber(bn, 2020);
      expect(twenty20.first, 'দু হাজার কুড়ি');
      expect(
        twenty20,
        containsAll(<String>['দু হাজার বিশ', 'দুই হাজার কুড়ি']),
      );
      expect(spellNumber(bn, 1950).first, 'এক হাজার নশো পঞ্চাশ');
      expect(spellNumber(bn, 1950), contains('এক হাজার নয়শো পঞ্চাশ'));
    });

    test('2026, now that every number to 99 has its word', () {
      expect(spellNumber(bn, 2026).first, 'দু হাজার ছাব্বিশ');
      expect(spellNumber(bn, 2026), contains('দুই হাজার ছাব্বিশ'));
    });
  });

  group('Telugu: 21 to 99 built from parts, and forms before more digits', () {
    final te = bundled('te');

    test('2026', () {
      expect(spellNumber(te, 2026).first, 'రెండు వేల ఇరవై ఆరు');
    });

    test('a hundred or a thousand changes its form when more follows', () {
      expect(spellNumber(te, 2000).first, 'రెండు వేలు');
      expect(spellNumber(te, 1200).first, 'వెయ్యి రెండు వందలు');
      expect(spellNumber(te, 1150).first, 'వెయ్యి నూట యాభై');
      expect(spellNumber(te, 250).first, 'రెండు వందల యాభై');
    });

    test('every four-digit number can be spelled', () {
      expect(spellableNumbers(te), hasLength(9000));
    });
  });

  test('a random number is one the rules can spell', () {
    final hi = bundled('hi');
    final random = Random(54);
    for (var i = 0; i < 200; i++) {
      final n = randomNumber(hi, random)!;
      expect(n, inInclusiveRange(1000, 9999));
      expect(spellNumber(hi, n), isNotEmpty, reason: '$n');
    }
  });

  group('a file that is not number rules is refused', () {
    final good = File('decks/hi/hi-numbers.yaml').readAsStringSync();

    test('the wrong kind', () {
      expect(
        () => parseNumberRules(
          good.replaceFirst('kind: numbers', 'kind: vocab'),
          source: 'x',
        ),
        refusedWith('"kind: numbers"'),
      );
    });

    test('an id that does not name the language', () {
      expect(
        () => parseNumberRules(
          good.replaceFirst('id: hi-numbers', 'id: numbers'),
          source: 'x',
        ),
        refusedWith('id must be "hi-numbers"'),
      );
    });

    test('a hundred missing', () {
      expect(
        () => parseNumberRules(
          good.replaceFirst(RegExp(r'\n  9: .*सौ.*'), ''),
          source: 'x',
        ),
        refusedWith('hundreds needs an entry for 9'),
      );
    });

    test('a key that is not a number below a hundred', () {
      expect(
        () => parseNumberRules(
          good.replaceFirst('  1: "एक"', '  100: "एक"'),
          source: 'x',
        ),
        refusedWith('from 1 to 99'),
      );
    });
  });
}
