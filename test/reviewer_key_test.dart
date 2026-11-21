// Signed reviewer keys (ADR-0058, W7): the key format, the checks and the
// keyring. The shared cases are in test/fixtures/reviewer_key_vectors.json,
// which tools/test_reviewer_keys.py reads too, so the app and the bot accept
// and refuse exactly the same keys. The key pair in the fixture is a
// throwaway made for tests.

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:fluenough/core/review/reviewer_key.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewerKeyStatus _status(String name) =>
    ReviewerKeyStatus.values.firstWhere((s) {
      final snake = s.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      );
      return snake == name;
    });

void main() {
  final all = jsonDecode(
    File('test/fixtures/reviewer_key_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final shared = all['reviewer_keys']! as Map<String, Object?>;
  final cases = (shared['cases']! as List<Object?>)
      .cast<Map<String, Object?>>();

  String publicKeysJson(String key) => jsonEncode(<String, Object?>{
    'keys': <Object?>[
      <String, Object?>{'version': shared['version'], 'public_key': key},
    ],
  });

  final keyring = ReviewerKeyring.fromAssets(
    publicKeysJson: publicKeysJson(shared['public_key']! as String),
    denylistText: (shared['denylist']! as List<Object?>).join('\n'),
  );

  group('the shared cases', () {
    for (final c in cases) {
      test(c['name']! as String, () {
        final got = keyring.check(c['key']! as String);
        expect(got.status, _status(c['status']! as String));
        if (c.containsKey('key_id')) {
          final key = got.key!;
          expect(key.keyId, c['key_id']);
          expect(key.courses, (c['courses']! as List<Object?>).cast<String>());
          expect(
            key.tier,
            c['tier'] == 'trusted'
                ? ReviewerTier.trusted
                : ReviewerTier.verified,
          );
          expect(key.issued, c['issued']);
        }
      });
    }
  });

  group('unlocks', () {
    test('a course or a whole language, and nothing else', () {
      final good = keyring.check(
        cases.firstWhere((c) => c['name'] == 'good Verified key')['key']!
            as String,
      );
      final key = good.key!;
      expect(key.unlocks(const ReviewPair('te', 'en')), isTrue);
      expect(key.unlocks(const ReviewPair('te', 'hi')), isFalse);
      expect(key.unlocks(const ReviewPair('bn', 'en')), isTrue);
      expect(key.unlocks(const ReviewPair('bn', 'hi')), isTrue);
      expect(key.unlocks(const ReviewPair('hi', 'en')), isFalse);
    });
  });

  group('the keyring', () {
    test('accepts nothing until a real public key is committed', () {
      final text = File('assets/reviewer/public_keys.json').readAsStringSync();
      final committed = ReviewerKeyring.fromAssets(
        publicKeysJson: text,
        denylistText: File('assets/reviewer/denylist.txt').readAsStringSync(),
      );
      // The committed file is a placeholder, or a real key, never the test
      // key of these tests.
      for (final key in committed.publicKeys.values) {
        expect(
          base64Url.encode(key).replaceAll('=', ''),
          isNot(shared['public_key']),
        );
      }
      final empty = ReviewerKeyring();
      expect(empty.enabled, isFalse);
      final good =
          cases.firstWhere((c) => c['name'] == 'good Verified key')['key']!
              as String;
      expect(empty.check(good).status, ReviewerKeyStatus.disabled);
      expect(empty.check('nonsense').status, ReviewerKeyStatus.malformed);
    });

    test('a placeholder or broken file is an empty keyring', () {
      expect(
        ReviewerKeyring.fromAssets(
          publicKeysJson: '{"keys":[{"version":1,"public_key":"PLACEHOLDER-NOT-A-REAL-KEY"}]}',
          denylistText: '',
        ).enabled,
        isFalse,
      );
      expect(
        ReviewerKeyring.fromAssets(
          publicKeysJson: 'not json',
          denylistText: '',
        ).enabled,
        isFalse,
      );
    });

    test('the denylist holds ids only, with comments', () {
      final ring = ReviewerKeyring.fromAssets(
        publicKeysJson: '{}',
        denylistText: '# comment\n0123456789ABCDEF  # shouted\nnot an id\n\nfedcba9876543210\n',
      );
      expect(ring.denylist, <String>{'0123456789abcdef', 'fedcba9876543210'});
    });

    test('the payload has one form', () {
      final payload = ReviewerKey.encodePayload(
        keyId: '0123456789abcdef',
        courses: <String>['te/en', 'bn', 'bn'],
        tier: ReviewerTier.verified,
        issued: '2026-11-21',
        version: 1,
      );
      expect(
        utf8.decode(payload!),
        '{"c":["bn","te/en"],"i":"2026-11-21","k":"0123456789abcdef",'
        '"p":1,"t":"v"}',
      );
      expect(
        ReviewerKey.encodePayload(
          keyId: '0123456789abcdef',
          courses: <String>['te'],
          tier: ReviewerTier.provisional,
          issued: '2026-11-21',
          version: 1,
        ),
        isNull,
      );
      expect(
        ReviewerKey.encodePayload(
          keyId: '0123456789abcdef',
          courses: <String>['te'],
          tier: ReviewerTier.verified,
          issued: '2026-02-30',
          version: 1,
        ),
        isNull,
      );
    });
  });
}
