import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/sha256.dart';

void main() {
  // FIPS 180-4's examples, and lengths either side of a block's padding,
  // checked against Python's hashlib.
  test('matches the standard examples', () {
    expect(
      sha256Hex(const <int>[]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(
        utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('pads each length around a block right', () {
    const expected = <int, String>{
      55: '9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318',
      56: 'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a',
      64: 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
      119: '31eba51c313a5c08226adf18d4a359cfdfd8d2e816b13f4af952f7ea6584dcfb',
    };
    for (final MapEntry(key: length, value: hash) in expected.entries) {
      expect(sha256Hex(utf8.encode('a' * length)), hash, reason: '$length');
    }
  });

  test('hashes bytes, not characters', () {
    expect(
      sha256Hex(utf8.encode('ह' * 50)),
      'adcf81a3c1c0090503e45b643cde5d11c3b1f8a9bc446375a5d18425b17cd8bd',
    );
  });

  test('hashes a long message', () {
    expect(
      sha256Hex(utf8.encode('a' * 1000000)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });
}
