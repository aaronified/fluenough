import 'dart:io';

import '../core/decks/app_version.dart';
import '../core/logs/log_entry.dart';
import '../core/private/private_manifest.dart';
import '../core/private/private_package.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'private_store.dart';

/// What importing a private language package came to (#1017).
class PrivateImportResult {
  const PrivateImportResult.installed(PrivateManifest this.manifest)
    : problems = const <String>[];

  const PrivateImportResult.refused(this.problems) : manifest = null;

  /// The package's manifest, when it was installed.
  final PrivateManifest? manifest;

  /// Why it was refused, one line each, for the learner or the author. Empty
  /// when it was installed.
  final List<String> problems;

  bool get installed => manifest != null;
}

/// The most files a package folder read here may hold, and the most bytes
/// of one. The full limits are the safe reading of a `.fnzip` (Plan-Private-
/// Languages, level 0); these only keep the dev path from reading a whole
/// disk into memory.
const int devImportMaxFiles = 1000;
const int devImportMaxFileBytes = 2 * 1024 * 1024;

/// Checks the package [files], keyed by path in the package (the manifest
/// included), and installs it into [store].
///
/// Level 1 of the plan's checks: the manifest reads, the app is new enough,
/// every file's name is safe, and the app's own readers parse every deck,
/// path and facts file of the package ([Catalog.parseAll] on the files under
/// the package's folder), with every id carrying `fnpd-<code>-` and every
/// deck teaching the manifest's language. [builtIn] holds the app's own deck
/// files, which a package that modifies a language may refer to.
///
/// Nothing is installed unless every check passes, and nothing here throws:
/// what goes wrong is logged to [log] and told in the result.
Future<PrivateImportResult> importPrivatePackage(
  Map<String, String> files, {
  required PrivateStore store,
  required String appVersion,
  Map<String, String> builtIn = const <String, String>{},
  AppLog? log,
}) async {
  try {
    final manifestText = files[privateManifestName];
    if (manifestText == null) {
      return _refused(log, <String>['$privateManifestName is missing']);
    }
    final PrivateManifest manifest;
    try {
      manifest = PrivateManifest.parse(manifestText);
    } on FormatException catch (e) {
      // The message names a field, never the learner's text.
      return _refused(log, <String>[e.message]);
    }
    if (appIsOlderThan(appVersion, manifest.minApp)) {
      return _refused(log, <String>[
        'this package needs app version ${manifest.minApp} or newer',
      ]);
    }
    final problems = <String>[
      for (final path in files.keys)
        if (!isSafePackagePath(path)) 'the file name "$path" is not allowed',
    ];
    if (problems.isNotEmpty) return _refused(log, problems);

    final folder = '$privateDeckPrefix${manifest.package}/';
    final deckFiles = <String, String>{
      for (final entry in files.entries)
        if (entry.key.endsWith('.yaml') && entry.key != privateManifestName)
          '$folder${entry.key}': entry.value,
    };
    final catalog = Catalog.parseAll(<String, String>{
      ...builtIn,
      ...deckFiles,
    });
    for (final broken in catalog.broken) {
      if (broken.path.startsWith(folder)) {
        problems.add('${broken.fileName}: ${broken.error.message}');
      }
    }
    // A hidden deck (D3) is in [Catalog.hidden], not [Catalog.decks]; it is
    // a deck of the package all the same.
    final own = <DeckEntry>[
      for (final entry in <DeckEntry>[...catalog.decks, ...catalog.hidden])
        if (entry.private) entry,
    ];
    if (own.isEmpty && problems.isEmpty) {
      problems.add('the package has no deck that can be read');
    }
    for (final deck in own) {
      if (deck.language.code != manifest.code) {
        problems.add(
          '${deck.path.split('/').last}: teaches ${deck.language.code}, but '
          'the manifest is for ${manifest.code}',
        );
      }
    }
    if (problems.isNotEmpty) return _refused(log, problems);

    final done = await store.install(
      manifest.package,
      files,
      revision: manifest.revision,
      kind: manifest.kind.text,
    );
    if (!done) {
      // The store has logged why.
      return const PrivateImportResult.refused(<String>[
        'the package could not be saved on this phone',
      ]);
    }
    log?.event(
      'Private decks: imported ${manifest.package} revision '
      '${manifest.revision}, ${own.length} decks',
    );
    return PrivateImportResult.installed(manifest);
  } on Object catch (e, stack) {
    log?.error(describeError('Private decks: import failed', e, stack));
    return const PrivateImportResult.refused(<String>[
      'the package could not be imported',
    ]);
  }
}

PrivateImportResult _refused(AppLog? log, List<String> problems) {
  log?.warning('Private decks: import refused, ${problems.length} problems');
  return PrivateImportResult.refused(problems);
}

/// The YAML and JSON files under [directory], keyed by path in it with `/`
/// separators, as [importPrivatePackage] takes them: the dev path for a
/// package that is a folder (the `.fnzip` reader comes later). Null, after
/// logging, when the folder cannot be read or is over the dev limits.
Future<Map<String, String>?> readPackageFolder(
  Directory directory, {
  AppLog? log,
}) async {
  try {
    final prefix = '${directory.path}/';
    final files = <String, String>{};
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.substring(prefix.length).replaceAll('\\', '/');
      if (!path.endsWith('.yaml') && !path.endsWith('.json')) continue;
      if (files.length >= devImportMaxFiles ||
          await entity.length() > devImportMaxFileBytes) {
        log?.warning('Private decks: a package folder is over the dev limits');
        return null;
      }
      files[path] = await entity.readAsString();
    }
    return files;
  } on Object catch (e, stack) {
    log?.error(
      describeError('Private decks: could not read a folder', e, stack),
    );
    return null;
  }
}

/// Imports every folder under [root] as a package, for a debug build (the
/// dev import path, #1017): put a package's files in a folder of
/// `<app support>/private-dev/`. Returns how many were installed.
Future<int> importDevPackages(
  Directory root, {
  required PrivateStore store,
  required String appVersion,
  AppLog? log,
}) async {
  var installed = 0;
  try {
    if (!await root.exists()) return 0;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final files = await readPackageFolder(entity, log: log);
      if (files == null) continue;
      final result = await importPrivatePackage(
        files,
        store: store,
        appVersion: appVersion,
        log: log,
      );
      if (result.installed) installed++;
    }
  } on Object catch (e, stack) {
    log?.error(describeError('Private decks: dev import failed', e, stack));
  }
  return installed;
}
