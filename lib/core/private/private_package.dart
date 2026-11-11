/// A private language package as the phone keeps it (#1017): the record the
/// index holds, and the check of a file's name inside a package. Pure Dart.
library;

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

  PrivatePackage withActive({required bool active}) => PrivatePackage(
    id: id,
    revision: revision,
    kind: kind,
    size: size,
    importedAt: importedAt,
    active: active,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'kind': kind,
    'size': size,
    'imported_at': importedAt.toUtc().toIso8601String(),
    'active': active,
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
