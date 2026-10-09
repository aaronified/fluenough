import 'dart:math';

/// A reviewer's rater code (docs/plans/deck-browser.md, "Review in the app,
/// by mail"): made on the phone when reviewing is turned on, written
/// `FL-XXXX-XXXX-C`.
///
/// The eight X are random symbols of Crockford's base32, which leaves out
/// I, L, O and U so that a code read aloud or copied by hand is not
/// misread: 40 bits from the phone's secure random source. C is a check
/// symbol from the same alphabet. It is a weighted sum in GF(32), each
/// symbol weighted by a different power of a primitive element, so that it
/// catches any single wrong symbol and any two neighbours swapped.
/// `tools/mail_to_issues.py` checks it the same way.
///
/// Rater codes are public: the issues name them, and a deck lists the codes
/// that helped build it. A review is accepted only from the mail address
/// the code's first review came from.
class RaterCode {
  const RaterCode._(this.symbols);

  /// Crockford's base32: digits, then letters without I, L, O and U.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// What every code starts with.
  static const String prefix = 'FL';

  /// The random symbols, without the check.
  static const int length = 8;

  /// The nine symbols, the check last, without the prefix or dashes.
  final String symbols;

  /// A new code, from [random], which must be the phone's secure source
  /// outside tests: `Random.secure()`.
  factory RaterCode.generate(Random random) {
    final body = String.fromCharCodes(<int>[
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ]);
    return RaterCode._('$body${checkSymbol(body)}');
  }

  /// [text] as a code, or null if it is not one or its check fails.
  ///
  /// Read loosely, as Crockford's base32 is: any case, with or without the
  /// `FL` and the dashes or spaces, and I and L read as 1, O as 0.
  static RaterCode? tryParse(String text) {
    var plain = text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (plain.startsWith(prefix) && plain.length == prefix.length + 9) {
      plain = plain.substring(prefix.length);
    }
    if (plain.length != length + 1) return null;
    plain = plain.replaceAll(RegExp('[IL]'), '1').replaceAll('O', '0');
    for (final unit in plain.codeUnits) {
      if (!alphabet.codeUnits.contains(unit)) return null;
    }
    final body = plain.substring(0, length);
    if (checkSymbol(body) != plain.substring(length)) return null;
    return RaterCode._(plain);
  }

  /// The check symbol of [body], eight symbols of [alphabet].
  static String checkSymbol(String body) {
    var sum = 0;
    var weight = 1;
    for (final unit in body.codeUnits) {
      weight = _times(weight, 2);
      sum ^= _times(weight, alphabet.indexOf(String.fromCharCode(unit)));
    }
    return alphabet[sum];
  }

  /// [a] times [b] in GF(32), whose elements are 5-bit numbers, modulo
  /// x⁵ + x² + 1, which is primitive: 2, which is x, has order 31.
  static int _times(int a, int b) {
    var product = 0;
    var x = a;
    var y = b;
    while (y > 0) {
      if (y & 1 == 1) product ^= x;
      y >>= 1;
      x <<= 1;
      if (x & 0x20 != 0) x ^= 0x25;
    }
    return product;
  }

  /// The code as it is shown and sent: `FL-7K3M-Q9TD-6`.
  @override
  String toString() =>
      '$prefix-${symbols.substring(0, 4)}-${symbols.substring(4, 8)}-'
      '${symbols.substring(8)}';

  @override
  bool operator ==(Object other) =>
      other is RaterCode && other.symbols == symbols;

  @override
  int get hashCode => symbols.hashCode;
}
