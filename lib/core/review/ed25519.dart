/// Ed25519 signature verification (RFC 8032), in Dart with [BigInt]. Pure
/// Dart, no Flutter; SHA-512 comes from `package:crypto`, already a
/// dependency.
///
/// Only verification is here: the app never signs. The owner signs reviewer
/// keys on their own machine with `tools/reviewer_keys.py`, whose
/// `tools/ed25519.py` is this same check in Python.
/// `test/fixtures/reviewer_key_vectors.json` holds RFC 8032's vectors and
/// the refusals, and both languages' tests read it. Not constant time, which
/// is fine: everything it handles is public.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;

/// Ed25519 verification.
abstract final class Ed25519 {
  static const int publicKeyLength = 32;
  static const int signatureLength = 64;

  static final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
  static final BigInt _q =
      (BigInt.one << 252) +
      BigInt.parse('27742317777372353535851937790883648493');
  static final BigInt _d =
      (-BigInt.from(121665) * BigInt.from(121666).modInverse(_p)) % _p;
  static final BigInt _sqrtM1 = BigInt.two.modPow((_p - BigInt.one) >> 2, _p);
  static final _Point _base = _basePoint();
  static final _Point _zero = _Point(
    BigInt.zero,
    BigInt.one,
    BigInt.one,
    BigInt.zero,
  );

  /// Whether [signature] is [publicKey]'s valid signature of [message].
  /// Never throws: a wrong length, a point off the curve or a scalar that is
  /// not reduced is false.
  static bool verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) {
    if (publicKey.length != publicKeyLength ||
        signature.length != signatureLength) {
      return false;
    }
    final a = _decompress(publicKey);
    final r = _decompress(Uint8List.sublistView(signature, 0, 32));
    if (a == null || r == null) return false;
    final s = _fromLittleEndian(Uint8List.sublistView(signature, 32));
    if (s >= _q) return false;
    final hashed = sha512.convert(<int>[
      ...Uint8List.sublistView(signature, 0, 32),
      ...publicKey,
      ...message,
    ]).bytes;
    final h = _fromLittleEndian(Uint8List.fromList(hashed)) % _q;
    return _equal(_multiply(s, _base), _add(r, _multiply(h, a)));
  }

  static BigInt _fromLittleEndian(List<int> bytes) {
    var value = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      value = (value << 8) | BigInt.from(bytes[i]);
    }
    return value;
  }

  static BigInt? _recoverX(BigInt y, int sign) {
    if (y >= _p) return null;
    final x2 =
        ((y * y - BigInt.one) * (_d * y * y + BigInt.one).modInverse(_p)) % _p;
    if (x2 == BigInt.zero) return sign == 1 ? null : BigInt.zero;
    var x = x2.modPow((_p + BigInt.from(3)) >> 3, _p);
    if ((x * x - x2) % _p != BigInt.zero) x = x * _sqrtM1 % _p;
    if ((x * x - x2) % _p != BigInt.zero) return null;
    if ((x.isOdd ? 1 : 0) != sign) x = _p - x;
    return x;
  }

  static _Point _basePoint() {
    final y = BigInt.from(4) * BigInt.from(5).modInverse(_p) % _p;
    final x = _recoverX(y, 0)!;
    return _Point(x, y, BigInt.one, x * y % _p);
  }

  static _Point? _decompress(Uint8List data) {
    if (data.length != 32) return null;
    var y = _fromLittleEndian(data);
    final sign = (y >> 255).toInt();
    y &= (BigInt.one << 255) - BigInt.one;
    final x = _recoverX(y, sign);
    if (x == null) return null;
    return _Point(x, y, BigInt.one, x * y % _p);
  }

  static _Point _add(_Point a, _Point b) {
    final aa = (a.y - a.x) * (b.y - b.x) % _p;
    final bb = (a.y + a.x) * (b.y + b.x) % _p;
    final c = BigInt.two * a.t * b.t * _d % _p;
    final dd = BigInt.two * a.z * b.z % _p;
    final e = bb - aa;
    final f = dd - c;
    final g = dd + c;
    final h = bb + aa;
    return _Point(e * f % _p, g * h % _p, f * g % _p, e * h % _p);
  }

  static _Point _multiply(BigInt scalar, _Point point) {
    var result = _zero;
    var addend = point;
    var s = scalar;
    while (s > BigInt.zero) {
      if (s.isOdd) result = _add(result, addend);
      addend = _add(addend, addend);
      s >>= 1;
    }
    return result;
  }

  static bool _equal(_Point a, _Point b) =>
      (a.x * b.z - b.x * a.z) % _p == BigInt.zero &&
      (a.y * b.z - b.y * a.z) % _p == BigInt.zero;
}

/// A point of the curve in extended coordinates.
class _Point {
  _Point(this.x, this.y, this.z, this.t);

  final BigInt x;
  final BigInt y;
  final BigInt z;
  final BigInt t;
}
