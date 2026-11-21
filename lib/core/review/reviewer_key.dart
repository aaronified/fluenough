/// Signed reviewer keys (ADR-0058, decision 8; issue #1658, work package W7).
/// Pure Dart.
///
/// A Verified reviewer gets a key from the owner, minted with
/// `tools/reviewer_keys.py` and signed with the owner's private Ed25519 key,
/// which no app, workflow or server ever holds. The key says which courses
/// it unlocks and its tier; the app checks the signature offline against the
/// public key(s) it ships (`assets/reviewer/public_keys.json`) and against
/// the denylist of revoked key ids (`assets/reviewer/denylist.txt`). The mail
/// bot checks the same key again.
///
/// The text of a key, `FLK1.<payload>.<signature>` in base64url without
/// padding: the payload is compact JSON with the keys `c` (courses, sorted:
/// `te/en` for one course, `te` for every course of a language), `i` (issue
/// date, YYYY-MM-DD), `k` (key id, 16 lower-case hex), `p` (the version of the
/// public key that checks it) and `t` (`v` Verified, `t` Trusted), written
/// in exactly the one form [ReviewerKey.encodePayload] gives, so a key is
/// accepted only in that form. The signature is Ed25519 over
/// `fluenough-reviewer-key-v1\n` and the payload bytes.
///
/// `tools/reviewer_keys.py` is the same format in Python, and
/// `test/fixtures/reviewer_key_vectors.json` is read by the tests of both.
///
/// **A key is a secret.** Nothing here logs or prints one, and the app never
/// shows one after it is accepted.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'ed25519.dart';
import 'review_pairs.dart';
import 'review_quorum.dart';

/// Why a key was or was not accepted.
enum ReviewerKeyStatus {
  /// Signed by a shipped public key, and not revoked.
  ok,

  /// Not a key, or not in its one form.
  malformed,

  /// No real public key is shipped yet (the committed file holds only a
  /// placeholder), so no key is accepted.
  disabled,

  /// Signed for a public-key version this app does not have.
  unknownKey,

  /// The signature does not match: forged or altered.
  badSignature,

  /// The owner revoked it: its id is on the denylist.
  revoked,
}

/// What a checked key says.
class ReviewerKey {
  const ReviewerKey({
    required this.keyId,
    required this.courses,
    required this.tier,
    required this.issued,
    required this.version,
  });

  /// 16 lower-case hex characters, never secret: it is what the denylist
  /// names.
  final String keyId;

  /// Sorted: `te/en` unlocks one course, `te` every course of Telugu.
  final List<String> courses;

  /// [ReviewerTier.verified] or [ReviewerTier.trusted].
  final ReviewerTier tier;

  /// The day the owner issued it, YYYY-MM-DD.
  final String issued;

  /// The version of the public key that checks it.
  final int version;

  /// Whether this key unlocks [pair]: the course itself, or its language.
  bool unlocks(ReviewPair pair) =>
      courses.contains(pair.target) || courses.contains(pair.key);

  static final RegExp _keyId = RegExp(r'^[0-9a-f]{16}$');
  static final RegExp _course = RegExp(r'^[a-z]{2,3}(/[a-z]{2,3})?$');
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static const int maxPayload = 1024;
  static const int maxCourses = 40;
  static const Map<String, ReviewerTier> _tierOf = <String, ReviewerTier>{
    'v': ReviewerTier.verified,
    't': ReviewerTier.trusted,
  };

  static bool _validDate(String text) {
    final match = _date.firstMatch(text);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (year < 1 || month < 1 || month > 12 || day < 1) return false;
    return day <= DateTime.utc(year, month + 1, 0).day;
  }

  /// The one form of a payload, or null for values a key may not hold.
  static Uint8List? encodePayload({
    required String keyId,
    required Iterable<String> courses,
    required ReviewerTier tier,
    required String issued,
    required int version,
  }) {
    final code = _tierOf.entries
        .where((e) => e.value == tier)
        .map((e) => e.key)
        .firstOrNull;
    final sorted = courses.toSet().toList()..sort();
    if (code == null ||
        !_keyId.hasMatch(keyId) ||
        sorted.isEmpty ||
        sorted.length > maxCourses ||
        !sorted.every(_course.hasMatch) ||
        !_validDate(issued) ||
        version < 1 ||
        version > 99) {
      return null;
    }
    final listed = sorted.map((c) => '"$c"').join(',');
    return Uint8List.fromList(
      ascii.encode(
        '{"c":[$listed],"i":"$issued","k":"$keyId","p":$version,"t":"$code"}',
      ),
    );
  }

  /// The key [payload] says, or null unless it is in its one form.
  static ReviewerKey? parsePayload(Uint8List payload) {
    if (payload.length > maxPayload) return null;
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(payload));
    } on FormatException {
      return null;
    }
    if (data is! Map<String, Object?>) return null;
    if (data.length != 5 ||
        !<String>{'c', 'i', 'k', 'p', 't'}.every(data.containsKey)) {
      return null;
    }
    final c = data['c'];
    final i = data['i'];
    final k = data['k'];
    final p = data['p'];
    final t = data['t'];
    if (c is! List<Object?> ||
        !c.every((x) => x is String) ||
        i is! String ||
        k is! String ||
        p is! int ||
        t is! String ||
        !_tierOf.containsKey(t)) {
      return null;
    }
    final tier = _tierOf[t]!;
    final again = encodePayload(
      keyId: k,
      courses: c.cast<String>(),
      tier: tier,
      issued: i,
      version: p,
    );
    if (again == null || !_same(again, payload)) return null;
    return ReviewerKey(
      keyId: k,
      courses: c.cast<String>().toList(),
      tier: tier,
      issued: i,
      version: p,
    );
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A key's check: its [status] and, when it was well formed, what it says
/// (also for a revoked one, so the app can name nothing but still know it).
class ReviewerKeyCheck {
  const ReviewerKeyCheck(this.status, [this.key]);

  final ReviewerKeyStatus status;
  final ReviewerKey? key;

  bool get ok => status == ReviewerKeyStatus.ok;
}

/// The public keys and the denylist a key is checked against.
class ReviewerKeyring {
  ReviewerKeyring({
    Map<int, Uint8List> publicKeys = const <int, Uint8List>{},
    Set<String> denylist = const <String>{},
  }) : publicKeys = Map<int, Uint8List>.unmodifiable(publicKeys),
       denylist = Set<String>.unmodifiable(denylist);

  /// From the text of `assets/reviewer/public_keys.json` and
  /// `assets/reviewer/denylist.txt`. An entry that is not a 32-byte key (the
  /// committed placeholder) is left out; unreadable text is an empty
  /// keyring, which accepts nothing.
  factory ReviewerKeyring.fromAssets({
    required String publicKeysJson,
    required String denylistText,
  }) {
    final keys = <int, Uint8List>{};
    try {
      final data = jsonDecode(publicKeysJson);
      final entries = data is Map<String, Object?> ? data['keys'] : null;
      if (entries is List<Object?>) {
        for (final entry in entries) {
          if (entry is! Map<String, Object?>) continue;
          final version = entry['version'];
          final raw = entry['public_key'];
          if (version is! int || raw is! String) continue;
          final bytes = _unbase64(raw);
          if (bytes != null && bytes.length == Ed25519.publicKeyLength) {
            keys[version] = bytes;
          }
        }
      }
    } on FormatException {
      // No keys: nothing is accepted.
    }
    final ids = <String>{};
    for (final line in const LineSplitter().convert(denylistText)) {
      final word = line.split('#').first.trim().toLowerCase();
      if (RegExp(r'^[0-9a-f]{16}$').hasMatch(word)) ids.add(word);
    }
    return ReviewerKeyring(publicKeys: keys, denylist: ids);
  }

  /// Version number to public key.
  final Map<int, Uint8List> publicKeys;

  /// Revoked key ids.
  final Set<String> denylist;

  /// Whether a real public key is shipped. False until the owner commits
  /// one, and then the feature is off: no key is accepted and the app shows
  /// no key row.
  bool get enabled => publicKeys.isNotEmpty;

  static const String prefix = 'FLK1.';
  static final Uint8List _domain = Uint8List.fromList(
    utf8.encode('fluenough-reviewer-key-v1\n'),
  );

  /// Checks the key [text] as pasted: whitespace anywhere is ignored, since a
  /// mail wraps lines. The order is the Python tool's: form, then whether a
  /// real public key is shipped, then the public-key version, the signature,
  /// and the denylist.
  ReviewerKeyCheck check(String text) {
    final plain = text.replaceAll(RegExp(r'\s+'), '');
    if (!plain.startsWith(prefix)) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.malformed);
    }
    final parts = plain.substring(prefix.length).split('.');
    if (parts.length != 2) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.malformed);
    }
    final payload = _unbase64(parts[0]);
    final signature = _unbase64(parts[1]);
    if (payload == null ||
        signature == null ||
        signature.length != Ed25519.signatureLength) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.malformed);
    }
    final key = ReviewerKey.parsePayload(payload);
    if (key == null) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.malformed);
    }
    if (!enabled) return const ReviewerKeyCheck(ReviewerKeyStatus.disabled);
    final public = publicKeys[key.version];
    if (public == null) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.unknownKey);
    }
    final signed = Uint8List.fromList(<int>[..._domain, ...payload]);
    if (!Ed25519.verify(public, signed, signature)) {
      return const ReviewerKeyCheck(ReviewerKeyStatus.badSignature);
    }
    if (denylist.contains(key.keyId)) {
      return ReviewerKeyCheck(ReviewerKeyStatus.revoked, key);
    }
    return ReviewerKeyCheck(ReviewerKeyStatus.ok, key);
  }

  /// [text] from base64url without padding, only in its one canonical form,
  /// or null.
  static Uint8List? _unbase64(String text) {
    if (!RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(text) || text.length % 4 == 1) {
      return null;
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(text));
      if (base64Url.encode(bytes).replaceAll('=', '') != text) return null;
      return Uint8List.fromList(bytes);
    } on FormatException {
      return null;
    }
  }
}
