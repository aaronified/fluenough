/// App versions as the deck index names them (`min_app`, ADR-0052): three
/// numbers, such as `0.7.1`. Free of Flutter, so that it is tested in
/// milliseconds.
library;

final RegExp _version = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

/// [text] as its three numbers, or null when it is not a version of the form
/// `major.minor.patch`.
List<int>? parseAppVersion(String text) {
  final match = _version.firstMatch(text);
  if (match == null) return null;
  return <int>[for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// Compares two versions of the form `major.minor.patch`: negative when [a]
/// is older than [b], zero when equal, positive when newer. Null when either
/// is not a version.
int? compareAppVersions(String a, String b) {
  final x = parseAppVersion(a);
  final y = parseAppVersion(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// Whether [app] is older than [minimum]. No [minimum], or a value that is
/// no version, is no requirement, and an [app] that is no version is taken
/// as new enough: a malformed value must never lock a learner out.
bool appIsOlderThan(String app, String? minimum) {
  if (minimum == null) return false;
  final order = compareAppVersions(app, minimum);
  return order != null && order < 0;
}

/// [value] when it is a version, else null: what the index's `min_app` is
/// read as, so that a bad value costs the requirement and never the index.
String? cleanMinApp(Object? value) =>
    value is String && parseAppVersion(value) != null ? value : null;

/// The newer of two optional versions.
String? newestAppVersion(String? a, String? b) {
  if (a == null) return b;
  if (b == null) return a;
  return (compareAppVersions(a, b) ?? 0) >= 0 ? a : b;
}
