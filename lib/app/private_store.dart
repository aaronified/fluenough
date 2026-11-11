import 'dart:convert';
import 'dart:io';

import '../core/logs/log_entry.dart';
import '../core/private/private_package.dart';
import 'app_log.dart';
import 'deck_catalog.dart';

/// Where a private package's path starts, so the catalog can tell it from a
/// bundled deck and from a single added file (#1017). A file is
/// `private/<package id>/<path in the package>`.
const String privateDeckPrefix = 'private/';

/// The file of a package that says what it is. Read with [DeckSource.read],
/// never listed with the deck files.
const String privateManifestName = 'manifest.yaml';

/// The private language packages a learner installed (#1017), kept apart
/// from the bundled and added decks. As a [DeckSource] it lists and reads the
/// YAML files of the **active** packages only, under [privateDeckPrefix], so
/// an inactive package costs nothing at launch.
///
/// Every method catches what can go wrong and logs it (never silent); a
/// method that changes the store says whether it did.
abstract interface class PrivateStore implements DeckSource {
  /// Every installed package, active or not, by id.
  Future<List<PrivatePackage>> packages();

  /// Installs the package [id] from [files], keyed by their path in the
  /// package, in one step: the files are written aside, then put in place,
  /// then the index is written. A failure leaves what was installed before
  /// as it was. Replaces any earlier install of [id] and keeps its
  /// active flag. True when it installed.
  Future<bool> install(
    String id,
    Map<String, String> files, {
    required int revision,
    required String kind,
  });

  /// Marks [id] active or not. True when it did.
  Future<bool> setActive(String id, {required bool active});

  /// Deletes the package [id]. Review history stays. True when it did.
  Future<bool> remove(String id);
}

/// The paths of the files a catalog reads from [files] of the package [id]:
/// its YAML files but not the manifest, under [privateDeckPrefix].
List<String> _catalogPaths(String id, Iterable<String> files) => <String>[
  for (final file in files)
    if (file.endsWith('.yaml') && file != privateManifestName)
      '$privateDeckPrefix$id/$file',
];

/// Splits `private/<id>/<file>` into the package id and the file, or null.
(String, String)? _split(String path) {
  if (!path.startsWith(privateDeckPrefix)) return null;
  final rest = path.substring(privateDeckPrefix.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) return null;
  return (rest.substring(0, slash), rest.substring(slash + 1));
}

/// Whether [id] is a name this store keeps a package under: letters, digits
/// and hyphens, so it can never name a place outside its own folder.
bool _isPackageId(String id) =>
    id != 'staging' && _packageIdPattern.hasMatch(id);

final RegExp _packageIdPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// [PrivateStore] in a directory of the app's own storage, which an update
/// leaves alone.
///
/// ```
/// <root>/index.json          the packages
/// <root>/<package id>/...    a package's files
/// <root>/staging/            an install in progress, deleted after it
/// ```
class FilePrivateStore implements PrivateStore {
  FilePrivateStore(this.root, {AppLog? log, DateTime Function()? clock})
    : _log = log,
      _clock = clock ?? DateTime.now;

  final Directory root;
  final AppLog? _log;
  final DateTime Function() _clock;

  File get _index => File('${root.path}/index.json');
  Directory get _staging => Directory('${root.path}/staging');
  Directory _folder(String id) => Directory('${root.path}/$id');

  Future<void>? _recovered;

  /// Once per launch, before anything else: a crash between moving a package
  /// aside and moving its new files in leaves `staging/<id>.old` and no
  /// `<id>`. Puts the old package back, then clears staging.
  Future<void> _recover() async {
    try {
      if (!await _staging.exists()) return;
      await for (final entity in _staging.list()) {
        if (entity is! Directory || !entity.path.endsWith('.old')) continue;
        final name = entity.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .replaceFirst(RegExp(r'\.old$'), '');
        if (!_isPackageId(name)) continue;
        final target = _folder(name);
        if (!await target.exists()) {
          await entity.rename(target.path);
          _log?.warning('Private decks: restored a package after a crash');
        }
      }
      await _staging.delete(recursive: true);
    } on Object catch (e, stack) {
      _fail('could not recover after a crash', e, stack);
    }
  }

  void _fail(String what, Object error, StackTrace stack) =>
      _log?.error(describeError('Private decks: $what', error, stack));

  @override
  Future<List<PrivatePackage>> packages() async {
    await (_recovered ??= _recover());
    try {
      if (!await _index.exists()) return const <PrivatePackage>[];
      final json = jsonDecode(await _index.readAsString());
      final list = json is Map<Object?, Object?> ? json['packages'] : null;
      if (list is! List<Object?>) {
        _log?.warning('Private decks: the index has no list of packages');
        return const <PrivatePackage>[];
      }
      return <PrivatePackage>[
        for (final item in list) ?PrivatePackage.fromJson(item),
      ];
    } on Object catch (e, stack) {
      _fail('could not read the index', e, stack);
      return const <PrivatePackage>[];
    }
  }

  Future<void> _writeIndex(List<PrivatePackage> packages) async {
    await root.create(recursive: true);
    final temp = File('${_index.path}.new');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'packages': <Object?>[for (final p in packages) p.toJson()],
      }),
      flush: true,
    );
    await temp.rename(_index.path);
  }

  @override
  Future<List<String>> list() async {
    try {
      final paths = <String>[];
      for (final package in await packages()) {
        if (!package.active || !_isPackageId(package.id)) continue;
        final folder = _folder(package.id);
        if (!await folder.exists()) continue;
        final prefix = '${folder.path}/';
        final files = <String>[
          await for (final entity in folder.list(recursive: true))
            if (entity is File && entity.path.startsWith(prefix))
              entity.path.substring(prefix.length).replaceAll('\\', '/'),
        ];
        paths.addAll(_catalogPaths(package.id, files));
      }
      return paths..sort();
    } on Object catch (e, stack) {
      _fail('could not list the packages', e, stack);
      return const <String>[];
    }
  }

  @override
  Future<String> read(String path) async {
    final parts = _split(path);
    if (parts == null ||
        !_isPackageId(parts.$1) ||
        !isSafePackagePath(parts.$2)) {
      throw StateError('no private deck file at $path');
    }
    try {
      return await File('${root.path}/${parts.$1}/${parts.$2}').readAsString();
    } on Object catch (e, stack) {
      _fail('could not read a file', e, stack);
      rethrow;
    }
  }

  @override
  Future<bool> install(
    String id,
    Map<String, String> files, {
    required int revision,
    required String kind,
  }) async {
    if (!_isPackageId(id) || files.isEmpty) {
      _log?.warning(
        'Private decks: refused to install a package with a bad '
        'id or no files',
      );
      return false;
    }
    for (final path in files.keys) {
      if (!isSafePackagePath(path)) {
        _log?.warning(
          'Private decks: refused to install a package with a '
          'file named outside its folder',
        );
        return false;
      }
    }
    final packagesBefore = await packages(); // recovers first
    final fresh = Directory('${_staging.path}/$id');
    final old = Directory('${_staging.path}/$id.old');
    var movedOld = false;
    try {
      if (await _staging.exists()) await _staging.delete(recursive: true);
      var size = 0;
      for (final entry in files.entries) {
        final file = File('${fresh.path}/${entry.key}');
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value, flush: true);
        size += utf8.encode(entry.value).length;
      }
      final target = _folder(id);
      if (await target.exists()) {
        await target.rename(old.path);
        movedOld = true;
      }
      await fresh.rename(target.path);
      final earlier = packagesBefore.where((p) => p.id == id).firstOrNull;
      await _writeIndex(<PrivatePackage>[
        for (final p in packagesBefore)
          if (p.id != id) p,
        PrivatePackage(
          id: id,
          revision: revision,
          kind: kind,
          size: size,
          importedAt: _clock().toUtc(),
          active: earlier?.active ?? true,
        ),
      ]);
      if (await _staging.exists()) await _staging.delete(recursive: true);
      _log?.event('Private decks: installed $id revision $revision');
      return true;
    } on Object catch (e, stack) {
      _fail('could not install a package', e, stack);
      try {
        // Put back what was there.
        final target = _folder(id);
        if (movedOld && await old.exists()) {
          if (await target.exists()) await target.delete(recursive: true);
          await old.rename(target.path);
        } else if (!packagesBefore.any((p) => p.id == id) &&
            await target.exists()) {
          await target.delete(recursive: true);
        }
        if (await _staging.exists()) await _staging.delete(recursive: true);
      } on Object catch (e, stack) {
        _fail('could not undo a failed install', e, stack);
      }
      return false;
    }
  }

  @override
  Future<bool> setActive(String id, {required bool active}) async {
    try {
      final all = await packages();
      if (!all.any((p) => p.id == id)) return false;
      await _writeIndex(<PrivatePackage>[
        for (final p in all) p.id == id ? p.withActive(active: active) : p,
      ]);
      return true;
    } on Object catch (e, stack) {
      _fail('could not change a package', e, stack);
      return false;
    }
  }

  @override
  Future<bool> remove(String id) async {
    if (!_isPackageId(id)) return false;
    try {
      final all = await packages();
      await _writeIndex(<PrivatePackage>[
        for (final p in all)
          if (p.id != id) p,
      ]);
      final folder = _folder(id);
      if (await folder.exists()) await folder.delete(recursive: true);
      return true;
    } on Object catch (e, stack) {
      _fail('could not remove a package', e, stack);
      return false;
    }
  }
}

/// [PrivateStore] in memory, for tests and the gallery.
class MemoryPrivateStore implements PrivateStore {
  MemoryPrivateStore({AppLog? log, DateTime Function()? clock})
    : _log = log,
      _clock = clock ?? DateTime.now;

  final AppLog? _log;
  final DateTime Function() _clock;
  final Map<String, PrivatePackage> _packages = <String, PrivatePackage>{};
  final Map<String, Map<String, String>> _files =
      <String, Map<String, String>>{};

  @override
  Future<List<PrivatePackage>> packages() async =>
      _packages.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<List<String>> list() async => <String>[
    for (final package in _packages.values)
      if (package.active)
        ..._catalogPaths(package.id, _files[package.id]!.keys),
  ]..sort();

  @override
  Future<String> read(String path) async {
    final parts = _split(path);
    final text = parts == null ? null : _files[parts.$1]?[parts.$2];
    return text ?? (throw StateError('no private deck file at $path'));
  }

  @override
  Future<bool> install(
    String id,
    Map<String, String> files, {
    required int revision,
    required String kind,
  }) async {
    if (!_isPackageId(id) ||
        files.isEmpty ||
        !files.keys.every(isSafePackagePath)) {
      _log?.warning('Private decks: refused to install a bad package');
      return false;
    }
    _files[id] = Map<String, String>.of(files);
    _packages[id] = PrivatePackage(
      id: id,
      revision: revision,
      kind: kind,
      size: files.values.fold<int>(0, (n, t) => n + utf8.encode(t).length),
      importedAt: _clock().toUtc(),
      active: _packages[id]?.active ?? true,
    );
    return true;
  }

  @override
  Future<bool> setActive(String id, {required bool active}) async {
    final package = _packages[id];
    if (package == null) return false;
    _packages[id] = package.withActive(active: active);
    return true;
  }

  @override
  Future<bool> remove(String id) async {
    _files.remove(id);
    return _packages.remove(id) != null;
  }
}
