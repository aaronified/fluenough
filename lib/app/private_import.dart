import 'dart:convert';
import 'dart:io';

import '../core/backup/zip_files.dart';
import '../core/decks/app_version.dart';
import '../core/logs/log_entry.dart';
import '../core/private/private_check.dart';
import '../core/private/private_manifest.dart';
import '../core/private/private_package.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'private_store.dart';

/// What importing a private language package came to (#1017).
enum PrivateImportOutcome {
  /// Installed.
  installed,

  /// A check found an error, or the package could not be saved; nothing was
  /// installed.
  refused,

  /// The package is fine, but [maxActivePrivatePackages] others are active:
  /// the learner deactivates one, or installs this one inactive.
  needsDeactivation,
}

/// A package opened and checked, before anything is installed (Plan-Private-
/// Languages, task 10): what the learner sees on the review screen.
class PrivateStaging {
  const PrivateStaging({
    required this.findings,
    this.manifest,
    this.files = const <String, String>{},
    this.counts,
    this.retired = const <String>[],
    this.dropped = const <String>[],
  });

  /// Every finding of levels 0 to 2, errors and warnings.
  final List<PrivateFinding> findings;

  /// The manifest, once it read.
  final PrivateManifest? manifest;

  /// The package's files, by path in the package, the manifest included.
  /// Empty when level 0 refused the archive.
  final Map<String, String> files;

  /// What the package holds; null when it could not be counted.
  final PrivateCounts? counts;

  /// The retired ids the package will have once installed: those of its
  /// earlier revisions, and the card ids this revision drops.
  final List<String> retired;

  /// The card ids this revision drops from the installed revision.
  final List<String> dropped;

  List<PrivateFinding> get errors => <PrivateFinding>[
    for (final f in findings)
      if (f.isError) f,
  ];

  List<PrivateFinding> get warnings => <PrivateFinding>[
    for (final f in findings)
      if (!f.isError) f,
  ];

  /// Whether no error was found and the manifest read.
  bool get canInstall => manifest != null && errors.isEmpty;
}

class PrivateImportResult {
  const PrivateImportResult({
    required this.outcome,
    this.manifest,
    this.findings = const <PrivateFinding>[],
    this.counts,
    this.active = const <PrivatePackage>[],
  });

  final PrivateImportOutcome outcome;

  /// The package's manifest, when it read.
  final PrivateManifest? manifest;

  /// Every finding, errors and warnings.
  final List<PrivateFinding> findings;

  /// What the package holds, when it was opened.
  final PrivateCounts? counts;

  /// For [PrivateImportOutcome.needsDeactivation], the packages that are
  /// active now, one of which the learner can deactivate.
  final List<PrivatePackage> active;

  bool get installed => outcome == PrivateImportOutcome.installed;

  /// The errors, one line each, for the learner or the author. Empty when
  /// the package was installed.
  List<String> get problems => <String>[
    for (final f in findings)
      if (f.isError) f.message,
    if (outcome == PrivateImportOutcome.refused &&
        !findings.any((f) => f.isError))
      'the package could not be saved on this phone',
  ];

  List<PrivateFinding> get warnings => <PrivateFinding>[
    for (final f in findings)
      if (!f.isError) f,
  ];
}

/// The most files a package folder read here may hold, and the most bytes
/// of one: the dev path reads a folder, which has no archive to bound it.
const int devImportMaxFiles = privateMaxFiles;
const int devImportMaxFileBytes = privateFileMaxBytes;

PrivateFinding _error(
  String token, {
  String? file,
  int? line,
  Map<String, String> params = const <String, String>{},
}) => PrivateFinding(
  severity: FindingSeverity.error,
  token: token,
  file: file,
  line: line,
  params: params,
);

/// Opens and checks the package [files], keyed by path in the package (the
/// manifest included), without installing it.
///
/// Level 0 (safe), the manifest and the app version, the revision against
/// what is installed in [store], level 1 (the app's own readers, through
/// [DeckCatalog.parseAll], with [builtIn] deck files beside, which a package
/// that modifies a language refers to) and level 2 (consistent), then the
/// retired ids. Each level runs only when the one before found no error.
///
/// [builtInCoreIds] are the course's core ids a path unit may name; when
/// null they are read from [builtIn] if it holds any. [builtInLanguages] are
/// the codes of the languages the app teaches; when given, a modified
/// language must be one of them. [archiveBytes] is the size of the `.fnzip`
/// when there is one. A lower revision than the installed one is an error
/// unless [allowLowerRevision].
///
/// Never throws: what goes wrong is logged to [log] (counts and ids only,
/// never the package's text) and told in the findings.
Future<PrivateStaging> stagePrivateFiles(
  Map<String, String> files, {
  required PrivateStore store,
  required String appVersion,
  Map<String, String> builtIn = const <String, String>{},
  Set<String>? builtInCoreIds,
  Set<String>? builtInLanguages,
  int? archiveBytes,
  bool allowLowerRevision = false,
  AppLog? log,
}) => _stage(
  <String, List<int>>{
    for (final e in files.entries) e.key: utf8.encode(e.value),
  },
  store: store,
  appVersion: appVersion,
  builtIn: builtIn,
  builtInCoreIds: builtInCoreIds,
  builtInLanguages: builtInLanguages,
  archiveBytes: archiveBytes,
  allowLowerRevision: allowLowerRevision,
  log: log,
);

/// [stagePrivateFiles] for the bytes of a `.fnzip`: refuses an archive over
/// 10 MB before opening it, opens it with [ZipLimits.privatePackage] (no
/// unsafe name, symbolic link, bomb or oversized file), then checks it as
/// [stagePrivateFiles] does.
Future<PrivateStaging> stagePrivateArchive(
  List<int> archive, {
  required PrivateStore store,
  required String appVersion,
  Map<String, String> builtIn = const <String, String>{},
  Set<String>? builtInCoreIds,
  Set<String>? builtInLanguages,
  bool allowLowerRevision = false,
  AppLog? log,
}) async {
  try {
    if (archive.length > privateArchiveMaxBytes) {
      return PrivateStaging(
        findings: <PrivateFinding>[
          _error(
            'archiveTooBig',
            params: <String, String>{
              'bytes': '${archive.length}',
              'limit': '$privateArchiveMaxBytes',
            },
          ),
        ],
      );
    }
    final Map<String, List<int>> opened;
    try {
      opened = ZipFiles.decode(archive, limits: ZipLimits.privatePackage);
    } on FormatException catch (e) {
      // The message names a reason, never a file.
      log?.warning('Private decks: an archive was refused');
      return PrivateStaging(
        findings: <PrivateFinding>[
          _error('zipUnsafe', params: <String, String>{'detail': e.message}),
        ],
      );
    }
    return await _stage(
      opened,
      store: store,
      appVersion: appVersion,
      builtIn: builtIn,
      builtInCoreIds: builtInCoreIds,
      builtInLanguages: builtInLanguages,
      archiveBytes: archive.length,
      allowLowerRevision: allowLowerRevision,
      log: log,
    );
  } on Object catch (e, stack) {
    log?.error(describeError('Private decks: archive failed', e, stack));
    return PrivateStaging(
      findings: <PrivateFinding>[
        _error(
          'zipUnsafe',
          params: <String, String>{'detail': 'the archive could not be opened'},
        ),
      ],
    );
  }
}

Future<PrivateStaging> _stage(
  Map<String, List<int>> bytes, {
  required PrivateStore store,
  required String appVersion,
  required Map<String, String> builtIn,
  required Set<String>? builtInCoreIds,
  required Set<String>? builtInLanguages,
  required int? archiveBytes,
  required bool allowLowerRevision,
  required AppLog? log,
}) async {
  try {
    final zero = PrivateCheck.level0(bytes, archiveBytes: archiveBytes);
    if (zero.any((f) => f.isError)) {
      log?.warning('Private decks: import refused, ${zero.length} findings');
      return PrivateStaging(findings: zero);
    }
    final files = <String, String>{
      for (final e in bytes.entries) e.key: utf8.decode(e.value),
    };
    final findings = <PrivateFinding>[...zero];
    PrivateStaging refused([PrivateManifest? manifest]) {
      log?.warning(
        'Private decks: import refused, ${findings.length} findings',
      );
      return PrivateStaging(findings: findings, manifest: manifest);
    }

    final manifestText = files[privateManifestFile];
    final PrivateManifest manifest;
    try {
      if (manifestText == null) {
        findings.addAll(PrivateCheck.level2(files));
        return refused();
      }
      manifest = PrivateManifest.parse(manifestText);
    } on FormatException {
      findings.addAll(PrivateCheck.level2(files));
      return refused();
    }
    if (appIsOlderThan(appVersion, manifest.minApp)) {
      findings.addAll(PrivateCheck.level2(files, appVersion: appVersion));
      return refused();
    }
    if (manifest.kind == PrivateKind.modifiedLanguage &&
        builtInLanguages != null &&
        !builtInLanguages.contains(manifest.code)) {
      findings.add(
        _error(
          'languageUnknown',
          file: privateManifestFile,
          params: <String, String>{'code': manifest.code},
        ),
      );
      return refused();
    }
    final installed = (await store.packages())
        .where((p) => p.id == manifest.package)
        .firstOrNull;
    if (installed != null &&
        manifest.revision < installed.revision &&
        !allowLowerRevision) {
      findings.add(
        _error(
          'revisionLower',
          file: privateManifestFile,
          params: <String, String>{
            'found': '${manifest.revision}',
            'installed': '${installed.revision}',
          },
        ),
      );
      // The manifest is given so that the screen can name the language.
      return refused(manifest);
    }

    // Level 1: the app's own readers.
    final folder = '$privateDeckPrefix${manifest.package}/';
    final deckFiles = <String, String>{
      for (final entry in files.entries)
        if (entry.key.endsWith('.yaml') && entry.key != privateManifestFile)
          '$folder${entry.key}': entry.value,
    };
    final catalog = DeckCatalog.parseAll(<String, String>{
      ...builtIn,
      ...deckFiles,
    });
    for (final broken in catalog.broken) {
      if (!broken.path.startsWith(folder)) continue;
      findings.add(
        _error(
          'unreadable',
          file: broken.path.substring(folder.length),
          line: broken.error.line,
          params: <String, String>{'detail': broken.error.message},
        ),
      );
    }
    // A hidden deck (D3) is in [Catalog.hidden], not [Catalog.decks]; it is
    // a deck of the package all the same.
    final own = <DeckEntry>[
      for (final entry in <DeckEntry>[...catalog.decks, ...catalog.hidden])
        if (entry.private) entry,
    ];
    if (own.isEmpty && !findings.any((f) => f.isError)) {
      findings.add(_error('noDecks'));
    }
    if (findings.any((f) => f.isError)) return refused();

    // Level 2: the package holds together, and reuses no retired id.
    findings.addAll(
      PrivateCheck.level2(
        files,
        appVersion: appVersion,
        builtInCoreIds:
            builtInCoreIds ??
            (builtIn.isEmpty ? null : PrivateCheck.coreIds(builtIn)),
      ),
    );
    // The ids an earlier revision retired, and those a removed package of the
    // same id kept (its tombstone): a package removed and imported again may
    // not give one of them to another card.
    final retiredBefore = <String>{
      ...?installed?.retired,
      ...await store.tombstone(manifest.package),
    }.toList()..sort();
    findings.addAll(PrivateCheck.retiredReused(files, retiredBefore));
    var dropped = const <String>[];
    if (installed != null) {
      final old = await store.readPackage(manifest.package);
      if (old != null) {
        final now = PrivateCheck.cardIds(files);
        dropped = <String>[
          for (final id in PrivateCheck.cardIds(old))
            if (!now.contains(id)) id,
        ]..sort();
      }
    }
    final retired = <String>{...retiredBefore, ...dropped}.toList()..sort();
    if (findings.any((f) => f.isError)) {
      log?.warning(
        'Private decks: import refused, ${findings.length} findings',
      );
    }
    return PrivateStaging(
      findings: findings,
      manifest: manifest,
      files: files,
      counts: PrivateCheck.counts(files),
      retired: retired,
      dropped: dropped,
    );
  } on Object catch (e, stack) {
    log?.error(describeError('Private decks: import failed', e, stack));
    return PrivateStaging(
      findings: <PrivateFinding>[
        _error(
          'manifestInvalid',
          params: <String, String>{
            'detail': 'the package could not be imported',
          },
        ),
      ],
    );
  }
}

/// Installs a package [staging] found no error in, into [store]; [active]
/// false installs it inactive (what the learner picks when
/// [PrivateImportOutcome.needsDeactivation] asked).
Future<PrivateImportResult> installStaged(
  PrivateStaging staging, {
  required PrivateStore store,
  bool? active,
  AppLog? log,
}) async {
  final manifest = staging.manifest;
  PrivateImportResult result(
    PrivateImportOutcome outcome, {
    List<PrivatePackage> activeNow = const <PrivatePackage>[],
  }) => PrivateImportResult(
    outcome: outcome,
    manifest: manifest,
    findings: staging.findings,
    counts: staging.counts,
    active: activeNow,
  );
  if (manifest == null || !staging.canInstall) {
    return result(PrivateImportOutcome.refused);
  }
  try {
    final done = await store.install(
      manifest.package,
      staging.files,
      revision: manifest.revision,
      kind: manifest.kind.text,
      active: active,
      retired: staging.retired,
    );
    switch (done) {
      case PrivateInstall.installed:
        log?.event(
          'Private decks: imported ${manifest.package} revision '
          '${manifest.revision}, ${staging.counts?.decks ?? 0} decks',
        );
        return result(PrivateImportOutcome.installed);
      case PrivateInstall.needsDeactivation:
        return result(
          PrivateImportOutcome.needsDeactivation,
          activeNow: <PrivatePackage>[
            for (final p in await store.packages())
              if (p.active && p.id != manifest.package) p,
          ],
        );
      case PrivateInstall.failed:
        // The store has logged why.
        return result(PrivateImportOutcome.refused);
    }
  } on Object catch (e, stack) {
    log?.error(describeError('Private decks: install failed', e, stack));
    return result(PrivateImportOutcome.refused);
  }
}

/// Checks the package [files], keyed by path in the package (the manifest
/// included), and installs it into [store]: [stagePrivateFiles], then
/// [installStaged]. Nothing is installed unless every check passes, and
/// nothing here throws.
Future<PrivateImportResult> importPrivatePackage(
  Map<String, String> files, {
  required PrivateStore store,
  required String appVersion,
  Map<String, String> builtIn = const <String, String>{},
  Set<String>? builtInCoreIds,
  Set<String>? builtInLanguages,
  bool allowLowerRevision = false,
  bool? active,
  AppLog? log,
}) async => installStaged(
  await stagePrivateFiles(
    files,
    store: store,
    appVersion: appVersion,
    builtIn: builtIn,
    builtInCoreIds: builtInCoreIds,
    builtInLanguages: builtInLanguages,
    allowLowerRevision: allowLowerRevision,
    log: log,
  ),
  store: store,
  active: active,
  log: log,
);

/// Imports the bytes of a `.fnzip`: [stagePrivateArchive], then
/// [installStaged].
Future<PrivateImportResult> importPrivateArchive(
  List<int> archive, {
  required PrivateStore store,
  required String appVersion,
  Map<String, String> builtIn = const <String, String>{},
  Set<String>? builtInCoreIds,
  Set<String>? builtInLanguages,
  bool allowLowerRevision = false,
  bool? active,
  AppLog? log,
}) async => installStaged(
  await stagePrivateArchive(
    archive,
    store: store,
    appVersion: appVersion,
    builtIn: builtIn,
    builtInCoreIds: builtInCoreIds,
    builtInLanguages: builtInLanguages,
    allowLowerRevision: allowLowerRevision,
    log: log,
  ),
  store: store,
  active: active,
  log: log,
);

/// The YAML and JSON files under [directory], keyed by path in it with `/`
/// separators, as [importPrivatePackage] takes them: the dev path for a
/// package that is a folder. Null, after logging, when the folder cannot be
/// read or is over the dev limits.
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
