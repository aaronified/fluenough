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
const String privateManifestName = privateManifestFile;

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
  /// active flag, unless [active] says otherwise; a package not installed
  /// before is active.
  ///
  /// At most [maxActivePrivatePackages] are active: installing a package
  /// that would be the fourth returns [PrivateInstall.needsDeactivation] and
  /// writes nothing (the learner deactivates one, or installs it with
  /// `active: false`). [retired] are the ids an update drops: they are
  /// added to the package's earlier retired ids (and those kept when it was
  /// removed), never swapped for them. The index is written first with the
  /// merged set, then the folders swapped, then the index finished; a crash
  /// between is finished or undone at next launch, never losing a retired id.
  Future<PrivateInstall> install(
    String id,
    Map<String, String> files, {
    required int revision,
    required String kind,
    bool? active,
    List<String>? retired,
  });

  /// Makes [id] active, unless [maxActivePrivatePackages] others already are:
  /// then [PrivateActivation.needsDeactivation], and nothing changes.
  Future<PrivateActivation> activate(String id);

  /// Makes [id] inactive: its files stay, the catalog stops reading it. True
  /// when it did (also when it was inactive already).
  Future<bool> deactivate(String id);

  /// Every file of the installed package [id], active or not, keyed by path
  /// in the package with the manifest included; null when it is not
  /// installed or cannot be read. For an update to compare with.
  Future<Map<String, String>?> readPackage(String id);

  /// Deletes the package [id]. Review history stays. Its retired ids are
  /// kept (a tombstone) so a package imported again under [id] cannot reuse
  /// them. True when it did.
  Future<bool> remove(String id);
}

/// A test's stand-in for a process killed mid-install: [FilePrivateStore]
/// does not undo anything when this is thrown from its `onStep` hook.
class PrivateStoreCrash implements Exception {
  const PrivateStoreCrash();
}

bool _sameIds(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

List<String> _sorted(Iterable<String> ids) =>
    (<String>{...ids}.toList())..sort();

/// Whether the package [id], once installed or activated, would be one more
/// than [maxActivePrivatePackages] active, given the [all] installed.
bool _overCap(List<PrivatePackage> all, String id) =>
    all.where((p) => p.id != id && p.active).length >= maxActivePrivatePackages;

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
  FilePrivateStore(this.root, {this._log, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory root;
  final AppLog? _log;
  final DateTime Function() _clock;

  File get _index => File('${root.path}/index.json');
  Directory get _staging => Directory('${root.path}/staging');
  Directory _folder(String id) => Directory('${root.path}/$id');

  Future<void>? _recovered;

  /// Test hook: called with the name of each step of an install (`index-pre`,
  /// `marker`, `old-moved`, `new-moved`, `index-final`, `cleanup`) before the
  /// step runs. A [PrivateStoreCrash] thrown from it stops the install dead,
  /// with no undo, as a killed process would; any other error is an ordinary
  /// failure.
  Future<void> Function(String step)? onStep;

  Future<void> _step(String step) async => await onStep?.call(step);

  File _marker(String id) => File('${_staging.path}/$id.commit');

  /// Once per launch, before anything else: finishes or undoes an install a
  /// crash cut short. An install writes the index first with the retired ids
  /// merged (a safe superset), then a commit marker holding the new entry,
  /// then swaps the folders. So:
  ///
  /// - marker present, the new files in place (`staging/<id>` gone) and the
  ///   folder there: rolls forward, writing the marker's entry unless the
  ///   index already has it or something newer, and drops the old files;
  /// - otherwise rolls back: puts `staging/<id>.old` back as `<id>`.
  ///
  /// The retired ids already in the index are kept either way. Then clears
  /// staging.
  Future<void> _recover() async {
    try {
      if (!await _staging.exists()) return;
      final ids = <String>{};
      await for (final entity in _staging.list()) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (entity is Directory && name.endsWith('.old')) {
          ids.add(name.replaceFirst(RegExp(r'\.old$'), ''));
        } else if (entity is File && name.endsWith('.commit')) {
          ids.add(name.replaceFirst(RegExp(r'\.commit$'), ''));
        }
      }
      for (final id in ids) {
        if (!_isPackageId(id)) continue;
        try {
          await _recoverOne(id);
        } on Object catch (e, stack) {
          _fail('could not recover a package', e, stack);
        }
      }
    } on Object catch (e, stack) {
      _fail('could not recover after a crash', e, stack);
    }
    try {
      if (await _staging.exists()) await _staging.delete(recursive: true);
    } on Object catch (e, stack) {
      _fail('could not clear staging', e, stack);
    }
  }

  Future<void> _recoverOne(String id) async {
    final target = _folder(id);
    final old = Directory('${_staging.path}/$id.old');
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
      final tombstones = await _readTombstones();
      // The ids this install retires are added to the earlier ones, never
      // swapped for them: a safe superset, whatever happens next.
      final mergedRetired = _sorted(<String>[
        ...?before?.retired,
        ...?tombstones[id],
        ...?retired,
      ]);
      final entry = PrivatePackage(
        id: id,
        revision: revision,
        kind: kind,
        size: size,
        importedAt: _clock().toUtc(),
        active: willBeActive,
        retired: mergedRetired,
      );
      // 1. The index first: the earlier entry with the merged retired ids,
      // so a crash from here on can never lose one.
      if (before != null && !_sameIds(before.retired, mergedRetired)) {
        await _step('index-pre');
        await _writeIndex(<PrivatePackage>[
          for (final p in packagesBefore)
            p.id == id
                ? PrivatePackage(
                    id: p.id,
                    revision: p.revision,
                    kind: p.kind,
                    size: p.size,
                    importedAt: p.importedAt,
                    active: p.active,
                    retired: mergedRetired,
                  )
                : p,
        ]);
      }
      // 2. The commit marker: what recovery writes if it finds the files
      // swapped but the index not yet final.
      await _step('marker');
      await _marker(id).writeAsString(jsonEncode(entry.toJson()), flush: true);
      // 3. The swap.
      final target = _folder(id);
      if (await target.exists()) {
        await _step('old-moved');
        await target.rename(old.path);
        movedOld = true;
      }
      await _step('new-moved');
      await fresh.rename(target.path);
      // 4. The final index.
      await _step('index-final');
      await _writeIndex(<PrivatePackage>[
        for (final p in packagesBefore)
          if (p.id != id) p,
        entry,
      ], tombstones: tombstones..remove(id));
    } on PrivateStoreCrash {
      rethrow;
    } on Object catch (e, stack) {
      _fail('could not install a package', e, stack);
      try {
        // Put back what was there. The index is either the earlier entry
        // (with possibly more retired ids, which is safe) or not touched.
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
      return PrivateInstall.failed;
    }
    // The install is done once the index is final: a failure to tidy up is
    // logged and never undoes it (a leftover is dealt with at next launch).
    try {
      await _step('cleanup');
      if (await _staging.exists()) await _staging.delete(recursive: true);
    } on PrivateStoreCrash {
      rethrow;
    } on Object catch (e, stack) {
      _fail('could not clear staging after an install', e, stack);
    }
    _log?.event('Private decks: installed $id revision $revision');
    return PrivateInstall.installed;
  }

  Future<bool> _setActive(String id, bool active) async {
    final all = await packages();
    await _writeIndex(<PrivatePackage>[
      for (final p in all) p.id == id ? p.withActive(active: active) : p,
    ]);
    return true;
  }

  @override
  Future<PrivateActivation> activate(String id) async {
    try {
      final all = await packages();
      final package = all.where((p) => p.id == id).firstOrNull;
      if (package == null) return PrivateActivation.notInstalled;
      if (package.active) return PrivateActivation.done;
      if (_overCap(all, id)) return PrivateActivation.needsDeactivation;
      await _setActive(id, true);
      return PrivateActivation.done;
    } on Object catch (e, stack) {
      _fail('could not activate a package', e, stack);
      return PrivateActivation.failed;
    }
  }

  @override
  Future<bool> deactivate(String id) async {
    try {
      final all = await packages();
      if (!all.any((p) => p.id == id)) return false;
      return await _setActive(id, false);
    } on Object catch (e, stack) {
      _fail('could not deactivate a package', e, stack);
      return false;
    }
  }

  @override
  Future<Map<String, String>?> readPackage(String id) async {
    if (!_isPackageId(id)) return null;
    try {
      final folder = _folder(id);
      if (!await folder.exists()) return null;
      final prefix = '${folder.path}/';
      final files = <String, String>{};
      await for (final entity in folder.list(recursive: true)) {
        if (entity is! File || !entity.path.startsWith(prefix)) continue;
        files[entity.path.substring(prefix.length).replaceAll('\\', '/')] =
            await entity.readAsString();
      }
      return files;
    } on Object catch (e, stack) {
      _fail('could not read a package', e, stack);
      return null;
    }
  }

  @override
  Future<bool> remove(String id) async {
    if (!_isPackageId(id)) return false;
    try {
      final all = await packages();
      final gone = all.where((p) => p.id == id).firstOrNull;
      final tombstones = await _readTombstones();
      if (gone != null && gone.retired.isNotEmpty) {
        tombstones[id] = _sorted(<String>[...gone.retired, ...?tombstones[id]]);
      }
      await _writeIndex(<PrivatePackage>[
        for (final p in all)
          if (p.id != id) p,
      ], tombstones: tombstones);
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
  MemoryPrivateStore({this._log, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppLog? _log;
  final DateTime Function() _clock;
  final Map<String, PrivatePackage> _packages = <String, PrivatePackage>{};
  final Map<String, Map<String, String>> _files =
      <String, Map<String, String>>{};
  final Map<String, List<String>> _tombstones = <String, List<String>>{};

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
  Future<PrivateInstall> install(
    String id,
    Map<String, String> files, {
    required int revision,
    required String kind,
    bool? active,
    List<String>? retired,
  }) async {
    if (!_isPackageId(id) ||
        files.isEmpty ||
        !files.keys.every(isSafePackagePath)) {
      _log?.warning('Private decks: refused to install a bad package');
      return PrivateInstall.failed;
    }
    final before = _packages[id];
    final willBeActive = active ?? before?.active ?? true;
    if (willBeActive && _overCap(_packages.values.toList(), id)) {
      _log?.warning('Private decks: a package needs another to be inactive');
      return PrivateInstall.needsDeactivation;
    }
    _files[id] = Map<String, String>.of(files);
    _packages[id] = PrivatePackage(
      id: id,
      revision: revision,
      kind: kind,
      size: files.values.fold<int>(0, (n, t) => n + utf8.encode(t).length),
      importedAt: _clock().toUtc(),
      active: willBeActive,
      retired: _sorted(<String>[
        ...?before?.retired,
        ..._tombstones[id] ?? const <String>[],
        ...?retired,
      ]),
    );
    _tombstones.remove(id);
    return PrivateInstall.installed;
  }

  @override
  Future<PrivateActivation> activate(String id) async {
    final package = _packages[id];
    if (package == null) return PrivateActivation.notInstalled;
    if (package.active) return PrivateActivation.done;
    if (_overCap(_packages.values.toList(), id)) {
      return PrivateActivation.needsDeactivation;
    }
    _packages[id] = package.withActive(active: true);
    return PrivateActivation.done;
  }

  @override
  Future<bool> deactivate(String id) async {
    final package = _packages[id];
    if (package == null) return false;
    _packages[id] = package.withActive(active: false);
    return true;
  }

  @override
  Future<Map<String, String>?> readPackage(String id) async {
    final files = _files[id];
    return files == null ? null : Map<String, String>.of(files);
  }

  @override
  Future<bool> remove(String id) async {
    _files.remove(id);
    final gone = _packages.remove(id);
    if (gone != null && gone.retired.isNotEmpty) {
      _tombstones[id] = gone.retired;
    }
    return gone != null;
  }
}
