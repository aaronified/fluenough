// Ed25519 verification (RFC 8032) in Dart, against RFC 8032's test vectors
// and the refusals in test/fixtures/reviewer_key_vectors.json, which
// tools/test_ed25519.py reads too: the Dart and Python verifiers stay equal.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluenough/core/review/ed25519.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _hex(String text) => Uint8List.fromList(<int>[
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

void main() {
  final vectors = jsonDecode(
    File('test/fixtures/reviewer_key_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final valid = (vectors['ed25519_valid']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final invalid = (vectors['ed25519_invalid']! as List<Object?>)
      .cast<Map<String, Object?>>();

  group('Ed25519.verify', () {
    for (final v in valid) {
      test('accepts ${v['name']}', () {
        expect(
          Ed25519.verify(
            _hex(v['public']! as String),
            _hex(v['message']! as String),
            _hex(v['signature']! as String),
          ),
          isTrue,
        );
      });
    }

    test('the first two are RFC 8032 test 1 and test 2', () {
      expect(
        valid[0]['public'],
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
      );
      expect(
        valid[1]['public'],
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
    });

    for (final v in invalid) {
      test('refuses: ${v['name']}', () {
        expect(
          Ed25519.verify(
            _hex(v['public']! as String),
            _hex(v['message']! as String),
            _hex(v['signature']! as String),
          ),
          isFalse,
        );
      });
    }

    test('does not throw on empty input', () {
      expect(Ed25519.verify(Uint8List(0), Uint8List(0), Uint8List(0)), isFalse);
    });
  });
}
