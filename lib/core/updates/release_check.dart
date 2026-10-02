import 'dart:async';
import 'dart:convert';

/// Why a check found no release (ADR-0017).
enum ReleaseCheckFailure {
  /// GitHub could not be reached, or did not answer in time: no network,
  /// or one that goes nowhere.
  offline,

  /// GitHub refused for now: too many requests from this network. It
  /// allows 60 an hour from one address without an account.
  rateLimited,

  /// GitHub answered, but not with a release that can be read: an error,
  /// no release yet, or a tag that is not a version.
  badReply,
}

/// The newest release, or why it could not be found.
class LatestRelease {
  const LatestRelease(String this.version, {this.apkSha256}) : failure = null;

  const LatestRelease.failed(ReleaseCheckFailure this.failure)
    : version = null,
      apkSha256 = null;

  /// The release's version, its tag without the "v": `0.2.0`.
  final String? version;
  final ReleaseCheckFailure? failure;

  /// The SHA-256 of the release's [apkName], in lower-case hex, when GitHub
  /// gives one: the download is checked against it before it installs.
  final String? apkSha256;

  /// The file the release workflow attaches to every release.
  static const String apkName = 'app-release.apk';

  bool get ok => version != null;
}

/// Where the app asks for its newest release (ADR-0017). Narrow enough that
/// tests fake it; only `main.dart` names the one that reaches GitHub.
abstract interface class ReleaseCheckEngine {
  /// Asks for the newest published release. Never throws: a failure is a
  /// [LatestRelease.failed].
  Future<LatestRelease> latest();
}

/// No network: every check fails as [ReleaseCheckFailure.offline]. The
/// default, so that no test or gallery state reaches GitHub.
class NullReleaseCheck implements ReleaseCheckEngine {
  const NullReleaseCheck();

  @override
  Future<LatestRelease> latest() async =>
      const LatestRelease.failed(ReleaseCheckFailure.offline);
}

/// A release check that answers what it is told to. For tests and the
/// gallery.
class FixedReleaseCheck implements ReleaseCheckEngine {
  FixedReleaseCheck(this.answer, {this.gate});

  /// What every check answers. Can change between checks.
  LatestRelease answer;

  /// While set and not completed, a check waits on it, so that "Checking…"
  /// can be seen.
  Completer<void>? gate;

  /// How many times [latest] was called.
  int checks = 0;

  @override
  Future<LatestRelease> latest() async {
    checks++;
    await gate?.future;
    return answer;
  }
}

/// [text], a tag such as `v0.2.0` or a version such as `0.2.0`, as its
/// numbers, or null if it is not dotted numbers.
List<int>? parseVersion(String text) {
  final match = RegExp(r'^[vV]?(\d+(?:\.\d+)*)$').firstMatch(text.trim());
  if (match == null) return null;
  final numbers = <int>[];
  for (final part in match.group(1)!.split('.')) {
    // Too long for an int: not a version anyone tags.
    final n = int.tryParse(part);
    if (n == null) return null;
    numbers.add(n);
  }
  return numbers;
}

/// Compares two versions number by number, negative when [a] is earlier. A
/// missing number counts as 0, so 0.2 and 0.2.0 are the same.
int compareVersions(List<int> a, List<int> b) {
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Whether [latest] is a later version than [current]. False when either is
/// missing or not a version.
bool isNewerVersion(String? latest, String current) {
  final a = latest == null ? null : parseVersion(latest);
  final b = parseVersion(current);
  return a != null && b != null && compareVersions(a, b) > 0;
}

/// GitHub's reply to `releases/latest`, its [status] and [body], as a
/// release. The version is the release's `tag_name`; the APK's checksum is
/// its asset's `digest`, `sha256:` and 64 hex digits, if it has one.
LatestRelease releaseFromReply(int status, String body) {
  const bad = LatestRelease.failed(ReleaseCheckFailure.badReply);
  // GitHub says 403 for its hourly limit, and 429 for its burst limit.
  if (status == 403 || status == 429) {
    return const LatestRelease.failed(ReleaseCheckFailure.rateLimited);
  }
  if (status != 200) return bad;
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return bad;
  }
  if (json is! Map<String, Object?>) return bad;
  final tag = json['tag_name'];
  final numbers = tag is String ? parseVersion(tag) : null;
  if (numbers == null) return bad;
  return LatestRelease(numbers.join('.'), apkSha256: _apkSha256(json));
}

/// The digest GitHub gives [release]'s APK, or null if it gives none or one
/// that is not SHA-256.
String? _apkSha256(Map<String, Object?> release) {
  final assets = release['assets'];
  if (assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map || asset['name'] != LatestRelease.apkName) continue;
    final digest = asset['digest'];
    final hex = digest is String
        ? RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest)?.group(1)
        : null;
    return hex?.toLowerCase();
  }
  return null;
}
