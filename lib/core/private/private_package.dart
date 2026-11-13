/// A private language package as the phone keeps it (#1017): the record the
/// index holds, and the check of a file's name inside a package. Pure Dart.
library;

/// The file of a package that says what it is.
const String privateManifestFile = 'manifest.yaml';

/// The most private packages the catalog reads at once (Plan-Private-
/// Languages, owner 2026-11-06): a fourth asks the learner to deactivate one.
const int maxActivePrivatePackages = 3;

/// What installing a package came to ([PrivateStore.install]).
enum PrivateInstall {
  /// It is installed (and active unless the caller asked for it inactive).
  installed,

  /// Installing it active would make more than [maxActivePrivatePackages]
  /// active; nothing was written. The learner deactivates one, or the
  /// package is installed inactive.
  needsDeactivation,

  /// It could not be installed; the store has logged why.
  failed,
}

/// What activating a package came to ([PrivateStore.activate]).
enum PrivateActivation {
  /// It is active.
  done,

  /// No such package.
  notInstalled,

  /// Another [maxActivePrivatePackages] are active already.
  needsDeactivation,

  /// It could not be changed; the store has logged why.
  failed,
}

/// What the phone knows of one installed private package: not its files, but
/// which package it is and whether the catalog reads it.
class PrivatePackage {
  const PrivatePackage({
    required this.id,
    required this.revision,
    required this.kind,
    required this.size,
    required this.importedAt,
    this.active = true,
    this.retired = const <String>[],
  });

  /// `fnpd-<code>`.
  final String id;

  /// The manifest's revision.
  final int revision;

  /// The manifest's kind, `new-language` or `modified-language`.
  final String kind;

  /// The bytes of the package's files, as installed.
  final int size;

  /// When it was installed, UTC.
  final DateTime importedAt;

  /// Whether the catalog reads it. An inactive package keeps its files.
  final bool active;

  /// The card ids an update dropped, sorted. A later revision may not give
  /// one of them to a card again (Plan-Private-Languages, 2.2): an id keys a
  /// learner's review history, so it is never reused.
  final List<String> retired;

  PrivatePackage withActive({required bool active}) => PrivatePackage(
    id: id,
    revision: revision,
    kind: kind,
    size: size,
    importedAt: importedAt,
    active: active,
    retired: retired,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'kind': kind,
    'size': size,
    'imported_at': importedAt.toUtc().toIso8601String(),
    'active': active,
    if (retired.isNotEmpty) 'retired': retired,
  };

  /// The record [json] holds, or null when it is not one.
  static PrivatePackage? fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    final id = json['id'];
    final revision = json['revision'];
    final kind = json['kind'];
    final size = json['size'];
    final at = json['imported_at'];
    final active = json['active'];
    final retired = json['retired'];
    if (id is! String ||
        revision is! int ||
        kind is! String ||
        size is! int ||
        at is! String) {
      return null;
    }
    final time = DateTime.tryParse(at);
    if (time == null) return null;
    return PrivatePackage(
      id: id,
      revision: revision,
      kind: kind,
      size: size,
      importedAt: time,
      active: active != false,
      retired: retired is List<Object?>
          ? (<String>{
              for (final r in retired)
                if (r is String) r,
            }.toList()..sort())
          : const <String>[],
    );
  }
}

/// Whether [path] is a file name a package may hold: relative, in folders
/// that are plain names, a YAML or JSON file. Refuses an absolute path, `..`,
/// a backslash, a drive, an empty segment and a hidden file, so that no
/// package file can be written outside its own folder.
bool isSafePackagePath(String path) {
  if (path.isEmpty || path.contains('\\') || path.contains(':')) return false;
  if (path.startsWith('/')) return false;
  if (!path.endsWith('.yaml') && !path.endsWith('.json')) return false;
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment.startsWith('.')) return false;
  }
  return true;
}
